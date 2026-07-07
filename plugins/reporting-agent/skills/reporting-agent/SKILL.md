---
name: reporting-agent
description: Use when the user asks about campaign performance, post-campaign analysis, retrospectives, campaign comparisons, or why a campaign underperformed. Covers email/SMS/push funnel metrics, audience segment diagnostics, and Treasure Data next-step recommendations.
---

# Reporting Agent

Three-phase post-campaign analysis workflow for TAIS Studio. Execute phases in order. Each phase has its own output format and trigger condition.

---

## Phase 1 — Performance Dashboard ("How did it perform?")

**Trigger:** Any question about campaign performance, retrospective, or comparison.

### Step 1: Query campaign funnel metrics

Run against `demo_lotto24`. Replace the WHERE clause with the campaigns requested by the user. To get all campaigns, omit the WHERE clause.

**Important — "last N campaigns":** Use `ORDER BY MIN(time) DESC LIMIT N` on `email_send` to find the most recent campaigns by name. If all campaigns share the same date range (as in demo environments), fall back to top N by send volume (`ORDER BY sends DESC`).

**Important — table join notes:**
- Use explicit `ON` joins, never `USING` — Trino does not allow qualified column references (e.g. `s.td_id`) after a `USING` join.
- `email_open`, `email_click`, `email_bounce`, `email_unsubscribe` use *different* campaign names than `email_send`. Always join through `email_send` as the campaign membership source of truth.

```sql
SELECT
  s.campaign_name,
  COUNT(DISTINCT s.td_id)                                                        AS sends,
  COUNT(DISTINCT o.td_id)                                                        AS opens,
  COUNT(DISTINCT c.td_id)                                                        AS clicks,
  COUNT(DISTINCT b.td_id)                                                        AS bounces,
  COUNT(DISTINCT u.td_id)                                                        AS unsubs,
  ROUND(COUNT(DISTINCT o.td_id) * 100.0 / COUNT(DISTINCT s.td_id), 1)           AS open_rate_pct,
  ROUND(COUNT(DISTINCT c.td_id) * 100.0 / COUNT(DISTINCT s.td_id), 1)           AS ctr_pct,
  ROUND(COUNT(DISTINCT b.td_id) * 100.0 / COUNT(DISTINCT s.td_id), 1)           AS bounce_rate_pct,
  ROUND(COUNT(DISTINCT u.td_id) * 100.0 / COUNT(DISTINCT s.td_id), 1)           AS unsub_rate_pct
FROM email_send s
LEFT JOIN email_open        o ON s.td_id = o.td_id AND s.campaign_id = o.campaign_id
LEFT JOIN email_click       c ON s.td_id = c.td_id AND s.campaign_id = c.campaign_id
LEFT JOIN email_bounce      b ON s.td_id = b.td_id AND s.campaign_id = b.campaign_id
LEFT JOIN email_unsubscribe u ON s.td_id = u.td_id AND s.campaign_id = u.campaign_id
WHERE s.campaign_name IN ('Campaign A', 'Campaign B')   -- replace or remove filter
GROUP BY s.campaign_name
ORDER BY sends DESC;
```

Run the same query without the WHERE filter to get the 8-campaign benchmark averages.

### Step 2: Compute the health score

For each campaign:
- Normalize each metric: `norm = (value − min_across_campaigns) / (max − min)`
- Health score (0–100): `(open_norm × 0.3 + ctr_norm × 0.4 + (1 − bounce_norm) × 0.2 + (1 − unsub_norm) × 0.1) × 100`
- Higher open/click = better; higher bounce/unsub = worse (hence `1 − norm`).

### Step 3: Render the grid dashboard

Load `studio-skills:grid-dashboard` and write a 4-column YAML dashboard file, then call `preview_grid_dashboard`.

Layout (4 columns):

