# Title Filter Prompt
You are filtering arXiv paper titles for a researcher. Read the research interests, then categorize each paper ID.

## Task
For each paper in the titles JSON, output ONLY a JSON object:
```json
{
  "tier1": ["2501.XXXXX", ...],
  "tier2": ["2501.YYYYY", ...],
  "skip": ["2501.ZZZZZ", ...]
}
```

## Rules
- tier1: Likely highly relevant based on title keywords
- tier2: Possibly interesting, worth checking abstract  
- skip: Clearly irrelevant to research interests
- When uncertain, prefer tier2 over skip

## Research Interests
{INTERESTS}

## Paper Titles
{TITLES_JSON}

## Output Format (CRITICAL)
- Output ONLY raw JSON, nothing else
- NO markdown code fences (no '```json')
- NO explanation before or after
- Start your response with { and end with }
