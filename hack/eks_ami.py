#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable, Iterable, Optional, Tuple

NAME_PREFIX_DEFAULT = "gather-eks-al2023-"
BUILDER_TAG_DEFAULT = "eks-ami-packer"
CLEANUP_KEEP_DEFAULT = 5

ProcResult = Tuple[int, str, str]
Runner = Callable[[list], ProcResult]

def real_runner(cmd: list) -> ProcResult:
    try:
        p = subprocess.run(cmd, check=False, capture_output=True, text=True)
        return p.returncode, p.stdout or "", p.stderr or ""
    except FileNotFoundError as e:
        return 127, "", str(e)

_NAME_TAIL_RE = re.compile(r"^([a-z0-9_]+)-(\d+\.\d+)")

def parse_arch_k8s(
    ami_name: str, name_prefix: str = NAME_PREFIX_DEFAULT
) -> Tuple[Optional[str], Optional[str]]:
    if not ami_name or not ami_name.startswith(name_prefix):
        return None, None
    tail = ami_name[len(name_prefix):]
    m = _NAME_TAIL_RE.match(tail)
    if not m:
        return None, None
    return m.group(1), m.group(2)

def parse_csv(value: str) -> list:
    if not value:
        return []
    return [v.strip() for v in value.split(",") if v.strip()]

def utc_iso_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def parse_os_release(path: Path = Path("/etc/os-release")) -> dict:
    info: dict = {}
    try:
        text = path.read_text()
    except (FileNotFoundError, IsADirectoryError, PermissionError):
        return info
    for line in text.splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        info[k.strip()] = v.strip().strip('"').strip("'")
    return info

def _ingest_packer_manifests(artifacts_dir: Path, amis: dict, log) -> None:
    for mpath in sorted(artifacts_dir.glob("*-manifest.json")):
        ami_name = mpath.name[: -len("-manifest.json")]
        arch, k8s = parse_arch_k8s(ami_name)
        if not arch or not k8s:
            log(f"WARN: {mpath.name} has unparseable name; skipping")
            continue
        try:
            data = json.loads(mpath.read_text())
        except json.JSONDecodeError as e:
            log(f"WARN: {mpath.name} not valid JSON: {e}; skipping")
            continue
        builds = data.get("builds") or []
        if not builds:
            continue
        artifact_id = (builds[-1].get("artifact_id") or "").strip()
        for entry in artifact_id.split(","):
            entry = entry.strip()
            if not entry or ":" not in entry:
                continue
            region, ami_id = entry.split(":", 1)
            region, ami_id = region.strip(), ami_id.strip()
            if not region or not ami_id:
                continue
            amis.setdefault(region, {}).setdefault(arch, {})[k8s] = ami_id

def _ingest_copies_summary(artifacts_dir: Path, amis: dict, log) -> None:
    summary = artifacts_dir / "copies" / "summary.tsv"
    if not summary.is_file():
        return
    with summary.open() as f:
        _header = f.readline()
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            _src, ami_name, region, copy_ami_id = parts[:4]
            arch, k8s = parse_arch_k8s(ami_name)
            if not arch or not k8s:
                continue
            region, copy_ami_id = region.strip(), copy_ami_id.strip()
            if not region or not copy_ami_id:
                continue
            amis.setdefault(region, {}).setdefault(arch, {})[k8s] = copy_ami_id

def build_aggregate_manifest(
    artifacts_dir: Path,
    *,
    commit: str = "",
    branch: str = "",
    cves: Iterable = (),
    now_iso: Optional[str] = None,
    log: Callable[[str], None] = lambda _msg: None,
) -> dict:
    amis: dict = {}
    _ingest_packer_manifests(artifacts_dir, amis, log)
    _ingest_copies_summary(artifacts_dir, amis, log)
    return {
        "build_date": now_iso or utc_iso_now(),
        "commit": commit,
        "branch": branch,
        "amis": amis,
        "cves_addressed": list(cves),
    }

def cmd_aggregate_manifest(args, runner: Runner = real_runner) -> int:
    if not args.artifacts_dir.is_dir():
        print(f"ERROR: {args.artifacts_dir} is not a directory", file=sys.stderr)
        return 2

    def log(msg: str) -> None:
        print(msg, file=sys.stderr)

    manifest = build_aggregate_manifest(
        args.artifacts_dir,
        commit=args.commit,
        branch=args.branch,
        cves=parse_csv(args.cves),
        log=log,
    )
    text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if args.out is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
    else:
        sys.stdout.write(text)
    return 0

