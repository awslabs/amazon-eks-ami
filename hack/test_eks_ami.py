#!/usr/bin/env python3

from __future__ import annotations

import io
import json
import os
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import eks_ami              

def make_runner(table, default=(127, "", "unmocked")):

    class _R:
        def __init__(self):
            self.calls = []

        def __call__(self, cmd):
            self.calls.append(cmd)
            joined = " ".join(cmd)
            for needle, resp in table.items():
                if needle in joined:
                    return resp
            return default

    return _R()

def write_json(path: Path, obj) -> None:
    path.write_text(json.dumps(obj))

class TestParseArchK8s(unittest.TestCase):
    cases = [
        ("gather-eks-al2023-arm64-1.33-cve2026-31431-abc1234", ("arm64", "1.33")),
        ("gather-eks-al2023-x86_64-1.34-c176c7af7", ("x86_64", "1.34")),
        ("gather-eks-al2023-arm64-1.35", ("arm64", "1.35")),
        ("gather-eks-al2023-arm64", (None, None)),
        ("totally-unrelated-name", (None, None)),
        ("", (None, None)),
                       
        ("custom-foo-arm64-1.33-abc", ("arm64", "1.33")),
    ]

    def test_canonical_prefix(self):
        for name, want in self.cases[:6]:
            with self.subTest(name=name):
                self.assertEqual(eks_ami.parse_arch_k8s(name), want)

    def test_custom_prefix(self):
        name, want = self.cases[6]
        self.assertEqual(eks_ami.parse_arch_k8s(name, name_prefix="custom-foo-"), want)

