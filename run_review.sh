#!/usr/bin/env bash
#
# Daily arXiv review pipeline
# Fetches papers, runs two-pass LLM filtering, generates summary
#
# Usage:
#   ./run_review.sh                    # Run for today
#   ./run_review.sh --dry-run          # Fetch only, no LLM
#   ./run_review.sh --date 2025-01-08  # Specific date
#
# Cron example (Mon-Fri at 8am):
#   0 8 * * 1-5 /path/to/run_review.sh >> /path/to/review.log 2>&1

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
OUTPUT_DIR="${SCRIPT_DIR}/output"
CATEGORIES="quant-ph cond-mat.str-el"

# Parse arguments
DRY_RUN=false
DATE=$(date +%Y-%m-%d)

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --date) DATE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Paths
DATA_FILE="${DATA_DIR}/${DATE}.json"
TITLES_FILE="${DATA_DIR}/${DATE}_titles.json"
FILTER_FILE="${DATA_DIR}/${DATE}_filter.json"
OUTPUT_FILE="${OUTPUT_DIR}/${DATE}_summary.md"

echo "=== arXiv Review: ${DATE} ==="
echo "Categories: ${CATEGORIES}"

# Step 1: Fetch papers
mkdir -p "${DATA_DIR}" "${OUTPUT_DIR}"

if [[ -f "${DATA_FILE}" ]]; then
    echo "Using cached data: ${DATA_FILE}"
else
    echo "Fetching arXiv RSS..."
    python3 "${SCRIPT_DIR}/fetch_arxiv.py" ${CATEGORIES} -o "${DATA_FILE}"
fi

PAPER_COUNT=$(jq '.count' "${DATA_FILE}")
echo "Papers fetched: ${PAPER_COUNT}"

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "Dry run - stopping before LLM processing"
    echo "Data saved to: ${DATA_FILE}"
    exit 0
fi

# Step 2: Generate titles-only JSON for first pass
echo "Preparing title filter..."
jq '{date: .date, papers: [.papers[] | {id, title, cat: .category}]}' \
    "${DATA_FILE}" > "${TITLES_FILE}"

# Step 3: First pass - title filtering
# This is where Claude Code or another LLM tool gets invoked
# The prompt is generated and fed to the LLM

TITLE_PROMPT=$(python3 "${SCRIPT_DIR}/prepare_prompt.py" title-filter --data "${DATA_FILE}")

echo "=== FIRST PASS: Title Filtering ==="
echo "Run this prompt through your LLM and save output to: ${FILTER_FILE}"
echo ""
echo "--- PROMPT START ---"
echo "${TITLE_PROMPT}"
echo "--- PROMPT END ---"
echo ""
echo "Expected output format:"
echo '{"tier1": ["2501.xxxxx"], "tier2": ["2501.yyyyy"], "skip": ["2501.zzzzz"]}'
echo ""

# For automated use with Claude Code, you could do:
# claude -p "${TITLE_PROMPT}" > "${FILTER_FILE}"

if [[ ! -f "${FILTER_FILE}" ]]; then
    echo "Waiting for filter file: ${FILTER_FILE}"
    echo "Create it manually or via LLM, then re-run this script."
    exit 0
fi

# Step 4: Second pass - abstract review
TIER1_COUNT=$(jq '.tier1 | length' "${FILTER_FILE}")
TIER2_COUNT=$(jq '.tier2 | length' "${FILTER_FILE}")
echo "First pass results: ${TIER1_COUNT} tier1, ${TIER2_COUNT} tier2"

ABSTRACT_PROMPT=$(python3 "${SCRIPT_DIR}/prepare_prompt.py" abstract-review \
    --data "${DATA_FILE}" --filter-ids "${FILTER_FILE}")

echo "=== SECOND PASS: Abstract Review ==="
echo "Run this prompt through your LLM and save output to: ${OUTPUT_FILE}"
echo ""
echo "--- PROMPT START ---"
echo "${ABSTRACT_PROMPT}"
echo "--- PROMPT END ---"

# For automated use:
# claude -p "${ABSTRACT_PROMPT}" > "${OUTPUT_FILE}"

echo ""
echo "=== Pipeline Complete ==="
echo "Output: ${OUTPUT_FILE}"
