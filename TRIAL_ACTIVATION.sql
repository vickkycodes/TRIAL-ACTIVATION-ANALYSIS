-- =============================================================================
-- SPLENDOR DATA CHALLENGE — TRIAL ACTIVATION MODEL
-- =============================================================================
-- Based on full analysis of 966 organizations across a 30-day trial period.
-- Overall conversion rate: 21.3%
--
-- Key findings driving this model:
--   - No single feature flag produced statistically significant lift (all p > 0.05)
--   - Score-based activation shows monotonic conversion lift:
--       Score 0 → 20.6% | Score 1 → 21.2% | Score 2 → 22.5% | Score 3 → 23.2%
--   - Logistic regression AUC = 0.51 (product data alone has near-random predictive power)
--   - Conversion is likely driven primarily by external/contextual factors
--
-- RECOMMENDATION: Use the composite score model (Query 3) as the primary trial goal.
-- It is the most defensible, monotonically increasing, and interpretable of the three.
-- =============================================================================


-- =============================================================================
-- QUERY 1: BINARY ACTIVATION (Baseline — original approach, for reference)
-- Activated = used template OR created ≥ 1 shift
-- Produces ~2–4% lift, no statistical significance
-- =============================================================================

WITH activity_counts AS (
    SELECT
        organization_id,
        SUM(CASE WHEN activity_name = 'Scheduling.Template.ApplyModal.Applied' THEN 1 ELSE 0 END) AS template_used,
        SUM(CASE WHEN activity_name = 'Scheduling.Shift.Created'               THEN 1 ELSE 0 END) AS shifts_created,
        MAX(CAST(converted AS INT))                                                                AS converted
    FROM events
    GROUP BY organization_id
),
activation AS (
    SELECT
        organization_id,
        converted,
        CASE
            WHEN template_used >= 1 OR shifts_created >= 1 THEN 1
            ELSE 0
        END AS activated
    FROM activity_counts
)
SELECT
    activated,
    COUNT(*)                        AS org_count,
    AVG(CAST(converted AS FLOAT))   AS conversion_rate
FROM activation
GROUP BY activated
ORDER BY activated;

-- Expected result:
--   activated = 0 → ~17.8% conversion
--   activated = 1 → ~21.8% conversion
--   Lift: ~+4.0% (not statistically significant, p = 0.38)


-- =============================================================================
-- QUERY 2: DEPTH-GATED BINARY ACTIVATION (Improved binary)
-- Requires BOTH template use AND meaningful shift volume (≥ 3 shifts)
-- Filters out orgs that only superficially touched the product
-- =============================================================================

WITH activity_counts AS (
    SELECT
        organization_id,
        SUM(CASE WHEN activity_name = 'Scheduling.Template.ApplyModal.Applied' THEN 1 ELSE 0 END) AS template_used,
        SUM(CASE WHEN activity_name = 'Scheduling.Shift.Created'               THEN 1 ELSE 0 END) AS shifts_created,
        SUM(CASE WHEN activity_name = 'PunchClock.PunchedIn'                   THEN 1 ELSE 0 END) AS punches,
        COUNT(DISTINCT activity_name)                                                              AS feature_diversity,
        MAX(CAST(converted AS INT))                                                                AS converted
    FROM events
    GROUP BY organization_id
),
activation AS (
    SELECT
        organization_id,
        converted,
        feature_diversity,
        CASE
            WHEN template_used >= 1
             AND shifts_created >= 3   -- Depth threshold: not just any touch, meaningful scheduling usage
            THEN 1
            ELSE 0
        END AS activated
    FROM activity_counts
)
SELECT
    activated,
    COUNT(*)                        AS org_count,
    AVG(CAST(converted AS FLOAT))   AS conversion_rate,
    AVG(feature_diversity)          AS avg_feature_diversity
FROM activation
GROUP BY activated
ORDER BY activated;


-- =============================================================================
-- QUERY 3: COMPOSITE SCORE-BASED ACTIVATION (RECOMMENDED)
-- Score 0–3 based on meeting meaningful thresholds across three signal types.
-- Monotonically increasing conversion: 20.6% → 21.2% → 22.5% → 23.2%
--
-- Scoring logic (1 point each):
--   +1  Applied a scheduling template (any use — rare behaviour, high intent signal)
--   +1  Created ≥ 3 shifts (depth of scheduling usage, not just first touch)
--   +1  Punched in at least once (cross-module engagement: scheduling + time tracking)
--
-- Orgs scoring 2–3 are considered "activated" for reporting purposes.
-- =============================================================================