class TestAggregateManifest(unittest.TestCase):
    def _fixture(self, td: Path) -> None:
                                             
        write_json(
            td / "gather-eks-al2023-arm64-1.33-cveXX-c176c7af-manifest.json",
            {"builds": [{"artifact_id": "us-east-1:ami-aaa"}]},
        )
        write_json(
            td / "gather-eks-al2023-x86_64-1.34-c176c7af-manifest.json",
            {"builds": [{"artifact_id": "us-east-1:ami-bbb"}]},
        )
                                                            
        write_json(td / "totally-unrelated-manifest.json", {"builds": [{"artifact_id": "us-east-1:ami-zzz"}]})
        (td / "copies").mkdir()
        (td / "copies/summary.tsv").write_text(
            "source_ami\tami_name\tregion\tcopy_ami_id\n"
            "ami-aaa\tgather-eks-al2023-arm64-1.33-cveXX-c176c7af\teu-central-1\tami-ccc\n"
            "ami-aaa\tgather-eks-al2023-arm64-1.33-cveXX-c176c7af\tap-northeast-1\tami-ddd\n"
            "ami-bbb\tgather-eks-al2023-x86_64-1.34-c176c7af\teu-central-1\tami-eee\n"
            "ami-zzz\ttotally-unrelated\teu-west-1\tami-fff\n"
        )

    def test_combines_packer_and_copies(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            self._fixture(d)
            manifest = eks_ami.build_aggregate_manifest(
                d, commit="c176c7af1", branch="my-branch", cves=["CVE-2026-31431"], now_iso="2026-05-22T10:00:00Z"
            )
        self.assertEqual(manifest["commit"], "c176c7af1")
        self.assertEqual(manifest["branch"], "my-branch")
        self.assertEqual(manifest["cves_addressed"], ["CVE-2026-31431"])
        self.assertEqual(manifest["build_date"], "2026-05-22T10:00:00Z")
        amis = manifest["amis"]
        self.assertEqual(amis["us-east-1"]["arm64"]["1.33"], "ami-aaa")
        self.assertEqual(amis["us-east-1"]["x86_64"]["1.34"], "ami-bbb")
        self.assertEqual(amis["eu-central-1"]["arm64"]["1.33"], "ami-ccc")
        self.assertEqual(amis["ap-northeast-1"]["arm64"]["1.33"], "ami-ddd")
        self.assertEqual(amis["eu-central-1"]["x86_64"]["1.34"], "ami-eee")
        self.assertNotIn("eu-west-1", amis, "unparseable name must be dropped")

    def test_empty_artifacts_dir_yields_empty_amis(self):
        with tempfile.TemporaryDirectory() as td:
            manifest = eks_ami.build_aggregate_manifest(Path(td), now_iso="t")
        self.assertEqual(manifest["amis"], {})
        self.assertEqual(manifest["cves_addressed"], [])

    def test_cli_writes_to_out(self):
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            self._fixture(d)
            out = d / "manifest.json"
            buf_err = io.StringIO()
            with redirect_stderr(buf_err):
                rc = eks_ami.main([
                    "aggregate-manifest", str(d),
                    "--commit", "abc", "--branch", "br", "--cves", "CVE-1, CVE-2",
                    "--out", str(out),
                ])
            self.assertEqual(rc, 0)
            data = json.loads(out.read_text())
            self.assertEqual(data["cves_addressed"], ["CVE-1", "CVE-2"])
            self.assertIn("us-east-1", data["amis"])
                                                                             
            self.assertIn("totally-unrelated-manifest.json", buf_err.getvalue())

class TestComputeCleanupDecisions(unittest.TestCase):
    def _img(self, name: str, ami_id: str, creation_date: str, snap: str = "") -> dict:
        return {"Name": name, "ImageId": ami_id, "CreationDate": creation_date, "SnapshotId": snap}

    def test_keeps_n_newest_per_type(self):
        imgs = [
            self._img(f"gather-eks-al2023-arm64-1.33-v{i}", f"ami-a{i}", f"2026-05-{15+i:02d}T00:00:00.000Z")
            for i in range(7)
        ]
        decisions, skipped = eks_ami.compute_cleanup_decisions(imgs, name_prefix=eks_ami.NAME_PREFIX_DEFAULT, keep=5)
        self.assertEqual(skipped, [])
        actions = [d[0] for d in decisions]
        self.assertEqual(actions.count("KEEP"), 5)
        self.assertEqual(actions.count("DELETE"), 2)
                                                                                                             
        deleted_dates = [d[2]["CreationDate"] for d in decisions if d[0] == "DELETE"]
        self.assertEqual(deleted_dates, ["2026-05-16T00:00:00.000Z", "2026-05-15T00:00:00.000Z"])

    def test_groups_by_type(self):
        imgs = [
            self._img("gather-eks-al2023-arm64-1.33-a", "ami-1", "2026-05-21T00:00:00Z"),
            self._img("gather-eks-al2023-arm64-1.33-b", "ami-2", "2026-05-20T00:00:00Z"),
            self._img("gather-eks-al2023-x86_64-1.33-a", "ami-3", "2026-05-21T00:00:00Z"),
            self._img("gather-eks-al2023-x86_64-1.33-b", "ami-4", "2026-05-20T00:00:00Z"),
            self._img("gather-eks-al2023-arm64-1.34-a", "ami-5", "2026-05-21T00:00:00Z"),
        ]
        decisions, skipped = eks_ami.compute_cleanup_decisions(imgs, name_prefix=eks_ami.NAME_PREFIX_DEFAULT, keep=1)
        self.assertEqual(skipped, [])
                                                                                
        kept = [(d[1], d[2]["ImageId"]) for d in decisions if d[0] == "KEEP"]
        deleted = [(d[1], d[2]["ImageId"]) for d in decisions if d[0] == "DELETE"]
        self.assertEqual(sorted(kept), [("arm64-1.33", "ami-1"), ("arm64-1.34", "ami-5"), ("x86_64-1.33", "ami-3")])
        self.assertEqual(sorted(deleted), [("arm64-1.33", "ami-2"), ("x86_64-1.33", "ami-4")])

    def test_unparseable_name_is_skipped_not_deleted(self):
        imgs = [
            self._img("gather-eks-al2023-arm64-1.33-a", "ami-1", "2026-05-21T00:00:00Z"),
            self._img("totally-unrelated", "ami-2", "2026-05-20T00:00:00Z"),
        ]
        decisions, skipped = eks_ami.compute_cleanup_decisions(imgs, name_prefix=eks_ami.NAME_PREFIX_DEFAULT, keep=5)
        self.assertEqual([s["ImageId"] for s in skipped], ["ami-2"])
        self.assertEqual([(d[0], d[2]["ImageId"]) for d in decisions], [("KEEP", "ami-1")])

class TestCleanupCli(unittest.TestCase):
    def test_dry_run_does_not_call_deregister_or_delete_snapshot(self):
                                                                                
        describe_payload = json.dumps({
            "Images": [
                {
                    "Name": "gather-eks-al2023-arm64-1.33-new",
                    "ImageId": "ami-new",
                    "CreationDate": "2026-05-21T00:00:00.000Z",
                    "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-new"}}],
                },
                {
                    "Name": "gather-eks-al2023-arm64-1.33-old",
                    "ImageId": "ami-old",
                    "CreationDate": "2026-05-20T00:00:00.000Z",
                    "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-old"}}],
                },
            ]
        })
        runner = make_runner({"ec2 describe-images": (0, describe_payload, "")})
        with tempfile.TemporaryDirectory() as td:
            args = SimpleNamespace(
                regions="us-east-1",
                keep=1,
                name_prefix=eks_ami.NAME_PREFIX_DEFAULT,
                builder_tag=eks_ami.BUILDER_TAG_DEFAULT,
                dry_run=True,
                out_dir=td,
            )
            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = eks_ami.cmd_cleanup_amis(args, runner=runner)
            self.assertEqual(rc, 0)
                                                       
            for call in runner.calls:
                self.assertNotIn("deregister-image", call)
                self.assertNotIn("delete-snapshot", call)
            summary = (Path(td) / "summary.tsv").read_text().splitlines()
            self.assertEqual(summary[0].split("\t"), list(eks_ami.CLEANUP_HEADER))
            actions = [row.split("\t")[2] for row in summary[1:]]
            self.assertEqual(sorted(actions), ["DELETE", "KEEP"])
                                                          
            delete_row = next(r for r in summary[1:] if r.split("\t")[2] == "DELETE")
            self.assertEqual(delete_row.split("\t")[-1], "dry-run")

    def test_real_run_calls_deregister_and_delete_snapshot(self):
        describe_payload = json.dumps({
            "Images": [
                {
                    "Name": "gather-eks-al2023-arm64-1.33-new",
                    "ImageId": "ami-new",
                    "CreationDate": "2026-05-21T00:00:00.000Z",
                    "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-new"}}],
                },
                {
                    "Name": "gather-eks-al2023-arm64-1.33-old",
                    "ImageId": "ami-old",
                    "CreationDate": "2026-05-20T00:00:00.000Z",
                    "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-old"}}],
                },
            ]
        })
        runner = make_runner({
            "ec2 describe-images": (0, describe_payload, ""),
            "ec2 deregister-image": (0, "", ""),
            "ec2 delete-snapshot": (0, "", ""),
        })
        with tempfile.TemporaryDirectory() as td:
            args = SimpleNamespace(
                regions="us-east-1", keep=1, name_prefix=eks_ami.NAME_PREFIX_DEFAULT,
                builder_tag=eks_ami.BUILDER_TAG_DEFAULT, dry_run=False, out_dir=td,
            )
            with redirect_stdout(io.StringIO()):
                rc = eks_ami.cmd_cleanup_amis(args, runner=runner)
            self.assertEqual(rc, 0)
        joined = [" ".join(c) for c in runner.calls]
        self.assertTrue(any("deregister-image --image-id ami-old" in c for c in joined))
        self.assertTrue(any("delete-snapshot --snapshot-id snap-old" in c for c in joined))
                                                       
        self.assertFalse(any("deregister-image --image-id ami-new" in c for c in joined))
        self.assertFalse(any("delete-snapshot --snapshot-id snap-new" in c for c in joined))

    def test_returns_2_when_aws_call_fails(self):
        describe_payload = json.dumps({
            "Images": [
                {"Name": "gather-eks-al2023-arm64-1.33-old", "ImageId": "ami-old",
                 "CreationDate": "2026-05-20T00:00:00.000Z",
                 "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-old"}}]},
                {"Name": "gather-eks-al2023-arm64-1.33-new", "ImageId": "ami-new",
                 "CreationDate": "2026-05-21T00:00:00.000Z",
                 "BlockDeviceMappings": [{"Ebs": {"SnapshotId": "snap-new"}}]},
            ]
        })
                                                         
        runner = make_runner({
            "ec2 describe-images": (0, describe_payload, ""),
            "ec2 deregister-image": (255, "", "permission denied"),
            "ec2 delete-snapshot": (0, "", ""),
        })
        with tempfile.TemporaryDirectory() as td:
            args = SimpleNamespace(
                regions="us-east-1", keep=1, name_prefix=eks_ami.NAME_PREFIX_DEFAULT,
                builder_tag=eks_ami.BUILDER_TAG_DEFAULT, dry_run=False, out_dir=td,
            )
            with redirect_stdout(io.StringIO()):
                rc = eks_ami.cmd_cleanup_amis(args, runner=runner)
        self.assertEqual(rc, 2)

