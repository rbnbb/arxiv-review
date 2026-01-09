# Abstract Review Prompt

You are reviewing arXiv abstracts for a researcher. Create a prioritized reading list.

## Task
Review each paper's abstract against the research interests. Output a markdown summary.

## Output Format
```markdown
# arXiv Review: {DATE}

## Tier 1: Must Read ({count})
Papers directly relevant to current research.

### [Paper Title 1](url1)
**Why:** 1-2 sentence explanation of relevance

### [Paper Title 2](url2)
**Why:** 1-2 sentence explanation of relevance

## Tier 2: Worth Skimming ({count})
- [Paper Title](url) - one-line note
- [Paper Title](url) - one-line note

## Tier 3: Background/Reference ({count})
Potentially useful for context or future reference.

- [Paper Title](url) — one-line note
- [Paper Title](url) — one-line note
```

## Guidelines
- Be concise: researchers skim these
- "Why" should connect to specific research interests
- Tier 1: Would read today
- Tier 2: Would skim or save for later
- Tier 3: Just tracking for awareness
- If a paper doesn't fit any tier, omit it

## Research Interests
{INTERESTS}

## Papers to Review
{PAPERS_JSON}
