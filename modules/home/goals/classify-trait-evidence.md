# Trait Evidence Classification

You are classifying a check-in text against a set of known behavioral
traits. Your task is to decide, for each trait, whether the check-in
reinforces it, contradicts it, or is unrelated.

---

## Input

- **check_in_text**: the user's free-form check-in (1–3 paragraphs)
- **traits**: a list of `{id, name, description, status, confidence, category}` for every trait in `proposed` or `active` status

---

## Classification rules

| evidence_value | Meaning | When to use |
|---|---|---|
| `1.0` | Reinforces | The text describes behaviour, sentiment, or circumstances that are *directly consistent* with this trait. A single concrete example is enough. |
| `0.0` | Contradicts | The text describes behaviour, sentiment, or circumstances that are *directly inconsistent* with this trait. One concrete counter-example is enough. |
| `0.5` | Neutral / unrelated | The text says nothing about this trait, or the connection is too weak/ambiguous to call. **This is the default when unsure.** |

### Hard rules

1. **When in doubt, use `0.5` (neutral).** A single ambiguous check-in should
   not move any trait's confidence. Asymmetric caution here matters: a wrongly
   reinforced trait can bias your model of the user for weeks; a missed signal
   merely stalls a `proposed → active` promotion, which is easy to correct
   later with clearer evidence.

2. **Every classification requires a one-line rationale.** The rationale is
   stored in the `note` field of the `trait_evidence` row so the evidence
   trail remains human-readable — not just a bare float. Write it in the
   user's natural voice, e.g. `"Morning check-in — said they 'felt
   lethargic', which is inconsistent with 'morning exercise habit' trait."`

3. **Never invent a new trait from a single check-in.** `propose_trait` should
   only fire when the user explicitly says something like "note that I tend
   to..." or "I've noticed I always..." — not inferred from phrasing patterns.
   Silent trait creation is the automated-memory equivalent of fabrication: an
   unearned claim about the user that they never actually said.



---

## Output format

```json
{
  "trait_classifications": [
    {
      "trait_id": 1,
      "evidence_value": 1.0,
      "rationale": "Check-in says 'went for a run this morning' — directly reinforces 'morning exercise'"
    },
    {
      "trait_id": 2,
      "evidence_value": 0.5,
      "rationale": "Check-in is about work productivity; says nothing about sleep schedule"
    }
  ]
}
```

---

## Worked examples

### Example 1 — Reinforces + neutral

**Check-in** (domain: health):
> Had a great workout this morning — 5K run in under 25 minutes. Felt
> energised all day. Ate clean except for one cookie after lunch.

**Traits**:
| id | name | status | confidence |
|----|------|--------|------------|
| 1 | Morning exercise habit | active | 0.72 |
| 2 | Consistent sleep schedule | active | 0.68 |
| 3 | Reading habit | proposed | 0.55 |

**Reasoning**:
- **Trait 1 (morning exercise):** 1.0 — explicitly went for a 5K run this morning. Direct reinforcement of an active trait.
- **Trait 2 (sleep):** 0.5 — no mention of sleep at all.
- **Trait 3 (reading):** 0.5 — no mention of reading. Even though the user shows self-discipline (running, eating clean), extrapolating that to reading is exactly the kind of weak inference rule 3 warns against.

**Output:**
```json
{
  "trait_classifications": [
    {"trait_id": 1, "evidence_value": 1.0, "rationale": "Went for a 5K run this morning — directly reinforces established morning exercise habit"},
    {"trait_id": 2, "evidence_value": 0.5, "rationale": "No mention of sleep schedule in this check-in"},
    {"trait_id": 3, "evidence_value": 0.5, "rationale": "No mention of reading; self-discipline in exercise does not imply reading habit"}
  ]
}
```

### Example 2 — Contradicts + neutral

**Check-in** (domain: work):
> Terrible day. Procrastinated for hours on Reddit, then had to rush through
> my deliverables at the last minute. Feel awful about it.