def _describe_images(region: str, builder_tag: str, runner: Runner) -> list:
    cmd = [
        "aws", "--region", region, "ec2", "describe-images",
        "--owners", "self",
        "--filters", f"Name=tag:Builder,Values={builder_tag}",
        "--output", "json",
    ]
    rc, out, err = runner(cmd)
    if rc != 0 or not out.strip():
        return []
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return []
    images = []
    for img in data.get("Images", []) or []:
        snap_id = ""
        for m in img.get("BlockDeviceMappings", []) or []:
            ebs = m.get("Ebs") or {}
            if ebs.get("SnapshotId"):
                snap_id = ebs["SnapshotId"]
                break
        images.append({
            "Name": img.get("Name") or "",
            "ImageId": img.get("ImageId") or "",
            "CreationDate": img.get("CreationDate") or "",
            "SnapshotId": snap_id,
        })
    return images

def _deregister_image(region: str, ami_id: str, runner: Runner) -> bool:
    rc, _, _ = runner(
        ["aws", "--region", region, "ec2", "deregister-image", "--image-id", ami_id]
    )
    return rc == 0

def _delete_snapshot(region: str, snapshot_id: str, runner: Runner) -> bool:
    rc, _, _ = runner(
        ["aws", "--region", region, "ec2", "delete-snapshot", "--snapshot-id", snapshot_id]
    )
    return rc == 0

CleanupRow = Tuple[str, str, str, str, str, str, str, str]
"""(region, type, action, ami_id, ami_name, creation_date, snapshot_id, result)"""

CLEANUP_HEADER: CleanupRow = (
    "region", "type", "action", "ami_id", "ami_name", "creation_date", "snapshot_id", "result"
)

def compute_cleanup_decisions(
    images: list, name_prefix: str, keep: int
) -> Tuple[list, list]:
    typed: dict = {}
    skipped = []
    for img in images:
        arch, k8s = parse_arch_k8s(img["Name"], name_prefix=name_prefix)
        if not arch or not k8s:
            skipped.append(img)
            continue
        typed.setdefault(f"{arch}-{k8s}", []).append(img)
    decisions = []
    for type_ in sorted(typed):
        imgs = sorted(typed[type_], key=lambda i: i["CreationDate"], reverse=True)
        for i, img in enumerate(imgs):
            decisions.append(("KEEP" if i < keep else "DELETE", type_, img))
    return decisions, skipped

