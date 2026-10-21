"""Render a JSON configuration template with values from a secret projection.

The template is JSON text that may contain ``{{NAME}}`` placeholders. A
placeholder that is the whole string value is replaced by the literal text of
the variable; a placeholder written as ``{{NAME:json}}`` is replaced by the
JSON value of the variable, so a list or an object can be injected.

Values come from a dotenv-style projection file. The file may quote a value
with shell syntax, matching the reader used for the secret units themselves.
"""

import json
import re
import shlex
import sys
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


def render(template_path, env_path, output_path):
    values = parse_env_file(env_path)
    template = json.loads(Path(template_path).read_text())
    rendered = render_node(template, values)
    text = json.dumps(rendered, indent=2) + "\n"
    leftover = re.search(r"\{\{[A-Za-z0-9_:-]+\}\}", text)
    if leftover:
        raise KeyError("Unresolved placeholder " + leftover.group(0))
    target = Path(output_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".new")
    temporary.write_text(text)
    temporary.replace(target)


def main():
    if len(sys.argv) != 4:
        print("Usage: render-config.py <template.json> <env-file> <output.json>", file=sys.stderr)
        return 2
    try:
        render(sys.argv[1], sys.argv[2], sys.argv[3])
    except (KeyError, ValueError, OSError) as error:
        print("Could not render configuration: {0}".format(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