```
Row 1: KPI — Open Rate | KPI — CTR | KPI — Bounce Rate | KPI — Unsub Rate
       Each: value = campaign %, change = delta vs benchmark %, trend = up (good) / down (bad)
       Note: for Bounce and Unsub, trend: down means better (rate is lower than benchmark)

Row 2: Gauge — health score (0–100, thresholds: red <40, yellow <70, green ≤100)
       Scores — open/ctr/bounce/unsub vs benchmark (value = campaign, max = benchmark×2)

Row 3: [full-width, merged "3-1" to "3-4"] Sortable table
       Headers: Campaign | Sends | Open% | CTR% | Bounce% | Unsub% | Health Score
       Rows: one per campaign, sorted by health score descending

Row 4: [full-width, merged "4-1" to "4-4"] Markdown
       Show benchmark averages: "Benchmark (8-campaign avg): Open X% | CTR X% | Bounce X% | Unsub X%"
       Show data date range from email_send.send_datetime.
```

**Fallback:** If `preview_grid_dashboard` is unavailable, output Phase 1 as a markdown table with the same columns.

---

## Phase 2 — Diagnostic Hints + Fixed Drills ("Why did it underperform?")

**Trigger:** Runs automatically after Phase 1 renders. Surface anomaly hints; run drills only on user confirmation.

### Step 1: Anomaly detection

After the dashboard renders, compare each campaign's metrics against benchmark. Flag using these thresholds:

| Metric | Flag condition | Direction |
|--------|---------------|-----------|
| bounce_rate_pct | > benchmark × 1.2 | High bounce |
| unsub_rate_pct  | > benchmark × 1.2 | High unsubscribe |
| open_rate_pct   | < benchmark × 0.8 | Low open rate |
| ctr_pct         | < benchmark × 0.8 | Low CTR |

For each flagged metric, emit one sentence:
> "[Campaign] had a [metric] of [value]% — [multiplier]× the average of [benchmark]%. Want me to dig into why?"

If no anomalies are found: skip to Phase 3 without asking.

### Step 2: Fixed drills (run all three on user confirmation)

#### Drill 1 — Deliverability (bounce by device + domain)

```sql
-- Bounce rate by device (os_version)
WITH campaign_sends AS (
  SELECT td_id, os_version
  FROM email_send
  WHERE campaign_name = '{campaign}'
),
total AS (SELECT COUNT(*) AS n FROM campaign_sends)
SELECT cs.os_version,
       COUNT(*)                              AS bounces,
       ROUND(COUNT(*) * 100.0 / t.n, 1)    AS pct
FROM email_bounce b
JOIN campaign_sends cs ON b.td_id = cs.td_id
CROSS JOIN total t
GROUP BY cs.os_version, t.n
ORDER BY pct DESC
LIMIT 10;

-- Bounce rate by email domain
SELECT SPLIT_PART(b.email, '@', 2)   AS domain,
       COUNT(*)                      AS bounces
FROM email_send s
JOIN email_bounce b ON s.td_id = b.td_id AND s.campaign_id = b.campaign_id
WHERE s.campaign_name = '{campaign}'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;
```

Output two inline tables. Flag any device or domain with bounce rate > 2× the campaign average.

#### Drill 2 — Channel Comparison (email vs SMS vs push)

```sql
-- Step A: get campaign time window
SELECT MIN(time) AS t_start, MAX(time) AS t_end
FROM email_send
WHERE campaign_name = '{campaign}';

-- Step B: SMS volume in same window (use t_start and t_end from Step A)
SELECT COUNT(*) AS sms_volume
FROM sms_send
WHERE time BETWEEN {t_start} AND {t_end};

-- Step C: App push volume in same window
SELECT COUNT(*) AS push_volume
FROM app_push
WHERE time BETWEEN {t_start} AND {t_end};
```

Output: 3-row comparison table — Channel | Volume | Note.
- Email row: show full funnel (sends / open% / CTR% / bounce% / unsub%)
- SMS row: volume only (no open/click tracking in demo data)
- Push row: volume only
If SMS or push returns 0 rows, note "No [channel] activity in this campaign window" and skip that row.

