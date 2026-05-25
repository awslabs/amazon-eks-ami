# Custom Gather Inc. EKS AMIs

Toolset to bake patched EKS-Optimized Amazon Linux 2023 (AL2023) AMIs for Gather Inc.'s EKS clusters. Lets us ship a fix for a kernel CVE without waiting for AWS to reissue their AMI.

The legacy upstream README is preserved at [`README-ORIG.md`](README-ORIG.md).

## Branches

- `eks-ami` — Gather's customisations. Default branch.
- `upstream-main` — mirror of [`awslabs/amazon-eks-ami`](https://github.com/awslabs/amazon-eks-ami). Periodically merged into `eks-ami`.

```sh
git remote -v
# origin    https://github.com/gathertown/amazon-eks-ami.git
# upstream  https://github.com/awslabs/amazon-eks-ami.git
```

## Source distro & CVE tracking

- **Base:** AL2023 (AWS's downstream of Fedora), source AMIs owned by `137112412989`, filtered by `al2023-ami-minimal-2023.*-kernel-<line>-*`.
- **Kernel:** `kernel6.12` (Linux 6.12 LTS) for k8s 1.33 / 1.34 (1.35 is available in `templates/al2023/variables-1.35.json` but not wired into the CI matrix yet).
- **CVE → ALAS → fix mapping:** <https://alas.aws.amazon.com/alas2023.html>. On a running node use `dnf updateinfo info --cve CVE-XXXX-XXXXX`.

## CircleCI pipeline

```text
build-al2023-ami → publish-al2023-amis → ┬→ upload-manifest
                                         └→ cleanup-old-amis
```

Runs on arm64 (Graviton) runners. The runner architecture is independent of the AMI architecture (Packer launches the build instance via API), so one arm64 runner bakes both `arm64` and `x86_64` AMIs. The CVE-assertion oracle is `dnf updateinfo --installed info --cve` (AL2023 kernel changelogs don't embed CVE IDs).

**Build matrix:** `{arm64} × {1.33, 1.34}` — 2 AMIs per run. Adding `x86_64` or `1.35` is a one-line addition to the `workflows.build-patched-eks-amis.jobs` block in `.circleci/config.yml` once we need them.

> **INFRA-2731 follow-up:** the `approve-publish` manual hold is still disabled while we shake the pipeline down. Restore it before treating any prod region as load-bearing on these AMIs.

### Pipeline parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `build_region` | `us-east-1` | Region the source AMI is baked in. |
| `copy_regions` | _12 iaac regions_ | `af-south-1, ap-northeast-1, ap-northeast-2, ap-south-1, ap-southeast-1, ap-southeast-2, eu-central-1, eu-south-2, eu-west-1, sa-east-1, us-east-2, us-west-1`. Discovered from `iaac/env/{production,staging,development,testbed}`. `build_region` is auto-filtered. |
| `cve_tag` | `cve2026-31431` | Suffix in the AMI name. Empty for generic rebuilds. |
| `assert_cves` | `CVE-2026-31431` | CVE IDs that must be covered by an installed ALAS. Empty disables the check. |
| `trigger_branch` | `panagiotis/infra-2697-patch-eks-for-cve-2026-31431` | Branch gating the workflow. |
| `cleanup_keep` | `5` | AMIs retained per `(arch, k8s)` per region (tagged `Builder=eks-ami-packer`). |
| `cleanup_dry_run` | `"false"` | `"true"` to preview deletes without calling AWS. |
| `cleanup_name_prefix` | `gather-eks-al2023-` | Name prefix scoping cleanup candidates. |
| `manifest_bucket` | `gather-infra-generic` | S3 bucket for the aggregated manifest. |
| `manifest_prefix` | `eks-custom-ami` | Key prefix under `manifest_bucket`. |

### Artifacts

| Job | Path | Contents |
| --- | --- | --- |
| `build-al2023-ami` | `ami-artifacts-<k8s>-<arch>/` | `<ami>-manifest.json`, `<ami>-version-info.json` (RPM SBOM), `<ami>-build-report.json` (kernel + CVE + ALAS), `<ami>-report.md` |
| `publish-al2023-amis` | `ami-artifacts-published/copies/summary.tsv` | `source_ami	ami_name	region	copy_ami_id` |
| `upload-manifest` | `ami-manifest/manifest.json` | Same as the S3 upload (see below). |
| `cleanup-old-amis` | `ami-cleanup/summary.tsv` | `region	type	action	ami_id	ami_name	creation_date	snapshot_id	result` |

### Aggregate manifest in S3

After publish, `upload-manifest` writes:

- `s3://${manifest_bucket}/${manifest_prefix}/manifests/<utc-date>-<short-sha>/manifest.json` — dated, immutable.
- `s3://${manifest_bucket}/${manifest_prefix}/manifests/latest.json` — pointer to the most recent run (Cache-Control: `no-cache`).

```json
{
  "build_date": "2026-05-26T03:00:00Z",
  "commit": "abc1234",
  "branch": "eks-ami",
  "amis": {
    "us-east-1": {
      "arm64":  {"1.33": "ami-..."},
      "x86_64": {"1.33": "ami-..."}
    }
  },
  "cves_addressed": ["CVE-2026-31431"]
}
```

The CircleCI OIDC role needs `s3:PutObject` on `arn:aws:s3:::gather-infra-generic/eks-custom-ami/*`.

## Triggering a new CVE patch build

1. Branch off the latest `eks-ami`:
   ```sh
   git checkout -b panagiotis/infra-XXXX-patch-eks-for-cve-YYYY-ZZZZZ
   ```
2. Edit `.circleci/config.yml`: set `trigger_branch`, `cve_tag` (`cveYYYY-ZZZZZ`), `assert_cves` (`CVE-YYYY-ZZZZZ[,...]`), and start `copy_regions` empty for the first run.
3. Push. The build fails fast if any requested CVE isn't covered by an installed ALAS on the freshly-baked instance.
4. Review the markdown report inline in the "Generate final report" CircleCI step (JSON variants in the artifacts tab).
5. Flip `copy_regions` to the full prod list and re-run. **Restore the `approve-publish` hold first** so AMI copies stay human-gated.
6. Wire the AMI IDs from `s3://gather-infra-generic/eks-custom-ami/manifests/latest.json` into the iaac repo (`sfu_t1`, `sfuga_t1`, `workers_t1`, `generic_graviton_t1/t2`).

## `hack/eks_ami.py` — single tool, four subcommands

Stdlib-only Python (Python 3.9+). No third-party deps. AWS access goes through the system `aws` CLI via `subprocess`, so the OIDC creds the CircleCI orb already exports flow through unchanged.

| Subcommand | Where it runs | What it does |
| --- | --- | --- |
| `build-report` | On the AL2023 builder during Packer | Probes kernel, `dnf updateinfo`, runtime versions; asserts requested CVE fixes are installed. |
| `render-report` | `build-al2023-ami` CI job | Merges the three JSON artifacts into Markdown. |
| `aggregate-manifest` | `upload-manifest` CI job | Combines per-build Packer manifests + cross-region copies into one JSON for S3. |
| `cleanup-amis` | `cleanup-old-amis` CI job | Per-region retention of `Builder=eks-ami-packer` AMIs. |

## Local testing

```sh
make test            # 23 stdlib unittest cases for hack/eks_ami.py, ~10 ms
make lint-circleci   # circleci config validate + process (requires the circleci CLI)
```

Full Packer build (uses your AWS creds, defaults to `arch=arm64`):

```sh
aws sso login --profile gather-infra
export AWS_PROFILE=gather-infra

make build os_distro=al2023 k8s=1.33 \
  aws_region=us-east-1 \
  assert_cves=CVE-2026-31431 \
  ami_name=gather-eks-al2023-arm64-1.33-localtest-$(git rev-parse --short HEAD)
```

Render the markdown summary:

```sh
python3 hack/eks_ami.py render-report "$AMI_NAME" "$PWD" --out "$AMI_NAME-report.md"
```

Preview cleanup decisions without mutating AWS:

```sh
python3 hack/eks_ami.py cleanup-amis \
  --regions us-east-1,eu-central-1 --keep 5 --dry-run true
```

## CircleCI / AWS prerequisites

- CircleCI env var `AWS_OIDC_ROLE_ARN` → `circleci-eks-ami-builder` IAM role (provisioned in iaac at `components/circleci/aws_iam_role_eks_ami_builder.tf`).
- The IAM role policy must grant `ec2:CopyImage`, `ec2:DescribeImages`, `ec2:CreateTags`, the standard Packer/`amazon-ebs` permissions in every `copy_regions` region, and `s3:PutObject` on the manifest prefix.
- All mutating actions are scoped to the `Builder=eks-ami-packer` resource tag; Packer applies it at build time and the publish job re-applies it on each cross-region copy.