def cmd_cleanup_amis(args, runner: Runner = real_runner) -> int:
    regions = parse_csv(args.regions)
    if not regions:
        print("ERROR: at least one region is required", file=sys.stderr)
        return 2

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    summary_path = out_dir / "summary.tsv"
    rows: list = [CLEANUP_HEADER]
    totals = {"kept": 0, "deleted": 0, "skipped": 0, "failed": 0}

    for region in regions:
        print(f"===== Region: {region} =====")
        images = _describe_images(region, args.builder_tag, runner)
        if not images:
            print(f"  no Builder={args.builder_tag} AMIs in {region}")
            continue

        decisions, skipped = compute_cleanup_decisions(
            images, name_prefix=args.name_prefix, keep=args.keep
        )

        for img in skipped:
            print(f"  WARN: name '{img['Name']}' does not match expected pattern; skipping")
            rows.append((
                region, "unknown", "SKIP", img["ImageId"], img["Name"],
                img["CreationDate"], img["SnapshotId"] or "", "name-mismatch",
            ))
            totals["skipped"] += 1

        if not decisions:
            print("  no AMIs matched the expected name pattern")
            continue

        print(f"\n  {'ACTION':<7} {'TYPE':<26} {'CREATION_DATE':<25} {'AMI_ID':<23} NAME")
        for action, type_, img in decisions:
            print(f"  {action:<7} {type_:<26} {img['CreationDate']:<25} {img['ImageId']:<23} {img['Name']}")
        print()

        for action, type_, img in decisions:
            if action == "KEEP":
                rows.append((
                    region, type_, "KEEP", img["ImageId"], img["Name"],
                    img["CreationDate"], img["SnapshotId"] or "", "n/a",
                ))
                totals["kept"] += 1
                continue

            if args.dry_run:
                print(
                    f"  [dry-run] would deregister {img['ImageId']} and delete snapshot "
                    f"{img['SnapshotId'] or '<none>'}"
                )
                rows.append((
                    region, type_, "DELETE", img["ImageId"], img["Name"],
                    img["CreationDate"], img["SnapshotId"] or "", "dry-run",
                ))
                totals["deleted"] += 1
                continue

            ami_result = "ok" if _deregister_image(region, img["ImageId"], runner) else "deregister-failed"
            snap_id = img["SnapshotId"]
            if snap_id and snap_id != "None":
                snap_result = "ok" if _delete_snapshot(region, snap_id, runner) else "snapshot-delete-failed"
            else:
                snap_result = "no-snapshot"

            overall = f"ami:{ami_result};snap:{snap_result}"
            print(f"  deleted {img['ImageId']} ({overall})")
            rows.append((
                region, type_, "DELETE", img["ImageId"], img["Name"],
                img["CreationDate"], snap_id or "", overall,
            ))
            if ami_result == "ok" and snap_result != "snapshot-delete-failed":
                totals["deleted"] += 1
            else:
                totals["failed"] += 1

    with summary_path.open("w") as f:
        for row in rows:
            f.write("\t".join(row) + "\n")

    print(f"\n===== Cleanup summary (also written to {summary_path}) =====")
    if len(rows) > 1:
        widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
        for row in rows:
            print("  ".join(c.ljust(w) for c, w in zip(row, widths)))
    else:
        print("(no rows)")
    print(
        f"\nCounts: kept={totals['kept']} deleted={totals['deleted']} "
        f"skipped={totals['skipped']} failed={totals['failed']}"
    )

    return 2 if totals["failed"] > 0 else 0

_ASSERT_BADGE = {"ok": "PASS", "failed": "FAIL", "not_requested": "N/A"}

_PACKAGE_KEY_RE = re.compile(
    r"^(kernel|containerd|runc|nerdctl|kubelet|nodeadm|nvidia|efa|soci"
    r"|amazon-ec2|amazon-ssm|aws-cfn|chrony|cloud-init|selinux)"
)