WITH activity_counts AS (
    SELECT
        organization_id,
        SUM(CASE WHEN activity_name = 'Scheduling.Template.ApplyModal.Applied' THEN 1 ELSE 0 END) AS template_used,
        SUM(CASE WHEN activity_name = 'Scheduling.Shift.Created'               THEN 1 ELSE 0 END) AS shifts_created,
        SUM(CASE WHEN activity_name = 'PunchClock.PunchedIn'                   THEN 1 ELSE 0 END) AS punches,
        COUNT(DISTINCT activity_name)                                                              AS feature_diversity,
        MAX(CAST(converted AS INT))                                                                AS converted
    FROM events
    GROUP BY organization_id
),
scored AS (
    SELECT
        organization_id,
        converted,
        feature_diversity,
        -- Individual signal flags
        CASE WHEN template_used >= 1  THEN 1 ELSE 0 END AS signal_template,
        CASE WHEN shifts_created >= 3 THEN 1 ELSE 0 END AS signal_shift_depth,
        CASE WHEN punches >= 1        THEN 1 ELSE 0 END AS signal_punch_clock,
        -- Composite score
        (
            CASE WHEN template_used >= 1  THEN 1 ELSE 0 END +
            CASE WHEN shifts_created >= 3 THEN 1 ELSE 0 END +
            CASE WHEN punches >= 1        THEN 1 ELSE 0 END
        ) AS activation_score
    FROM activity_counts
)
SELECT
    activation_score,
    COUNT(*)                                        AS org_count,
    ROUND(AVG(CAST(converted AS FLOAT)) * 100, 2)  AS conversion_rate_pct,
    AVG(feature_diversity)                          AS avg_feature_diversity,
    SUM(signal_template)                            AS used_template,
    SUM(signal_shift_depth)                         AS created_3plus_shifts,
    SUM(signal_punch_clock)                         AS used_punch_clock
FROM scored
GROUP BY activation_score
ORDER BY activation_score;

-- Expected result (from analysis):
--   Score 0 → 20.60%  (369 orgs) — no meaningful engagement
--   Score 1 → 21.20%  (368 orgs) — surface-level engagement
--   Score 2 → 22.54%  (173 orgs) — moderately activated
--   Score 3 → 23.21%   (56 orgs) — fully activated across all three signals


-- =============================================================================
-- QUERY 4: COMPOSITE SCORE — BINARY ACTIVATED FLAG (for dashboards/reporting)
-- Collapses score into: activated (score ≥ 2) vs not activated (score ≤ 1)
-- =============================================================================

WITH activity_counts AS (
    SELECT
        organization_id,
        SUM(CASE WHEN activity_name = 'Scheduling.Template.ApplyModal.Applied' THEN 1 ELSE 0 END) AS template_used,
        SUM(CASE WHEN activity_name = 'Scheduling.Shift.Created'               THEN 1 ELSE 0 END) AS shifts_created,
        SUM(CASE WHEN activity_name = 'PunchClock.PunchedIn'                   THEN 1 ELSE 0 END) AS punches,
        MAX(CAST(converted AS INT))                                                                AS converted
    FROM events
    GROUP BY organization_id
),
scored AS (
    SELECT
        organization_id,
        converted,
        (
            CASE WHEN template_used >= 1  THEN 1 ELSE 0 END +
            CASE WHEN shifts_created >= 3 THEN 1 ELSE 0 END +
            CASE WHEN punches >= 1        THEN 1 ELSE 0 END
        ) AS activation_score
    FROM activity_counts
),
final AS (
    SELECT
        organization_id,
        converted,
        activation_score,
        CASE WHEN activation_score >= 2 THEN 1 ELSE 0 END AS activated
    FROM scored
)
SELECT
    activated,
    COUNT(*)                                        AS org_count,
    ROUND(AVG(CAST(converted AS FLOAT)) * 100, 2)  AS conversion_rate_pct
FROM final
GROUP BY activated
ORDER BY activated;
