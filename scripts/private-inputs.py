#!/usr/bin/env python3
"""Supply the private flake source to flake.nix and flake.lock.

The public repository names no private repository, revision, or content hash.
The committed tree carries a placeholder, and the pinned source is supplied
from a private specification:

* continuous integration reads it from a repository secret, and
* a deployment host reads it from a root-only file outside the checkout.

Usage:
  private-inputs.py apply  --spec <file>   rewrite the tree to the real source
  private-inputs.py import --spec <file>   additionally import the source
                                            through a read-only deploy key and
                                            point the lock at the local checkout
  private-inputs.py restore                restore the committed placeholders
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

INPUT = "ghostship-private-agent"
PLACEHOLDER_URL = "path:./private-agent-source"
PLACEHOLDER_PATH = "./private-agent-source"
LOCKED_PLACEHOLDER = {
    "lastModified": 0,
    "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    "path": PLACEHOLDER_PATH,
    "type": "path",
}
ORIGINAL_PLACEHOLDER = {"path": PLACEHOLDER_PATH, "type": "path"}


def load_spec(args):
    if args.spec:
        return json.loads(Path(args.spec).read_text())
    raw = os.environ.get(args.env)
    if not raw:
        raise SystemExit(
            "Missing private source specification: pass --spec or set " + args.env
        )
    return json.loads(raw)


def spec_entry(spec):
    if INPUT not in spec:
        raise SystemExit("Private source specification has no " + INPUT + " entry")
    return spec[INPUT]


def read_tree():
    flake_nix = Path("flake.nix")
    lock_path = Path("flake.lock")
    if not flake_nix.is_file() or not lock_path.is_file():
        raise SystemExit("Run this from the repository root")
    return flake_nix, lock_path, json.loads(lock_path.read_text())


def apply_source(entry):
    """Write the real source into flake.nix and flake.lock."""
    flake_nix, lock_path, lock = read_tree()
    url = "github:{owner}/{repo}/{rev}".format(**entry)
    text = flake_nix.read_text()
    marker = 'ghostship-private-agent.url = "{0}";'.format(PLACEHOLDER_URL)
    if marker not in text:
        raise SystemExit("flake.nix does not carry the expected placeholder")
    flake_nix.write_text(text.replace(marker, 'ghostship-private-agent.url = "{0}";'.format(url), 1))

    locked = {
        "lastModified": entry.get("lastModified", 0),
        "narHash": entry["narHash"],
        "owner": entry["owner"],
        "repo": entry["repo"],
        "rev": entry["rev"],
        "type": "github",
    }
    original = {
        "owner": entry["owner"],
        "repo": entry["repo"],
        "rev": entry["rev"],
        "type": "github",
    }
    node = lock["nodes"].setdefault(INPUT, {})
    node["locked"] = locked
    node["original"] = original
    lock_path.write_text(json.dumps(lock, indent=2) + "\n")
    return locked


def restore_placeholders():
    """Put the committed placeholders back."""
    flake_nix, lock_path, lock = read_tree()
    text = flake_nix.read_text()
    marker = 'ghostship-private-agent.url = "{0}";'.format(PLACEHOLDER_URL)
    pattern = 'ghostship-private-agent.url = "github:{owner}/{repo}/{rev}";'
    for entry in re_owner_repo_rev():
        text = text.replace(
            'ghostship-private-agent.url = "github:{0}/{1}/{2}";'.format(*entry),
            marker,
        )
    if marker not in text:
        raise SystemExit("flake.nix does not carry the expected placeholder")
    flake_nix.write_text(text)
    node = lock["nodes"].setdefault(INPUT, {})
    node["locked"] = dict(LOCKED_PLACEHOLDER)
    node["original"] = dict(ORIGINAL_PLACEHOLDER)
    lock_path.write_text(json.dumps(lock, indent=2) + "\n")


def re_owner_repo_rev():
    """Every owner/repo/revision currently written into flake.nix."""
    text = Path("flake.nix").read_text()
    marker = 'ghostship-private-agent.url = "github:'
    found = []
    for line in text.splitlines():
        if marker in line:
            value = line.split(marker, 1)[1].split('"', 1)[0]
            parts = value.split("/")
            if len(parts) == 3:
                found.append(tuple(parts))
    return found


def import_source(entry, root):
    """Fetch the private source with a read-only deploy key and verify it."""
    credential = os.environ.get("GHOSTSHIP_AGENT_READ_KEY", "").strip()
    if not credential:
        raise SystemExit("Missing the scoped read-only deploy key for the private source")
    key_path = root / "agent.key"
    key_path.write_text(credential + "\n")
    key_path.chmod(0o600)
    known = root / "known_hosts"
    headers = {"User-Agent": "ghostship-private-inputs"}
    token = os.environ.pop("GITHUB_META_TOKEN", "")
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request("https://api.github.com/meta", headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        host_keys = json.load(response)["ssh_keys"]
    known.write_text("".join("github.com " + key + "\n" for key in host_keys))
    checkout = root / "checkout"
    try:
        env = {name: os.environ[name] for name in ("PATH", "HOME") if name in os.environ}
        env["GIT_SSH_COMMAND"] = (
            "ssh -i " + str(key_path)
            + " -o IdentitiesOnly=yes -o BatchMode=yes"
            + " -o StrictHostKeyChecking=yes -o UserKnownHostsFile=" + str(known)
        )
        subprocess.run(["git", "init", "-q", str(checkout)], env=env, check=True)
        subprocess.run(
            ["git", "-C", str(checkout), "fetch", "-q", "--depth=1",
             "git@github.com:{0}/{1}.git".format(entry["owner"], entry["repo"]), entry["rev"]],
            env=env, check=True,
        )
        subprocess.run(
            ["git", "-C", str(checkout), "checkout", "-q", "--detach", "FETCH_HEAD"],
            env=env, check=True,
        )
        archive = root / "source.tar"
        with archive.open("wb") as output:
            subprocess.run(
                ["git", "-C", str(checkout), "archive", "FETCH_HEAD"],
                stdout=output, env=env, check=True,
            )
        source = root / "source"
        source.mkdir()
        with tarfile.open(archive) as packed:
            packed.extractall(source, filter="data")
        actual = subprocess.check_output(["nix", "hash", "path", str(source)], text=True).strip()
        if actual != entry["narHash"]:
            raise SystemExit("Pinned private source hash mismatch")
        return checkout, source
    finally:
        key_path.unlink(missing_ok=True)
        known.unlink(missing_ok=True)
        shutil.rmtree(checkout, ignore_errors=True)


def point_lock_at_checkout(lock_path, checkout, entry):
    lock = json.loads(lock_path.read_text())
    node = lock["nodes"].setdefault(INPUT, {})
    node["locked"] = {
        "type": "git",
        "url": checkout.as_uri(),
        "rev": entry["rev"],
        "narHash": entry["narHash"],
        "lastModified": entry.get("lastModified", 0),
    }
    lock_path.write_text(json.dumps(lock, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["apply", "import", "restore"])
    parser.add_argument("--spec", help="path to the private source specification")
    parser.add_argument("--env", default="GHOSTSHIP_PRIVATE_SOURCES",
                        help="environment variable holding the specification")
    parser.add_argument("--key", help="unused; the deploy key comes from the environment")
    args = parser.parse_args()

    if args.operation == "restore":
        restore_placeholders()
        print("Restored the committed private source placeholders")
        return 0

    entry = spec_entry(load_spec(args))
    apply_source(entry)
    if args.operation == "import":
        root = Path(tempfile.mkdtemp(prefix="ghostship-private-source-"))
        try:
            checkout, _ = import_source(entry, root)
            point_lock_at_checkout(Path("flake.lock"), checkout, entry)
        finally:
            shutil.rmtree(root, ignore_errors=True)
    print("Applied the private source specification for " + INPUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
