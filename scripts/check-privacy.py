#!/usr/bin/env python3
"""Reject personal or account data that must not reach a public tree.

Every repository in this fleet is treated as public, so this check runs over
the tracked files and fails on anything that reads as a person's identity or a
private account. The detectors are category based: they name no private
value, so the check itself stays publishable.

Intentional public identifiers are listed in scripts/privacy-allowlist.txt
with the reason they are public. A file of exact private values may be
supplied with --patterns for an exact match pass; that file is never tracked.

Exit status is 0 when the tree is clean and 1 when a finding is reported.
"""

import argparse
import re
import pathlib
import subprocess
import sys
from pathlib import Path

ALLOWLIST = Path(__file__).resolve().parent / "privacy-allowlist.txt"

# An email address. The local part is what identifies a person; the domain
# only narrows the provider.
EMAIL = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")

# An owner/name path for a source repository, in a forge context. A bare
# owner/name pair is far too common in prose to be a useful signal.
REPO_PATH = re.compile(
    r"(?<!api\.)"
    r"(?:github\.com[:/]|github:|ghcr\.io/)"
    r"([A-Za-z0-9][A-Za-z0-9._-]*)/([A-Za-z0-9][A-Za-z0-9._-]*)"
)

# A Windows profile directory, which carries the account name.
WINDOWS_USER = re.compile(r"[A-Za-z]:\\Users\\([^\\\s\"']+)")

# A home directory that carries an account name.
HOME_USER = re.compile(r"/home/([a-z][a-z0-9_-]*)/")

# A hexadecimal account identifier: a cloud account id, a ticket id, a
# long-lived device id. A forty character revision is a source reference and
# is not an account identifier.
ACCOUNT_ID = re.compile(r"\b[0-9a-f]{32}\b")

# An OAuth client identifier, which is public by construction but must be
# listed so a new one is reviewed.
CLIENT_ID = re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")

CATEGORIES = {
    "email": EMAIL,
    "repository-path": REPO_PATH,
    "windows-account": WINDOWS_USER,
    "home-account": HOME_USER,
    "account-identifier": ACCOUNT_ID,
    "oauth-client-id": CLIENT_ID,
}

# Paths whose content is an allowlist, a fixture, or a generated index.
SKIP_PATHS = (
    "scripts/privacy-allowlist.txt",
    "scripts/check-privacy.py",
    "tests/test_privacy_check.py",
)


def load_allowlist():
    """Exact values and suffix patterns that are intentionally public."""
    allowed = set()
    allowed_suffixes = set()
    reasons = {}
    for raw in ALLOWLIST.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        value, _, reason = line.partition("#")
        value = value.strip()
        if not value:
            continue
        if value.startswith("suffix:"):
            allowed_suffixes.add(value[len("suffix:"):].strip())
        else:
            allowed.add(value)
        reasons[value] = reason.strip()
    return allowed, allowed_suffixes, reasons


def committed_files():
    """Paths in the published tree."""
    result = subprocess.run(
        ["git", "ls-tree", "-r", "-z", "--name-only", "HEAD"],
        capture_output=True, text=True, check=True,
    )
    for name in result.stdout.split("\0"):
        if name and name not in SKIP_PATHS:
            yield name


def committed_content(path):
    result = subprocess.run(
        ["git", "show", "HEAD:" + path], capture_output=True, check=False
    )
    if result.returncode != 0:
        return None
    return result.stdout.decode("utf-8", errors="replace")


def tracked_files():
    result = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, text=True, check=True
    )
    for name in result.stdout.split("\0"):
        if name and name not in SKIP_PATHS:
            yield name


def working_content(path):
    try:
        return pathlib.Path(path).read_text(errors="replace")
    except OSError:
        return None


def is_binary(path):
    try:
        with open(path, "rb") as handle:
            chunk = handle.read(4096)
    except OSError:
        return True
    return b"\0" in chunk


def load_patterns(path):
    if not path:
        return []
    values = []
    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            values.append(line)
    return values


def scan(patterns, files=None, source="committed"):
    """Scan for private data.

    The default source is the published tree, so the result does not depend on
    a local working state. A deployment supplies the private flake source into
    the working tree before evaluation, and that substitution must not read as
    a finding.
    """
    allowed, allowed_suffixes, reasons = load_allowlist()
    findings = []
    reader = committed_content if source == "committed" else working_content
    for name in (tracked_files() if files is None else files):
        if source == "working-tree":
            path = Path(name)
            if not path.is_file() or is_binary(name):
                continue
        text = reader(name)
        if text is None:
            continue
        lines = text.splitlines()
        for number, line in enumerate(lines, 1):
            for category, pattern in CATEGORIES.items():
                for match in pattern.finditer(line):
                    value = match.group(0)
                    if category == "repository-path":
                        value = match.group(1) + "/" + match.group(2)
                    if "<" in value or ">" in value:
                        # A documented placeholder, not a value.
                        continue
                    if value in allowed:
                        continue
                    if any(value.endswith(suffix) for suffix in allowed_suffixes):
                        continue
                    findings.append((name, number, category, value, reasons.get(value, "")))
    for value in patterns:
        for name in (tracked_files() if files is None else files):
            if source == "working-tree":
                path = Path(name)
                if not path.is_file() or is_binary(name):
                    continue
            text = reader(name)
            if text is None:
                continue
            for number, line in enumerate(text.splitlines(), 1):
                if value in line:
                    findings.append((name, number, "exact-private-value", "<redacted>", ""))
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--patterns", help="file of exact private values; never tracked")
    parser.add_argument("--source", choices=["committed", "working-tree"],
                        default="committed",
                        help="scan the published tree or the working tree")
    args = parser.parse_args()

    findings = scan(load_patterns(args.patterns), source=args.source)
    if not findings:
        print("Privacy check passed")
        return 0

    by_category = {}
    for name, number, category, value, reason in findings:
        by_category.setdefault(category, []).append((name, number, value, reason))
    print("Privacy findings by category:")
    for category in sorted(by_category):
        entries = by_category[category]
        print("  {0}: {1}".format(category, len(entries)))
        for name, number, value, reason in sorted(entries)[:40]:
            print("    {0}:{1}  {2}{3}".format(
                name, number, value, "  (allowed: {0})".format(reason) if reason else ""))
        if len(entries) > 40:
            print("    ... {0} more".format(len(entries) - 40))
    print("Total findings: {0}".format(len(findings)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
