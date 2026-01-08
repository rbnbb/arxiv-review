# arXiv Daily Review Pipeline

Automated two-pass filtering of arXiv preprints using LLM.

## Quick Start

```bash
# 1. Fetch today's papers
make fetch

# 2. First pass: title filtering (copy prompt to Claude, paste JSON response)
make filter

# 3. Second pass: abstract review (copy prompt to Claude, paste markdown)
make review

# View result
cat output/$(date +%Y-%m-%d)_summary.md
```

## How It Works

### Two-Pass Design (Token Efficient)

**Pass 1 - Title Filter** (~500 tokens for 100 papers)
- Input: Paper IDs + titles only
- Output: JSON with tier1/tier2/skip lists
- Purpose: Quickly eliminate 70-80% of irrelevant papers

**Pass 2 - Abstract Review** (~2000 tokens for 20-30 papers)
- Input: Full abstracts of tier1 + tier2 papers only
- Output: Formatted markdown summary
- Purpose: Detailed relevance assessment with explanations

### Token Savings Example

| Approach | Papers | Tokens |
|----------|--------|--------|
| All abstracts at once | 100 | ~15,000 |
| Two-pass (this) | 100 → 25 | ~3,000 |

## Files

```
├── fetch_arxiv.py        # Fetches arXiv RSS → JSON
├── prepare_prompt.py     # Prepares prompts with data
├── research_interests.md # YOUR PREFERENCES (edit this!)
├── prompts/
│   ├── title_filter.md   # First pass prompt template
│   └── abstract_review.md # Second pass prompt template
├── run_review.sh         # Manual pipeline script
├── run_automated.sh      # Automated with claude CLI
├── Makefile              # Easy commands
├── data/                 # Fetched paper data (gitignored)
└── output/               # Generated summaries
```

## Configuration

### 1. Edit Research Interests

The most important file is `research_interests.md`. Customize it with:
- Your core research areas
- Methods you use
- What you find interesting vs. skip-worthy
- Tier definitions for your workflow

### 2. Choose Categories

Edit `CATEGORIES` in scripts or use environment variable:

```bash
# In run_automated.sh or via env
export ARXIV_CATEGORIES="quant-ph cond-mat.str-el cond-mat.mes-hall"
```

Common categories:
- `quant-ph` - Quantum Physics
- `cond-mat.str-el` - Strongly Correlated Electrons  
- `cond-mat.mes-hall` - Mesoscale and Nanoscale Physics
- `cond-mat.stat-mech` - Statistical Mechanics
- `physics.comp-ph` - Computational Physics

Full list: https://arxiv.org/category_taxonomy

### 3. Set Up Cron

```crontab
# Edit with: crontab -e
# Run Mon-Fri at 8:00 AM
0 8 * * 1-5 /path/to/arxiv-review/run_automated.sh >> /path/to/arxiv-review/cron.log 2>&1
```

## Manual Usage

### Fetch Papers

```bash
# Today
python3 fetch_arxiv.py quant-ph cond-mat.str-el -o data/today.json

# Preview titles
jq '.papers[:10] | .[].title' data/today.json
```

### Generate Prompts

```bash
# Title filter prompt
python3 prepare_prompt.py title-filter --data data/today.json

# After creating filter.json with LLM response:
python3 prepare_prompt.py abstract-review --data data/today.json --filter-ids filter.json
```

## Integration with Claude Code

The prompts are designed for minimal, reliable output:

```bash
# First pass - expects pure JSON
claude --print "$(python3 prepare_prompt.py title-filter --data data/today.json)" \
  | grep -E '^\{' | head -1 > filter.json

# Second pass - expects markdown
claude --print "$(python3 prepare_prompt.py abstract-review --data data/today.json --filter-ids filter.json)" \
  > output/summary.md
```

## Output Format

The generated `YYYY-MM-DD_summary.md` looks like:

```markdown
# arXiv Review: 2025-01-08

## Tier 1: Must Read (3)

### [Towards an understading of cat sociality](https://arxiv.org/abs/4242.12345)
**Why:** It's cool !
**Key:** New understading of cat behaviour

### [Title 2](url)
...

## Tier 2: Worth Skimming (5)

### [Paper title](url)
**Why:** Reasons !

## Tier 3: Background/Reference (4)

- [Paper](url) — something that might just be useful
```

## Tips

1. **Tune your interests file** - The quality of filtering depends on how well you describe your preferences

2. **Adjust tier definitions** - If too many/few papers in tier1, refine the guidance

3. **Cache data** - The fetch script won't re-download if today's file exists

4. **Check weekends** - arXiv doesn't post new papers Sat/Sun, RSS may be empty

5. **Combine with Zotero** - Add tier1 papers directly to your library

## Troubleshooting

**Empty RSS feed?**
- Weekend or holiday
- Category name typo (use hyphens: `cond-mat.str-el` not `cond-mat.strel`)

**LLM not outputting JSON?**
- The prompt explicitly asks for JSON only
- Some models need temperature=0 for reliable structured output

**Missing abstracts?**
- arXiv RSS sometimes truncates; the script handles this gracefully
