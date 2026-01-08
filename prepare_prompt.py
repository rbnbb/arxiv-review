#!/usr/bin/env python3
"""
Prepare prompts for LLM processing.
Handles template substitution and data filtering.

Usage:
    python prepare_prompt.py title-filter --data data/2025-01-08.json
    python prepare_prompt.py abstract-review --data data/2025-01-08.json --filter-ids tier1.json
"""

import argparse
import json
import sys
from pathlib import Path


def load_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def load_text(path: str) -> str:
    with open(path) as f:
        return f.read()


def prepare_title_filter(data_path: str, base_dir: Path) -> str:
    """Prepare first-pass prompt with titles only."""
    data = load_json(data_path)
    interests = load_text(base_dir / "research_interests.md")
    template = load_text(base_dir / "prompts" / "title_filter.md")

    # Extract only id, title, category for minimal tokens
    titles = [
        {"id": p["id"], "title": p["title"], "cat": p["category"]}
        for p in data["papers"]
    ]

    titles_json = json.dumps(titles, indent=None)  # Compact JSON

    prompt = template.replace("{INTERESTS}", interests)
    prompt = prompt.replace("{TITLES_JSON}", titles_json)
    prompt = prompt.replace("{DATE}", data["date"])

    return prompt


def prepare_abstract_review(
    data_path: str, filter_ids_path: str | None, base_dir: Path
) -> str:
    """Prepare second-pass prompt with filtered abstracts."""
    data = load_json(data_path)
    interests = load_text(base_dir / "research_interests.md")
    template = load_text(base_dir / "prompts" / "abstract_review.md")

    papers = data["papers"]

    # Filter to specific IDs if provided
    if filter_ids_path:
        filter_data = load_json(filter_ids_path)
        # Accept either {"tier1": [...], "tier2": [...]} or just [...]
        if isinstance(filter_data, dict):
            keep_ids = set(filter_data.get("tier1", []) + filter_data.get("tier2", []))
        else:
            keep_ids = set(filter_data)
        papers = [p for p in papers if p["id"] in keep_ids]

    # Include full info for abstract review
    papers_json = json.dumps(papers, indent=2)

    prompt = template.replace("{INTERESTS}", interests)
    prompt = prompt.replace("{PAPERS_JSON}", papers_json)
    prompt = prompt.replace("{DATE}", data["date"])

    return prompt


def main():
    parser = argparse.ArgumentParser(description="Prepare prompts for LLM")
    parser.add_argument(
        "mode", choices=["title-filter", "abstract-review"], help="Which prompt to prepare"
    )
    parser.add_argument("--data", required=True, help="Path to papers JSON")
    parser.add_argument(
        "--filter-ids", help="JSON file with paper IDs to include (for abstract-review)"
    )
    parser.add_argument(
        "--base-dir",
        default=Path(__file__).parent,
        type=Path,
        help="Base directory containing prompts/",
    )

    args = parser.parse_args()

    if args.mode == "title-filter":
        prompt = prepare_title_filter(args.data, args.base_dir)
    else:
        prompt = prepare_abstract_review(args.data, args.filter_ids, args.base_dir)

    print(prompt)


if __name__ == "__main__":
    main()
