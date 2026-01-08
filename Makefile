# arXiv Review Pipeline
# Run `make help` for usage

DATE ?= $(shell date +%Y-%m-%d)
CATEGORIES ?= quant-ph cond-mat.str-el
DATA_FILE = data/$(DATE).json
FILTER_FILE = data/$(DATE)_filter.json
OUTPUT_FILE = output/$(DATE)_summary.md

.PHONY: help fetch filter review clean all

help:
	@echo "arXiv Review Pipeline"
	@echo ""
	@echo "Usage:"
	@echo "  make fetch              Fetch today's papers"
	@echo "  make fetch DATE=2025-01-07"
	@echo "  make filter             Show title filter prompt"
	@echo "  make review             Show abstract review prompt"
	@echo "  make all                Run full pipeline (needs claude CLI)"
	@echo "  make clean              Remove today's data"
	@echo ""
	@echo "Current: DATE=$(DATE) CATEGORIES=$(CATEGORIES)"

data output:
	mkdir -p $@

fetch: data
	python3 fetch_arxiv.py $(CATEGORIES) -o $(DATA_FILE)
	@echo "Fetched $$(jq '.count' $(DATA_FILE)) papers"

titles: $(DATA_FILE)
	@jq '.papers | .[:5] | .[] | "\(.id): \(.title)"' -r $(DATA_FILE)

filter-prompt: $(DATA_FILE)
	@python3 prepare_prompt.py title-filter --data $(DATA_FILE)

review-prompt: $(DATA_FILE) $(FILTER_FILE)
	@python3 prepare_prompt.py abstract-review --data $(DATA_FILE) --filter-ids $(FILTER_FILE)

# Interactive mode: shows prompt, you paste response
filter: $(DATA_FILE)
	@echo "=== Copy this prompt to Claude ===" 
	@python3 prepare_prompt.py title-filter --data $(DATA_FILE)
	@echo ""
	@echo "=== Paste JSON response below, Ctrl+D when done ==="
	@cat > $(FILTER_FILE)
	@echo "Saved to $(FILTER_FILE)"

review: $(DATA_FILE) $(FILTER_FILE) output
	@echo "=== Copy this prompt to Claude ==="
	@python3 prepare_prompt.py abstract-review --data $(DATA_FILE) --filter-ids $(FILTER_FILE)
	@echo ""
	@echo "=== Paste markdown response below, Ctrl+D when done ==="
	@cat > $(OUTPUT_FILE)
	@echo "Saved to $(OUTPUT_FILE)"

# Automated with claude CLI
all: data output
	./run_review.sh

clean:
	rm -f $(DATA_FILE) $(FILTER_FILE) $(OUTPUT_FILE)

# Token usage estimate
stats: $(DATA_FILE)
	@echo "Papers: $$(jq '.count' $(DATA_FILE))"
	@echo "Title-only size: $$(jq '[.papers[] | {id, title}]' $(DATA_FILE) | wc -c) bytes"
	@echo "Full data size: $$(wc -c < $(DATA_FILE)) bytes"