class TestRenderReport(unittest.TestCase):
    def _inputs(self) -> dict:
        return {
            "ami_name": "gather-eks-al2023-arm64-1.33-cve2026-31431-abc1234",
            "manifest": {
                "builds": [{
                    "artifact_id": "us-east-1:ami-aaa,eu-central-1:ami-bbb",
                    "build_time": 1234567890,
                    "custom_data": {"source_ami_id": "ami-src", "source_ami_name": "al2023-source"},
                }]
            },
            "build_report": {
                "kernel": {
                    "package": "kernel6.12",
                    "nvr": "kernel6.12-6.12.5-100.amzn2023",
                    "uname_r": "6.12.5-100.amzn2023.aarch64",
                    "arch": "aarch64",
                    "installed_cves": [f"CVE-2026-{i:05d}" for i in range(250)],
                    "installed_alas": ["ALAS-2026-1234", "ALAS-2026-1235"],
                },
                "runtime": {"containerd": "2.0.5", "runc": "1.2.0", "kubelet": "v1.33.0", "nerdctl": "2.0.0"},
                "security": {
                    "pending_security_count": 1,
                    "pending_security_alas": ["ALAS-2026-9999"],
                    "pending_security_pkgs": ["bash"],
                    "pending_cves": ["CVE-2026-9999"],
                    "assertions": {
                        "requested": ["CVE-2026-31431"], "status": "ok", "missing": [],
                    },
                },
                "release": "BASE_AMI_ID=ami-src\nBUILD_TIME=...",
                "os": {"name": "Amazon Linux", "version_id": "2023", "pretty_name": "Amazon Linux 2023"},
            },
            "version_info": {
                "packages": {
                    "kernel6.12.x86_64": "6.12.5-100.amzn2023",
                    "containerd.x86_64": "2.0.5-1.amzn2023",
                    "unrelated.x86_64": "1.0.0",
                }
            },
        }

    def test_pass_badge_and_truncation(self):
        i = self._inputs()
        md = eks_ami.render_markdown_report(
            i["ami_name"], manifest=i["manifest"], build_report=i["build_report"], version_info=i["version_info"],
            ci_build_url="https://ci/123", ci_branch="my-branch", ci_sha="deadbeef",
        )
        self.assertIn("## CVE assertion: PASS", md)
        self.assertIn("- Status: `ok`", md)
        self.assertIn("- Missing: `none`", md)
        self.assertIn("**Built AMI:** `ami-aaa` in `us-east-1`", md)
        self.assertIn("**Branch / SHA:** `my-branch` @ `deadbeef`", md)
                                                                     
        listing = re.search(
            r"<details><summary>CVEs fixed by kernel advisories[\s\S]*?</details>", md
        )
        self.assertIsNotNone(listing, "CVE listing details block missing")
        self.assertEqual(
            len(re.findall(r"CVE-2026-\d{5}", listing.group(0))),
            200,
            "listing must show only first 200 of 250 CVEs",
        )
                                                        
        self.assertIn("ALAS-2026-9999", md)
                                                  
        self.assertIn("kernel6.12.x86_64 6.12.5-100.amzn2023", md)
        self.assertIn("containerd.x86_64 2.0.5-1.amzn2023", md)
        self.assertNotIn("unrelated.x86_64", md)

    def test_fail_badge_with_missing_cves(self):
        i = self._inputs()
        i["build_report"]["security"]["assertions"] = {
            "requested": ["CVE-X", "CVE-Y"], "status": "failed", "missing": ["CVE-Y"],
        }
        md = eks_ami.render_markdown_report(
            i["ami_name"], manifest=i["manifest"], build_report=i["build_report"], version_info=i["version_info"],
        )
        self.assertIn("## CVE assertion: FAIL", md)
        self.assertIn("- Missing: `CVE-Y`", md)

    def test_not_requested_badge(self):
        i = self._inputs()
        i["build_report"]["security"]["assertions"] = {
            "requested": [], "status": "not_requested", "missing": [],
        }
        md = eks_ami.render_markdown_report(
            i["ami_name"], manifest=i["manifest"], build_report=i["build_report"], version_info=i["version_info"],
        )
        self.assertIn("## CVE assertion: N/A", md)
        self.assertIn("- Requested: `none`", md)

