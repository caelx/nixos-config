"""Render a JSON configuration template with values from a secret projection.

The template is JSON text that may contain ``{{NAME}}`` placeholders. A
placeholder that is the whole string value is replaced by the literal text of
the variable; a placeholder written as ``{{NAME:json}}`` is replaced by the
JSON value of the variable, so a list or an object can be injected.

Values come from a dotenv-style projection file. The file may quote a value
with shell syntax, matching the reader used for the secret units themselves.

The rendered file is published safely. The publication directory must not be
writable by anyone other than its owner, and it must not be a symbolic link.
The temporary file is created with exclusive creation under a random name, so
a pre-created path cannot capture the write, and its final permissions and
ownership are applied before it is renamed into place, so the published file
is never briefly readable with the wrong mode or owner.
"""

import errno
import json
import os
import re
import shlex
import stat
import sys
import tempfile
from pathlib import Path


def parse_env_file(path):
    values = {}
    for raw_line in Path(path).read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value.startswith(("'", '"')):
            try:
                parts = shlex.split(value, comments=False)
            except ValueError:
                raise ValueError(f"Invalid quoting for secret {key}") from None
            if len(parts) != 1:
                raise ValueError(f"Invalid quoting for secret {key}")
            value = parts[0]
        values[key] = value
    return values


def substitute(text, values):
    """Replace embedded {{NAME}} placeholders in one string value."""
    for key, value in values.items():
        text = text.replace("{{%s}}" % key, value)
    return text


def render_node(node, values):
    if isinstance(node, dict):
        return {key: render_node(item, values) for key, item in node.items()}
    if isinstance(node, list):
        return [render_node(item, values) for item in node]
    if not isinstance(node, str):
        return node
    if node.startswith("{{") and node.endswith(":json}}"):
        name = node[2:-len(":json}}")]
        if name not in values:
            raise KeyError("Missing secret value for placeholder " + name)
        return json.loads(values[name])
    if node.startswith("{{") and node.endswith("}}"):
        name = node[2:-2]
        if name not in values:
            raise KeyError("Missing secret value for placeholder " + name)
        return values[name]
    return substitute(node, values)


def require_safe_directory(directory):
    """The publication directory must not be shared with another account."""
    try:
        info = os.lstat(directory)
    except OSError as error:
        raise ValueError(
            "publication directory is not usable: {0}".format(error.strerror)
        ) from None
    if stat.S_ISLNK(info.st_mode):
        raise ValueError("publication directory is a symbolic link")
    if not stat.S_ISDIR(info.st_mode):
        raise ValueError("publication directory is not a directory")
    if info.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise ValueError("publication directory is writable by another account")
    return info


def publish(target, text, mode, owner):
    """Write the text into the target, safely.

    The temporary file is created exclusively under a random name, the final
    mode and ownership are applied to it while it is still private, and only
    then is it renamed into place.
    """
    target = Path(target)
    require_safe_directory(target.parent)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=str(target.parent), prefix="." + target.name + "."
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        if owner:
            user, _, group = owner.partition(":")
            os.chown(
                temporary,
                -1 if not user else int(user),
                -1 if not group else int(group),
            )
        os.replace(temporary, target)
    except BaseException:
        try:
            temporary.unlink()
        except OSError as error:
            if error.errno != errno.ENOENT:
                raise
        raise


def render(template_path, env_path, output_path, mode, owner):
    values = parse_env_file(env_path)
    template = json.loads(Path(template_path).read_text())
    rendered = render_node(template, values)
    text = json.dumps(rendered, indent=2) + "\n"
    leftover = re.search(r"\{\{[A-Za-z0-9_:-]+\}\}", text)
    if leftover:
        raise KeyError("Unresolved placeholder " + leftover.group(0))
    publish(output_path, text, mode, owner)


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: render-config.py <template.json> <env-file> <output.json>"
            " [--owner uid:gid] [--mode mode]",
            file=sys.stderr,
        )
        return 2
    mode = 0o600
    owner = ""
    arguments = sys.argv[1:]
    while "--owner" in arguments or "--mode" in arguments:
        if "--owner" in arguments:
            index = arguments.index("--owner")
            owner = arguments[index + 1]
            del arguments[index:index + 2]
        else:
            index = arguments.index("--mode")
            mode = int(arguments[index + 1], 8)
            del arguments[index:index + 2]
    try:
        render(arguments[0], arguments[1], arguments[2], mode, owner)
    except (KeyError, ValueError, OSError) as error:
        print("Could not render configuration: {0}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
