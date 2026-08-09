#!/usr/bin/env python3
"""Build a deterministic graph from Markdown vault documents.

Markdown files remain authoritative. The JSON and DOT outputs are derived
artifacts intended for graph views, backlinks, and other disposable tooling.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)
MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)#]+)(?:#[^)]+)?\)")
WIKILINK_RE = re.compile(r"\[\[([^|\]]+)(?:\|[^\]]+)?\]\]")
YAML_SCALAR_RE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*?)\s*$")


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if value in {"true", "false"}:
        return value == "true"
    if value.startswith("[") and value.endswith("]"):
        return [
            item.strip().strip("'\"")
            for item in value[1:-1].split(",")
            if item.strip()
        ]
    return value.strip("'\"")


def parse_frontmatter(text: str) -> dict[str, Any]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}

    metadata: dict[str, Any] = {}
    for line in match.group(1).splitlines():
        scalar = YAML_SCALAR_RE.match(line)
        if scalar:
            metadata[scalar.group(1)] = parse_scalar(scalar.group(2))
    return metadata


def normalise_target(source: Path, target: str, root: Path) -> str | None:
    target_path = (source.parent / target).resolve()
    try:
        relative = target_path.relative_to(root.resolve())
    except ValueError:
        return None

    if relative.suffix != ".md":
        relative = relative.with_suffix(".md")
    candidate = root / relative
    if not candidate.is_file():
        return None
    return relative.as_posix()


def build_graph(root: Path) -> dict[str, Any]:
    documents = sorted(root.rglob("*.md"))
    nodes: list[dict[str, Any]] = []
    edges: set[tuple[str, str, str]] = set()

    for path in documents:
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        metadata = parse_frontmatter(text)
        nodes.append(
            {
                "id": relative,
                "path": relative,
                "kind": metadata.get("kind", "document"),
                "name": metadata.get("name", path.stem),
                "tags": metadata.get("tags", []),
            }
        )

        targets = [
            ("markdown", target)
            for target in MARKDOWN_LINK_RE.findall(text)
        ] + [
            ("wikilink", target)
            for target in WIKILINK_RE.findall(text)
        ]
        for relation, target in targets:
            target_path = normalise_target(path, target.strip(), root)
            if target_path:
                edges.add((relative, target_path, relation))

    return {
        "schema_version": 1,
        "root": str(root),
        "nodes": nodes,
        "edges": [
            {"source": source, "target": target, "type": relation}
            for source, target, relation in sorted(edges)
        ],
    }


def dot_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def to_dot(graph: dict[str, Any]) -> str:
    lines = ["digraph markdown_vault {", "  rankdir=LR;"]
    for node in graph["nodes"]:
        node_id = dot_escape(node["id"])
        label = dot_escape(node["name"])
        lines.append(f'  "{node_id}" [label="{label}"];')
    for edge in graph["edges"]:
        source = dot_escape(edge["source"])
        target = dot_escape(edge["target"])
        relation = dot_escape(edge["type"])
        lines.append(f'  "{source}" -> "{target}" [label="{relation}"];')
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(".agents"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dot-output", type=Path)
    args = parser.parse_args()

    root = args.root.resolve()
    if not root.is_dir():
        parser.error(f"root is not a directory: {root}")

    graph = build_graph(root)
    payload = json.dumps(graph, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")

    if args.dot_output:
        args.dot_output.parent.mkdir(parents=True, exist_ok=True)
        args.dot_output.write_text(to_dot(graph), encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())