def render_markdown_report(
    ami_name: str,
    manifest: dict,
    build_report: dict,
    version_info: dict,
    *,
    ci_build_url: str = "local",
    ci_branch: str = "unknown",
    ci_sha: str = "unknown",
) -> str:
    builds = manifest.get("builds") or []
    last = builds[-1] if builds else {}
    artifact_id = (last.get("artifact_id") or "").strip()
    source_ami = (last.get("custom_data") or {}).get("source_ami_id", "unknown")
    source_name = (last.get("custom_data") or {}).get("source_ami_name", "unknown")
    build_time = last.get("build_time", "")

    build_region = built_ami = "unknown"
    first_pair = artifact_id.split(",", 1)[0]
    if ":" in first_pair:
        build_region, built_ami = first_pair.split(":", 1)

    sec = build_report.get("security") or {}
    assertions = sec.get("assertions") or {}
    assert_status = assertions.get("status", "unknown")
    requested = assertions.get("requested") or []
    missing = assertions.get("missing") or []
    pending_count = sec.get("pending_security_count", 0)

    badge = _ASSERT_BADGE.get(assert_status, "UNKNOWN")

    out = []
    out.append("# EKS AMI Build Report\n\n")
    out.append(f"**AMI name:** `{ami_name}`\n\n")
    out.append(f"**Built AMI:** `{built_ami}` in `{build_region}`\n\n")
    out.append(f"**Source AMI:** `{source_ami}` (`{source_name}`)\n\n")
    out.append(f"**Packer build time:** `{build_time}`\n\n")
    out.append(f"**CI build:** {ci_build_url}\n\n")
    out.append(f"**Branch / SHA:** `{ci_branch}` @ `{ci_sha}`\n\n")

    out.append(f"## CVE assertion: {badge}\n\n")
    out.append(f"- Requested: `{', '.join(requested) if requested else 'none'}`\n")
    out.append(f"- Status: `{assert_status}`\n")
    out.append(f"- Missing: `{', '.join(missing) if missing else 'none'}`\n\n")

    out.append("## Security posture\n\n")
    out.append(f"- Pending AL2023 security advisories after build: **{pending_count}**\n\n")
    if isinstance(pending_count, int) and pending_count > 0:
        out.append("<details><summary>Pending advisories</summary>\n\n```\n")
        for alas in sec.get("pending_security_alas") or []:
            out.append(f"{alas}\n")
        out.append("```\n</details>\n\n")
        out.append("<details><summary>Affected packages</summary>\n\n```\n")
        for pkg in sec.get("pending_security_pkgs") or []:
            out.append(f"{pkg}\n")
        out.append("```\n</details>\n\n")

    kernel = build_report.get("kernel") or {}
    out.append("## Kernel\n\n```\n")
    out.append(f"package: {kernel.get('package', '')}\n")
    out.append(f"nvr:     {kernel.get('nvr', '')}\n")
    out.append(f"uname:   {kernel.get('uname_r', '')}\n")
    out.append(f"arch:    {kernel.get('arch', '')}\n")
    out.append("```\n\n")

    installed_cves = kernel.get("installed_cves") or []
    out.append(
        f"<details><summary>CVEs fixed by kernel advisories installed on this AMI "
        f"({len(installed_cves)}, showing up to 200)</summary>\n\n```\n"
    )
                                                                             
    for cve in installed_cves[:200]:
        out.append(f"{cve}\n")
    out.append("```\n</details>\n\n")

    installed_alas = kernel.get("installed_alas") or []
    out.append(
        f"<details><summary>Amazon Linux advisories that updated kernel packages on "
        f"this AMI ({len(installed_alas)}, showing up to 200)</summary>\n\n```\n"
    )
    for alas in installed_alas[:200]:
        out.append(f"{alas}\n")
    out.append("```\n</details>\n\n")

    out.append("## Runtime\n\n")
    runtime = build_report.get("runtime") or {}
    for k in sorted(runtime):
        v = runtime[k]
        if v:
            out.append(f"- **{k}**: `{v}`\n")
    out.append("\n")

    out.append("## /etc/eks/release\n\n```\n")
    out.append(f"{build_report.get('release', '')}\n")
    out.append("```\n\n")

    os_info = build_report.get("os") or {}
    out.append("## OS\n\n")
    out.append(f"- **name**: {os_info.get('name', '')}\n")
    out.append(f"- **version_id**: {os_info.get('version_id', '')}\n")
    out.append(f"- **pretty_name**: {os_info.get('pretty_name', '')}\n\n")

    out.append("<details><summary>Key package versions</summary>\n\n```\n")
    pkgs = version_info.get("packages") or {}
    for k in sorted(pkgs):
        if _PACKAGE_KEY_RE.match(k):
            out.append(f"{k} {pkgs[k]}\n")
    out.append("```\n</details>\n")

    return "".join(out)

def cmd_render_report(args, runner: Runner = real_runner) -> int:
    workdir = Path(args.workdir)
    manifest_path = workdir / f"{args.ami_name}-manifest.json"
    build_report_path = workdir / f"{args.ami_name}-build-report.json"
    version_info_path = workdir / f"{args.ami_name}-version-info.json"

    missing = [p for p in (manifest_path, build_report_path, version_info_path) if not p.is_file()]
    if missing:
        for p in missing:
            print(f"ERROR: missing input file {p}", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text())
    build_report = json.loads(build_report_path.read_text())
    version_info = json.loads(version_info_path.read_text())

    import os
    md = render_markdown_report(
        args.ami_name,
        manifest=manifest,
        build_report=build_report,
        version_info=version_info,
        ci_build_url=os.environ.get("CIRCLE_BUILD_URL", "local"),
        ci_branch=os.environ.get("CIRCLE_BRANCH", "unknown"),
        ci_sha=os.environ.get("CIRCLE_SHA1", "unknown"),
    )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(md)
    print(f"rendered: {out}")
    return 0

_ALAS_ROW_RE = re.compile(r"^[A-Z]+-[0-9-]+")
_CVE_ROW_RE = re.compile(r"^CVE-\S+")

def _detect_kernel_package(uname_r: str) -> str:
    if uname_r.startswith("6.12."):
        return "kernel6.12"
    if uname_r.startswith("6.18."):
        return "kernel6.18"
    return "kernel"