class TestBuildReport(unittest.TestCase):
    def _ok_runner(self):
                                                                           
        installed_kernel_cves = (
            "CVE-2026-31431 important/Sec. kernel6.12-0:6.12.5-100.amzn2023\n"
            "CVE-2026-12345 moderate/Sec.  kernel6.12-0:6.12.5-100.amzn2023\n"
            "CVE-2026-67890 important/Sec. systemd-0:255.4-1.amzn2023\n"                                
        )
        installed_alas_list = (
            "ALAS-2026-001 Important/Sec.   kernel6.12-0:6.12.5-100.amzn2023\n"
            "ALAS-2026-002 Moderate/Sec.    kernel6.12-0:6.12.5-100.amzn2023\n"
            "ALAS-2026-003 Low/Sec.         bash-0:5.2.21-1.amzn2023\n"              
        )
        pending_security = (
            "ALAS-2026-100 Important/Sec.   curl-0:8.5.0-1.amzn2023\n"
            "ALAS-2026-101 Moderate/Sec.    glibc-0:2.39-1.amzn2023\n"
        )
        info_with_update_id = "    Update ID: ALAS-2026-001\n    Type    : security\n"
        return make_runner({
            "uname -r": (0, "6.12.5-100.amzn2023.aarch64\n", ""),
            "uname -m": (0, "aarch64\n", ""),
            "rpm -q kernel6.12": (0, "kernel6.12-6.12.5-100.amzn2023.aarch64\n", ""),
            "dnf -q --refresh makecache": (0, "", ""),
            "dnf -q updateinfo list security": (0, pending_security, ""),
            "dnf -q updateinfo list cves": (0, "CVE-2026-9999 important/Sec. curl-0:8.5.0-1.amzn2023\n", ""),
            "dnf -q updateinfo --installed list cves": (0, installed_kernel_cves, ""),
            "dnf -q updateinfo --installed list": (0, installed_alas_list, ""),
                                                                             
            "dnf -q updateinfo --installed info --cve CVE-2026-31431": (0, info_with_update_id, ""),
            "dnf -q updateinfo --installed info --cve CVE-MISSING": (0, "  (no advisory info)\n", ""),
            "cat /etc/eks/release": (0, "BASE_AMI_ID=ami-src\n", ""),
            "containerd --version": (0, "containerd github.com/containerd/containerd 2.0.5\n", ""),
            "runc --version": (0, "runc version 1.2.0\n", ""),
            "kubelet --version": (0, "Kubernetes v1.33.0\n", ""),
            "nerdctl --version": (0, "nerdctl version 2.0.0\n", ""),
            "rpm -q --queryformat": (0, "0.7.0-1.amzn2023", ""),
        })

    def test_assertion_ok_when_update_id_present(self):
        runner = self._ok_runner()
        report, missing = eks_ami.collect_build_report(
            assert_cves=["CVE-2026-31431"], runner=runner,
            os_release_path=Path("/this/path/does/not/exist"),
            now_iso="2026-05-22T10:00:00Z",
        )
        self.assertEqual(missing, [])
        self.assertEqual(report["security"]["assertions"]["status"], "ok")
        self.assertEqual(report["security"]["assertions"]["requested"], ["CVE-2026-31431"])
                                                                           
        self.assertIn("CVE-2026-31431", report["kernel"]["installed_cves"])
        self.assertIn("CVE-2026-12345", report["kernel"]["installed_cves"])
        self.assertNotIn("CVE-2026-67890", report["kernel"]["installed_cves"])
                                           
        self.assertIn("ALAS-2026-001", report["kernel"]["installed_alas"])
        self.assertIn("ALAS-2026-002", report["kernel"]["installed_alas"])
        self.assertNotIn("ALAS-2026-003", report["kernel"]["installed_alas"])
                          
        self.assertEqual(report["runtime"]["containerd"], "2.0.5")
        self.assertEqual(report["runtime"]["runc"], "1.2.0")
        self.assertEqual(report["runtime"]["kubelet"], "v1.33.0")
        self.assertEqual(report["runtime"]["nerdctl"], "2.0.0")
        self.assertEqual(report["runtime"]["soci_snapshotter"], "0.7.0-1.amzn2023")
                            
        self.assertEqual(report["security"]["pending_security_count"], 2)
        self.assertEqual(report["security"]["pending_security_alas"], ["ALAS-2026-100", "ALAS-2026-101"])
                                  
        self.assertEqual(report["kernel"]["package"], "kernel6.12")

    def test_assertion_failed_when_no_update_id(self):
        runner = self._ok_runner()
        report, missing = eks_ami.collect_build_report(
            assert_cves=["CVE-2026-31431", "CVE-MISSING"], runner=runner,
            os_release_path=Path("/this/path/does/not/exist"),
        )
        self.assertEqual(missing, ["CVE-MISSING"])
        self.assertEqual(report["security"]["assertions"]["status"], "failed")
        self.assertEqual(report["security"]["assertions"]["missing"], ["CVE-MISSING"])

    def test_not_requested_when_empty(self):
        runner = self._ok_runner()
        report, missing = eks_ami.collect_build_report(
            assert_cves=[], runner=runner,
            os_release_path=Path("/this/path/does/not/exist"),
        )
        self.assertEqual(missing, [])
        self.assertEqual(report["security"]["assertions"]["status"], "not_requested")

    def test_kernel_package_detection(self):
        cases = [
            ("6.12.5-100.amzn2023.aarch64", "kernel6.12"),
            ("6.18.1-200.amzn2023.x86_64", "kernel6.18"),
            ("5.10.999-99.amzn2023.x86_64", "kernel"),
        ]
        for uname_r, expected in cases:
            with self.subTest(uname_r=uname_r):
                self.assertEqual(eks_ami._detect_kernel_package(uname_r), expected)

    def test_os_release_parsing(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "os-release"
            p.write_text('NAME="Amazon Linux"\nVERSION_ID="2023"\nPRETTY_NAME="Amazon Linux 2023"\nID=amzn\n')
            info = eks_ami.parse_os_release(p)
        self.assertEqual(info["NAME"], "Amazon Linux")
        self.assertEqual(info["VERSION_ID"], "2023")
        self.assertEqual(info["PRETTY_NAME"], "Amazon Linux 2023")

    def test_cli_writes_json_and_exits_nonzero_on_fail(self):
        runner = self._ok_runner()
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "build-report.json"
            args = SimpleNamespace(out=str(out), assert_cves="CVE-MISSING")
            buf_out, buf_err = io.StringIO(), io.StringIO()
            with redirect_stdout(buf_out), redirect_stderr(buf_err):
                rc = eks_ami.cmd_build_report(args, runner=runner)
            self.assertEqual(rc, 1, f"stderr was: {buf_err.getvalue()!r}")
            data = json.loads(out.read_text())
            self.assertEqual(data["security"]["assertions"]["status"], "failed")
            self.assertIn("ERROR: required CVE fixes are NOT covered", buf_err.getvalue())

class TestSmallHelpers(unittest.TestCase):
    def test_parse_csv(self):
        self.assertEqual(eks_ami.parse_csv(""), [])
        self.assertEqual(eks_ami.parse_csv("a,b,c"), ["a", "b", "c"])
        self.assertEqual(eks_ami.parse_csv(" a , , b "), ["a", "b"])
        self.assertEqual(eks_ami.parse_csv(None or ""), [])

    def test_str_to_bool(self):
        for v in (True, "true", "TRUE", "yes", "Y", "1", "on"):
            self.assertTrue(eks_ami._str_to_bool(v), v)
        for v in (False, "", None, "false", "0", "no", "off", "anything"):
            self.assertFalse(eks_ami._str_to_bool(v), v)

    def test_parsed_first_field(self):
        self.assertEqual(eks_ami._parsed_first_field("a b c\nd e f", 1), "b")
        self.assertEqual(eks_ami._parsed_first_field("a b c\nd e f", 1, line_idx=1), "e")
        self.assertEqual(eks_ami._parsed_first_field("only-one", 5), "")
        self.assertEqual(eks_ami._parsed_first_field("", 0), "")

if __name__ == "__main__":
    unittest.main()