#### Drill 3 — Audience Segment Split (KYC Verified vs High Value vs General)

```sql
-- First: check the actual column names in master_profile
DESCRIBE demo_lotto24.master_profile;
```

Then adapt the CASE expression to match real column names before running:

```sql
SELECT
  CASE
    WHEN p.kyc_status = 'verified'       THEN 'KYC Verified'
    WHEN p.customer_tier = 'high_value'  THEN 'High Value'
    ELSE 'General'
  END                                                                          AS segment,
  COUNT(DISTINCT s.td_id)                                                      AS sends,
  ROUND(COUNT(DISTINCT o.td_id) * 100.0 / NULLIF(COUNT(DISTINCT s.td_id),0), 1) AS open_pct,
  ROUND(COUNT(DISTINCT c.td_id) * 100.0 / NULLIF(COUNT(DISTINCT s.td_id),0), 1) AS ctr_pct,
  ROUND(COUNT(DISTINCT u.td_id) * 100.0 / NULLIF(COUNT(DISTINCT s.td_id),0), 1) AS unsub_pct
FROM email_send s
LEFT JOIN email_open        o ON s.td_id = o.td_id AND s.campaign_id = o.campaign_id
LEFT JOIN email_click       c ON s.td_id = c.td_id AND s.campaign_id = c.campaign_id
LEFT JOIN email_unsubscribe u ON s.td_id = u.td_id AND s.campaign_id = u.campaign_id
LEFT JOIN master_profile    p ON s.td_id = p.td_id
WHERE s.campaign_name = '{campaign}'
GROUP BY 1;
```

Output: 3-row table. Flag any segment with unsub_pct > 1.5× the campaign-level unsub average.

---

## Phase 3 — Next-Step Recommendations ("What should we do next?")

**Trigger:** Always runs after Phase 1. Runs after Phase 2 if drills executed; uses Phase 1 data alone if Phase 2 was skipped (no anomalies).

### Step 1: Generate 2–3 recommendations

Pick the most relevant from this list based on what the data showed:

**Recommendation A — Re-target segment (always include if CTR < benchmark)**

Estimate the "opened but didn't click" cohort:

```sql
-- Bridge through email_send — email_open uses different campaign names than email_send
SELECT COUNT(DISTINCT s.td_id) AS opened_no_click
FROM email_send s
INNER JOIN email_open  o ON s.td_id = o.td_id AND s.campaign_id = o.campaign_id
LEFT  JOIN email_click c ON s.td_id = c.td_id AND s.campaign_id = c.campaign_id
WHERE s.campaign_name = '{campaign}'
  AND c.td_id IS NULL;
```

Then say:
> "[X] profiles opened [campaign] but didn't click. I can create a child segment targeting them for a follow-up send with a stronger CTA."

**Recommendation B — Channel shift (include if SMS/push volume > email sends × 1.2 in Drill 2)**

> "SMS reached [X] more users in the same window. For the next campaign targeting [High-Value / KYC Verified], routing to SMS could increase reach by ~[delta]."

**Recommendation C — Audience suppression or copy change (include if any segment had unsub_pct > 1.5× avg in Drill 3)**

> "[Segment] unsubscribed [X]× more than average on [campaign]. Recommend either suppressing this segment from the next send, or using a softer copy tone for them."

If Phase 2 was skipped, default to Recommendation A only (re-target the low-CTR cohort from Phase 1).

### Step 2: TD-specific CTA

After presenting each recommendation, ask:
> "Want me to build this in Treasure Data?"

Route confirmations to the right skill — **only invoke after explicit user confirmation**:

| Recommendation | Skill to invoke |
|---------------|----------------|
| Re-target segment (A) | `tdx-skills:segment` |
| Journey update for new segment | `tdx-skills:journey` |
| Suppression activation (C) | `tdx-skills:activation` |

Do not auto-build. Do not invoke downstream skills proactively.