def _parse_updateinfo_list(
    text: str, *, only_kernel_packages: bool = False
) -> Tuple[list, list]:
    alas: set = set()
    pkgs: set = set()
    for line in text.splitlines():
        toks = line.split()
        if len(toks) < 3:
            continue
        if not _ALAS_ROW_RE.match(toks[0]):
            continue
        if only_kernel_packages and not toks[2].startswith("kernel"):
            continue
        alas.add(toks[0])
        pkgs.add(toks[2])
    return sorted(alas), sorted(pkgs)

def _parse_updateinfo_cves(text: str, *, only_kernel_packages: bool = False) -> list:
    cves: set = set()
    for line in text.splitlines():
        toks = line.split()
        if not toks:
            continue
        if not _CVE_ROW_RE.match(toks[0]):
            continue
        if only_kernel_packages and (len(toks) < 3 or not toks[2].startswith("kernel")):
            continue
        cves.add(toks[0])
    return sorted(cves)

def _parsed_first_field(text: str, field_idx: int, line_idx: int = 0) -> str:
    if not text:
        return ""
    lines = text.splitlines()
    if line_idx >= len(lines):
        return ""
    toks = lines[line_idx].split()
    if field_idx >= len(toks):
        return ""
    return toks[field_idx]

def collect_build_report(
    *,
    assert_cves: Iterable = (),
    runner: Runner = real_runner,
    os_release_path: Path = Path("/etc/os-release"),
    now_iso: Optional[str] = None,
) -> Tuple[dict, list]:
    _, uname_r, _ = runner(["uname", "-r"])
    uname_r = uname_r.strip()
    _, uname_m, _ = runner(["uname", "-m"])
    uname_m = uname_m.strip()

    kernel_pkg = _detect_kernel_package(uname_r)
    rc_k, kernel_nvr, _ = runner(["rpm", "-q", kernel_pkg])
    kernel_nvr = kernel_nvr.strip() if rc_k == 0 else "unknown"

    runner(["sudo", "dnf", "-q", "--refresh", "makecache"])

    _, pending_text, _ = runner(["sudo", "dnf", "-q", "updateinfo", "list", "security"])
    pending_alas, pending_pkgs = _parse_updateinfo_list(pending_text)
    pending_count = sum(1 for line in pending_text.splitlines() if _ALAS_ROW_RE.match(line.split()[0] if line.split() else ""))

    _, pending_cves_text, _ = runner(["sudo", "dnf", "-q", "updateinfo", "list", "cves"])
    pending_cves = _parse_updateinfo_cves(pending_cves_text)

    _, installed_cves_text, _ = runner(["sudo", "dnf", "-q", "updateinfo", "--installed", "list", "cves"])
    kernel_installed_cves = _parse_updateinfo_cves(installed_cves_text, only_kernel_packages=True)

    _, installed_list_text, _ = runner(["sudo", "dnf", "-q", "updateinfo", "--installed", "list"])
    kernel_installed_alas, _ = _parse_updateinfo_list(installed_list_text, only_kernel_packages=True)

    requested = list(assert_cves)
    missing: list = []
    if requested:
        for cve in requested:
            _, info_text, _ = runner(
                ["sudo", "dnf", "-q", "updateinfo", "--installed", "info", "--cve", cve]
            )
            if not any(re.match(r"^\s*Update ID:", l) for l in (info_text or "").splitlines()):
                missing.append(cve)
        assert_status = "failed" if missing else "ok"
    else:
        assert_status = "not_requested"

    os_info = parse_os_release(os_release_path)
    release_text = ""
    rc_r, out_r, _ = runner(["sudo", "cat", "/etc/eks/release"])
    if rc_r == 0:
        release_text = out_r

    _, containerd_v, _ = runner(["containerd", "--version"])
    _, runc_v, _ = runner(["runc", "--version"])
    _, kubelet_v, _ = runner(["kubelet", "--version"])
    _, nerdctl_v, _ = runner(["nerdctl", "--version"])
    rc_s, soci_v, _ = runner(["rpm", "-q", "--queryformat", "%{VERSION}-%{RELEASE}", "soci-snapshotter"])

    report = {
        "generated_at": now_iso or utc_iso_now(),
        "os": {
            "name": os_info.get("NAME", ""),
            "version_id": os_info.get("VERSION_ID", ""),
            "pretty_name": os_info.get("PRETTY_NAME", ""),
        },
        "release": release_text,
        "kernel": {
            "package": kernel_pkg,
            "nvr": kernel_nvr,
            "uname_r": uname_r,
            "arch": uname_m,
            "installed_cves": kernel_installed_cves,
            "installed_alas": kernel_installed_alas,
        },
        "runtime": {
            "containerd": _parsed_first_field(containerd_v, 2),
            "runc": _parsed_first_field(runc_v, 2),
            "kubelet": _parsed_first_field(kubelet_v, 1),
            "nerdctl": _parsed_first_field(nerdctl_v, 2),
            "soci_snapshotter": soci_v.strip() if rc_s == 0 else "",
        },
        "security": {
            "pending_security_count": pending_count,
            "pending_security_alas": pending_alas,
            "pending_security_pkgs": pending_pkgs,
            "pending_cves": pending_cves,
            "assertions": {
                "requested": requested,
                "status": assert_status,
                "missing": missing,
            },
        },
    }
    return report, missing