**Traits**:
| id | name | status | confidence |
|----|------|--------|------------|
| 4 | Deep work habit | active | 0.81 |
| 5 | Evening coding projects | proposed | 0.58 |
| 6 | Journaling practice | active | 0.65 |

**Reasoning**:
- **Trait 4 (deep work):** 0.0 — explicitly procrastinated instead of focusing. Contradicts an established active trait with clear evidence.
- **Trait 5 (evening coding):** 0.5 — no mention of evening activities at all.
- **Trait 6 (journaling):** 0.5 — the check-in itself is not journaling; it's a frustrated report. The user didn't say they journaled or failed to journal. Rule 1 applies: ambiguous → 0.5.

**Output:**
```json
{
  "trait_classifications": [
    {"trait_id": 4, "evidence_value": 0.0, "rationale": "Explicitly procrastinated instead of focused work — contradicts deep work habit"},
    {"trait_id": 5, "evidence_value": 0.5, "rationale": "No mention of evening activities"},
    {"trait_id": 6, "evidence_value": 0.5, "rationale": "Check-in is a frustrated report, not a journaling session; connection is too weak"}
  ]
}
```

### Example 3 — Mixed with edge-case

**Check-in** (domain: personal-growth):
> Finally finished that book I've been reading for weeks. Really proud of
> myself for sticking with it — normally I abandon books halfway. Also,
> I noticed I tend to focus better in the morning, so maybe I should
> start scheduling deep work before noon.

**Traits**:
| id | name | status | confidence |
|----|------|--------|------------|
| 7 | Reading habit | proposed | 0.62 |
| 8 | Morning exercise | active | 0.70 |

**Reasoning**:
- **Trait 7 (reading):** 1.0 — explicitly finished a book, expressed pride in persistence. For a proposed trait nearing 0.65, this is one of the stronger signals possible.
- **Trait 8 (morning exercise):** 0.5 — mentions focusing better in the morning, but that's about work, not exercise. Rule 1 applies.
- **Silent trait creation?** The user said "I noticed I tend to focus better in the morning". This is NOT a request to create a new "morning focus" trait — it's a casual self-observation. Rule 3 says: do not create a trait from this. Only if the user said "I want to track that I'm a morning person" or "note that I focus better in the morning" would you create one.

**Output:**
```json
{
  "trait_classifications": [
    {"trait_id": 7, "evidence_value": 1.0, "rationale": "Finished a book after weeks of persistence — directly reinforces reading habit, strong signal for a proposed trait"},
    {"trait_id": 8, "evidence_value": 0.5, "rationale": "Mentions morning focus for work, not exercise; connection to morning exercise is too weak"}
  ]
}
```

### Example 4 — All neutral (trap check)

**Check-in** (domain: work):
> Just another Tuesday. Responded to emails, fixed a bug in the deploy
> script, had a sandwich for lunch.

**Traits**:
| id | name | status | confidence |
|----|------|--------|------------|
| 9 | Deep work habit | active | 0.75 |
| 10 | Healthy eating | proposed | 0.50 |

**Reasoning**:
- **Trait 9 (deep work):** 0.5 — "fixed a bug in the deploy script" sounds like focused work, but the tone says "routine Tuesday" not "deep work session". Rule 1: ambiguous → 0.5. This is the trap where an enthusiastic classifier would give it 1.0, but the check-in is too generic to move the needle.
- **Trait 10 (healthy eating):** 0.5 — "had a sandwich for lunch" is neutral. It could be healthy or not. No signal.

**Output:**
```json
{
  "trait_classifications": [
    {"trait_id": 9, "evidence_value": 0.5, "rationale": "Fixed a bug but described it as routine — insufficient signal to reinforce deep work habit"},
    {"trait_id": 10, "evidence_value": 0.5, "rationale": "Had a sandwich — completely neutral with respect to healthy eating"}
  ]
}
```
