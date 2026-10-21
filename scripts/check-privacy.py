#!/usr/bin/env python3
"""Reject personal or account data that must not reach a public tree.

Every repository in this fleet is treated as public, so this check runs over
the published tree and fails on anything that reads as a person's identity or
a private account. The detectors are category based: they name no private
value, so the check itself stays publishable.

Two kinds of finding are reported, and they are not the same claim:

  category-heuristic      the shape of the value looks like personal or
                          account data. This says the shape is present, not
                          that the value is private. A reviewer decides.
  proven-private-mapping  the value is an exact match against a value set the
                          operator holds privately. That set is never tracked
                          and never enters the repository.

Nothing this script prints contains a detected value. A finding is reported as
its category, its path, and its line, so a continuous integration log can
never become a disclosure channel.

Intentional public identifiers are listed in scripts/privacy-allowlist.txt
with the reason they are public. A file of exact private values may be
supplied with --patterns for the proven pass; that file is never tracked.

Exit status is 0 when the tree is clean and 1 when a finding is reported.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from source_privacy import PolicyError, load_allowlist as read_allowlist, validate_lock

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

# The fields of a private source specification. A specification that names a
# repository, a revision, and a content hash as separate fields is the
# discovery chain for a private repository, so it is detected wherever it
# appears outside the committed lock file. A value in angle brackets is a
# documented placeholder, not a specification.
SPEC_FIELD = re.compile(r'"(owner|repo|rev|narHash)"\s*:\s*"([^"]*)"')
SPEC_PLACEHOLDER = re.compile(r"^<[^>]*>$")
SPEC_FIELDS = {"owner", "repo", "rev", "narHash"}

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

# Lock files are parsed and every source is validated, rather than exempted.
# These tests carry synthetic specifications by design.
SPEC_EXEMPT_PATHS = (
    "tests/test_private_inputs.py",
    "tests/test_render_config.py",
)

# The boundaries this check cannot see. They are reported so the claim the
# check supports stays bounded by measurement.
BOUNDARIES = (
    "a value split across lines or tokens, unless the whitespace-collapsed "
    "form of the file still contains it",
    "a value inside a file the tool reads as binary",
    "a value in an untracked file, which is not part of the published tree",
    "a value written with confusable or homoglyph characters",
    "a value whose shape matches no category heuristic and is not in the "
    "operator's private value set",
)


def load_allowlist():
    """Exact values and suffix patterns that are intentionally public."""
    return read_allowlist(ALLOWLIST)


def committed_files():
    """Paths in the published tree."""
    result = subprocess.run(
        ["git", "ls-tree", "-r", "-z", "--name-only", "HEAD"],
        capture_output=True, check=False,
    )
    for name in result.stdout.decode("utf-8", errors="replace").split("\0"):
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
        ["git", "ls-files", "-z"], capture_output=True, check=False
    )
    for name in result.stdout.decode("utf-8", errors="replace").split("\0"):
        if name and name not in SKIP_PATHS:
            yield name


def working_content(path):
    try:
        return Path(path).read_text(errors="replace")
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


def exact_pattern(value):
    """A pattern that matches a whole identifier, not a prefix of one.

    A private repository name is often the start of a longer public
    identifier, for example an image path that adds a suffix. Matching on the
    identifier boundary keeps a public value from reading as a private one.
    """
    if "/" in value:
        left = r"(?<![A-Za-z0-9._/-])"
        right = r"(?![A-Za-z0-9._-])"
    else:
        left = r"(?<![A-Za-z0-9._%+-])"
        right = r"(?![A-Za-z0-9_-])"
    return re.compile(left + re.escape(value) + right)


def exact_occurrences(text, value):
    """How many times the value appears as a whole identifier."""
    return len(exact_pattern(value).findall(text))


def collapse(text):
    """The file with all whitespace removed.

    A value written across two lines, or with tokens split by a space, still
    appears in this form. The check looks for it there as well, so that a
    simple split does not defeat it.
    """
    return re.sub(r"\s+", "", text)


def make_finding(kind, category, file, line):
    """A finding carries no value. Only its category, path, and line."""
    return {"kind": kind, "category": category, "file": file, "line": line}


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
    coverage = {"scanned": 0, "binary": 0, "unreadable": 0}
    for name in (tracked_files() if files is None else files):
        if source == "working-tree":
            path = Path(name)
            if not path.is_file():
                continue
            if is_binary(name):
                coverage["binary"] += 1
                continue
        text = reader(name)
        if text is None:
            coverage["unreadable"] += 1
            continue
        coverage["scanned"] += 1
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
                    findings.append(
                        make_finding("category-heuristic", category, name, number))
        if Path(name).name == "flake.lock":
            try:
                validate_lock(text, require_placeholder=(name == "flake.lock"), allowed=allowed)
            except PolicyError as error:
                findings.append(make_finding("category-heuristic", str(error), name, 0))
        elif name not in SPEC_EXEMPT_PATHS:
            spec_fields = {
                match.group(1)
                for match in SPEC_FIELD.finditer(text)
                if not SPEC_PLACEHOLDER.match(match.group(2))
            }
            if len(spec_fields & SPEC_FIELDS) >= 3:
                findings.append(
                    make_finding("category-heuristic", "private-source-specification",
                                 name, 0))
    if patterns:
        collapsed_cache = {}
        for name in (tracked_files() if files is None else files):
            if source == "working-tree":
                path = Path(name)
                if not path.is_file() or is_binary(name):
                    continue
            text = reader(name)
            if text is None:
                continue
            if name not in collapsed_cache:
                collapsed_cache[name] = collapse(text)
            folded = collapsed_cache[name]
            for number, line in enumerate(text.splitlines(), 1):
                for value in patterns:
                    if exact_occurrences(line, value):
                        findings.append(
                            make_finding("proven-private-mapping", "exact-value",
                                         name, number))
                        break
            for value in patterns:
                if value and exact_occurrences(folded, "".join(value.split())):
                    findings.append(
                        make_finding("proven-private-mapping", "exact-value",
                                     name, 0))
    return findings, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--patterns", help="file of exact private values; never tracked")
    parser.add_argument("--source", choices=["committed", "working-tree"],
                        default="committed",
                        help="scan the published tree or the working tree")
    args = parser.parse_args()

    findings, coverage = scan(load_patterns(args.patterns), source=args.source)
    print("Coverage: {0} files scanned, {1} binary, {2} unreadable".format(
        coverage["scanned"], coverage["binary"], coverage["unreadable"]))
    if not findings:
        print("Privacy check passed")
        print("Unscannable boundaries:")
        for boundary in BOUNDARIES:
            print("  - " + boundary)
        return 0

    grouped = {}
    for finding in findings:
        key = (finding["kind"], finding["category"])
        grouped.setdefault(key, []).append(finding)
    print("Privacy findings:")
    for kind in ("category-heuristic", "proven-private-mapping"):
        for (finding_kind, category), entries in sorted(grouped.items()):
            if finding_kind != kind:
                continue
            print("  {0} / {1}: {2}".format(kind, category, len(entries)))
            for entry in sorted(entries, key=lambda item: (item["file"], item["line"]))[:40]:
                print("    {0}:{1}".format(entry["file"], entry["line"]))
            if len(entries) > 40:
                print("    ... {0} more".format(len(entries) - 40))
    print("Total findings: {0}".format(len(findings)))
    print("Unscannable boundaries:")
    for boundary in BOUNDARIES:
        print("  - " + boundary)
    return 1


if __name__ == "__main__":
    sys.exit(main())
