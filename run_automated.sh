#!/usr/bin/env bash
#
# Fully automated arXiv review using Claude Code
# Runs both passes automatically
#
# Requirements:
#   - claude CLI installed and authenticated
#   - jq installed
#
# Cron example (Mon-Fri at 8am):
#   0 8 * * 1-5 /path/to/run_automated.sh >> ~/.local/share/arxiv-review/cron.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
OUTPUT_DIR="${SCRIPT_DIR}/output"
CATEGORIES="${ARXIV_CATEGORIES:-quant-ph cond-mat.str-el}"
DATE=$(date +%Y-%m-%d)

# Paths
DATA_FILE="${DATA_DIR}/${DATE}.json"
FILTER_FILE="${DATA_DIR}/${DATE}_filter.json"
OUTPUT_FILE="${OUTPUT_DIR}/${DATE}_summary.md"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

mkdir -p "${DATA_DIR}" "${OUTPUT_DIR}"

# Step 1: Fetch if not cached
if [[ ! -f "${DATA_FILE}" ]]; then
    log "Fetching arXiv papers..."
    python3 "${SCRIPT_DIR}/fetch_arxiv.py" ${CATEGORIES} -o "${DATA_FILE}"
fi

PAPER_COUNT=$(jq '.count' "${DATA_FILE}")
log "Processing ${PAPER_COUNT} papers"

if [[ "${PAPER_COUNT}" -eq 0 ]]; then
    log "No papers found (weekend?), skipping."
    exit 0
fi

# Step 2: First pass - title filtering
if [[ ! -f "${FILTER_FILE}" ]]; then
    log "Running title filter (pass 1)..."
    
    TITLE_PROMPT=$(python3 "${SCRIPT_DIR}/prepare_prompt.py" title-filter --data "${DATA_FILE}")
    
    # Run through Claude, then strip markdown fences if present
    RESPONSE=$(claude --print "${TITLE_PROMPT}" 2>/dev/null)
    
    # Extract JSON: remove ```json and ``` fences, find the JSON object
    echo "${RESPONSE}" | \
        sed 's/^```json//; s/^```//' | \
        grep -v '^```' | \
        sed -n '/^{/,/^}/p' > "${FILTER_FILE}"
    
    # Validate JSON
    if ! jq empty "${FILTER_FILE}" 2>/dev/null; then
        log "ERROR: Invalid JSON from title filter. Raw response:"
        echo "${RESPONSE}"
        rm -f "${FILTER_FILE}"
        exit 1
    fi
fi

TIER1=$(jq -r '.tier1 | length' "${FILTER_FILE}")
TIER2=$(jq -r '.tier2 | length' "${FILTER_FILE}")
log "Title filter: ${TIER1} tier1, ${TIER2} tier2"

# Step 3: Second pass - abstract review
if [[ ! -f "${OUTPUT_FILE}" ]]; then
    log "Running abstract review (pass 2)..."
    
    ABSTRACT_PROMPT=$(python3 "${SCRIPT_DIR}/prepare_prompt.py" abstract-review \
        --data "${DATA_FILE}" --filter-ids "${FILTER_FILE}")
    
    claude --print "${ABSTRACT_PROMPT}" 2>/dev/null > "${OUTPUT_FILE}"
fi

ln -sf "$OUTPUT_FILE" ~/arxiv-today.md

log "Done: ${OUTPUT_FILE}"

# Optional: send notification
if command -v notify-send &>/dev/null; then
    notify-send "arXiv Review" "${TIER1} must-read, ${TIER2} to skim"
fi
