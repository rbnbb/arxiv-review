#!/usr/bin/env python3
"""
Fetch arXiv papers for specified categories.
Uses RSS for daily new submissions, outputs structured JSON.

Usage:
    python fetch_arxiv.py quant-ph cond-mat.str-el > data/2025-01-08.json
    python fetch_arxiv.py --categories quant-ph cond-mat.str-el --output data/today.json
"""

import argparse
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from html import unescape
from pathlib import Path
from typing import Optional


def fetch_rss(category: str) -> str:
    """Fetch RSS feed for a category."""
    # arXiv RSS provides new submissions from the previous day
    url = f"https://rss.arxiv.org/rss/{category}"
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8")


def clean_text(text: str) -> str:
    """Clean HTML entities and normalize whitespace."""
    if not text:
        return ""
    text = unescape(text)
    text = re.sub(r"<[^>]+>", "", text)  # Remove HTML tags
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_arxiv_id(link: str) -> str:
    """Extract arXiv ID from URL."""
    # Handle both /abs/ and /pdf/ URLs
    match = re.search(r"arxiv.org/(?:abs|pdf)/([0-9]+\.[0-9]+)", link)
    return match.group(1) if match else ""


def parse_rss(xml_content: str, category: str) -> list[dict]:
    """Parse RSS XML into list of paper dicts."""
    papers = []
    root = ET.fromstring(xml_content)

    # Handle namespaces - arXiv RSS uses default namespace
    ns = {"dc": "http://purl.org/dc/elements/1.1/"}

    for item in root.findall(".//item"):
        title_elem = item.find("title")
        link_elem = item.find("link")
        desc_elem = item.find("description")
        creator_elem = item.find("dc:creator", ns)

        if title_elem is None or link_elem is None:
            continue

        arxiv_id = extract_arxiv_id(link_elem.text or "")
        if not arxiv_id:
            continue

        # Title often has format "Title. (arXiv:XXXX.XXXXX ...)"
        title = clean_text(title_elem.text or "")
        title = re.sub(r"\s*\(arXiv:[^)]+\)\s*$", "", title)

        # Description contains abstract + author list
        description = clean_text(desc_elem.text or "") if desc_elem is not None else ""

        # Extract authors from dc:creator or description
        authors = ""
        if creator_elem is not None and creator_elem.text:
            authors = clean_text(creator_elem.text)

        papers.append(
            {
                "id": arxiv_id,
                "title": title,
                "abstract": description,
                "authors": authors,
                "category": category,
                "url": f"https://arxiv.org/abs/{arxiv_id}",
                "pdf": f"https://arxiv.org/pdf/{arxiv_id}.pdf",
            }
        )

    return papers


def fetch_category(category: str) -> list[dict]:
    """Fetch all new papers for a category."""
    try:
        xml_content = fetch_rss(category)
        return parse_rss(xml_content, category)
    except Exception as e:
        print(f"Warning: Failed to fetch {category}: {e}", file=sys.stderr)
        return []


def main():
    parser = argparse.ArgumentParser(
        description="Fetch arXiv papers from RSS feeds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s quant-ph
    %(prog)s quant-ph cond-mat.str-el --output today.json
    %(prog)s quant-ph --titles-only

Common categories:
    quant-ph          Quantum Physics
    cond-mat.str-el   Strongly Correlated Electrons
    cond-mat.mes-hall Mesoscale and Nanoscale Physics
    cond-mat.stat-mech Statistical Mechanics
    physics.comp-ph   Computational Physics
        """,
    )
    parser.add_argument("categories", nargs="+", help="arXiv categories to fetch")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    parser.add_argument(
        "--titles-only",
        action="store_true",
        help="Output only id, title, url (for first pass)",
    )

    args = parser.parse_args()

    all_papers = []
    seen_ids = set()

    for category in args.categories:
        papers = fetch_category(category)
        for paper in papers:
            if paper["id"] not in seen_ids:
                seen_ids.add(paper["id"])
                all_papers.append(paper)

    # Sort by ID (newer papers have higher IDs)
    all_papers.sort(key=lambda p: p["id"], reverse=True)

    if args.titles_only:
        all_papers = [
            {"id": p["id"], "title": p["title"], "url": p["url"]} for p in all_papers
        ]

    output = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "categories": args.categories,
        "count": len(all_papers),
        "papers": all_papers,
    }

    json_str = json.dumps(output, indent=2, ensure_ascii=False)

    if args.output:
        # Ensure parent directory exists
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            f.write(json_str)
        print(f"Wrote {len(all_papers)} papers to {args.output}", file=sys.stderr)
    else:
        print(json_str)


if __name__ == "__main__":
    main()