def cmd_build_report(args, runner: Runner = real_runner) -> int:
    requested = parse_csv(args.assert_cves)
    report, missing = collect_build_report(assert_cves=requested, runner=runner)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")

    kernel_nvr = report["kernel"]["nvr"]
    pending_count = report["security"]["pending_security_count"]
    assert_status = report["security"]["assertions"]["status"]
    print(
        f"build-report written to {out} (kernel={kernel_nvr}, "
        f"pending_security={pending_count}, assert={assert_status})"
    )

    if assert_status == "failed":
        print(
            f"ERROR: required CVE fixes are NOT covered by any installed "
            f"{report['kernel']['package']} advisory: {' '.join(missing)}",
            file=sys.stderr,
        )
        print(
            "Hint: AL2023 may not have published the ALAS yet, the build region's "
            "repo mirror is stale, or the kernel was not upgraded past the fix's NVR.",
            file=sys.stderr,
        )
        return 1
    return 0

def _str_to_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    s = str(value).strip().lower()
    return s in {"true", "yes", "y", "1", "on"}

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="eks_ami.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("aggregate-manifest", help="Combine Packer manifests + copies into multi-region JSON")
    p.add_argument("artifacts_dir", type=Path, help="Directory with *-manifest.json (+ optional copies/summary.tsv)")
    p.add_argument("--commit", default="")
    p.add_argument("--branch", default="")
    p.add_argument("--cves", default="", help="Comma-separated CVE IDs the build asserted")
    p.add_argument("--out", type=Path, default=None, help="Write to this file instead of stdout")
    p.set_defaults(func=cmd_aggregate_manifest)

    p = sub.add_parser("cleanup-amis", help="Retain N newest AMIs per (arch, k8s) per region")
    p.add_argument("--regions", required=True, help="Comma-separated AWS regions")
    p.add_argument("--keep", type=int, default=CLEANUP_KEEP_DEFAULT, help="AMIs to retain per type per region")
    p.add_argument("--name-prefix", default=NAME_PREFIX_DEFAULT)
    p.add_argument("--builder-tag", default=BUILDER_TAG_DEFAULT, help="Value of the Builder tag filter")
    p.add_argument("--dry-run", type=_str_to_bool, default=False, help="Print decisions without mutating AWS")
    p.add_argument("--out-dir", default="/tmp/ami-cleanup")
    p.set_defaults(func=cmd_cleanup_amis)

    p = sub.add_parser("render-report", help="Merge build-report.json + manifest + version-info into Markdown")
    p.add_argument("ami_name")
    p.add_argument("workdir", help="Directory containing the 3 sibling JSONs")
    p.add_argument("--out", required=True, help="Output Markdown file")
    p.set_defaults(func=cmd_render_report)

    p = sub.add_parser("build-report", help="(Runs on AL2023 builder) Collect kernel + CVE facts to JSON")
    p.add_argument("--out", required=True, help="Output build-report.json")
    p.add_argument("--assert-cves", default="", help="Comma-separated CVE IDs; fail if any unfixed")
    p.set_defaults(func=cmd_build_report)

    return parser

def main(argv: Optional[list] = None, runner: Runner = real_runner) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args, runner=runner)

if __name__ == "__main__":
    sys.exit(main())
