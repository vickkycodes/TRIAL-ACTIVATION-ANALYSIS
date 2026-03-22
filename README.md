# TRIAL-ACTIVATION-ANALYSIS
# Splendor Data Challenge — Trial Activation Analysis

## Overview

This project analyses event-level product usage data from 966 organizations across their 30-day trial periods. The objective is to define a data-driven **activation metric** that predicts trial-to-paid conversion.

---

## Dataset

| Field | Description |
|---|---|
| `organization_id` | Unique org identifier (966 orgs) |
| `activity_name` | Product event name (28 distinct activities) |
| `timestamp` | Event timestamp |
| `converted` | Whether the org converted to paid |
| `converted_at` | Conversion timestamp (populated for converters only) |
| `trial_start` / `trial_end` | 30-day trial window (consistent across all orgs) |

**After deduplication:** 102,895 event rows (from 170,526 raw)  
**Overall conversion rate:** 21.3%

---

## Analysis Structure

The notebook runs the following sections in order:

1. **Data Cleaning & Preparation** — type casting, deduplication, derived fields, shared org-level matrices
2. **Exploratory Analysis** — overall conversion rate, activity distribution
3. **Feature-Level Analysis** — binary lift comparison for top 10 activities
4. **Statistical Significance Testing** — chi-square tests and 95% confidence intervals on all lift figures
5. **Feature Frequency & Depth Analysis** — point-biserial correlation between raw usage count and conversion
6. **Feature Diversity Score** — breadth of distinct activities per org vs conversion
7. **Feature Combination Analysis** — co-occurrence lift for all pairs and triplets of top 6 features
8. **Time-Based Analysis** — early engagement; time-to-first key action across 5 time windows
9. **Weekly Engagement Trajectory** — week-by-week activity split by converter vs non-converter
10. **Activity Recency** — last-active day correlation and conversion by trial week
11. **Logistic Regression** — org-level feature matrix; 5-fold cross-validated AUC; coefficient chart
12. **Activation Model** — binary baseline
13. **Score-Based Activation** — composite score (0-3) with conversion by score level

---

## Key Results

### What the data shows

| Dimension | Finding |
|---|---|
| Feature lift | Highest: Template Applied (+4.1%), Shift Created (+4.0%) |
| Statistical significance | None of the 10 features reached p < 0.05 — all lifts are noise |
| Feature frequency | No significant correlation between usage count and conversion |
| Feature diversity | No significant correlation (r = -0.0001, p = 0.996) |
| Feature combinations | Best pair: +5.9% lift, p = 0.24 — not significant |
| Time-to-first action | No time window produced significant lift for any key action |
| Weekly trajectory | Converters do not diverge from non-converters (ramp t-test p = 0.58) |
| Activity recency | Last-active day r = 0.024, p = 0.46 — no meaningful signal |
| Logistic regression AUC | 0.5088 +/- 0.0161 — near-random predictive power from product data |

### Score-based activation (actual results)

| Score | Orgs | Conversion Rate |
|---|---|---|
| 0 — no signals met | 369 | 20.6% |
| 1 — one signal met | 368 | 21.2% |
| 2 — two signals met | 173 | 22.5% |
| 3 — all signals met | 56 | 23.2% |

---

## Trial Goal Definition

### Recommended Activation Metric

An organization is **activated** if it achieves a **composite score >= 2** across three signals:

| Signal | Threshold | Rationale |
|---|---|---|
| Applied a scheduling template | >= 1 use | Rare behaviour (108/966 orgs), indicates intentional setup |
| Created shifts | >= 3 shifts | Depth threshold — excludes superficial first-touch exploration |
| Punched in (PunchClock) | >= 1 use | Cross-module engagement, signals operational adoption |

**Score >= 2 = Activated | Score <= 1 = Not Activated**

### Why this metric

- Binary OR activation (original) produces ~4% lift with p = 0.38 — indistinguishable from chance
- Score model shows monotonically increasing conversion across all four score levels
- Requiring depth (>= 3 shifts) avoids counting superficial touches as meaningful engagement
- PunchClock signal captures cross-module engagement, not just scheduling exploration

### Important caveat

AUC of 0.51 confirms that in-product usage data alone is a weak predictor of conversion. This metric is a directional signal only. True conversion drivers are likely external to the product.

---

## Recommended Data Enhancements

- **Organization size** — number of users invited or active during trial
- **Sales interactions** — demo attendance, support contacts, outbound touchpoints
- **Pricing exposure** — whether orgs viewed pricing or selected a plan tier
- **Industry segmentation** — hospitality, retail, healthcare behave differently
- **Time-to-first-value** — days from trial start to first published schedule
- **Invite signals** — whether managers invited team members during trial
- **Firmographic data** — company size, funding stage, sector

---

## Files

| File | Description |
|---|---|
| `RETRIAL_SPLENDOR_CHALLENGE_ENHANCED.ipynb` | Full enhanced analysis notebook |
| `splendor_trial_activation.sql` | All four SQL activation queries with inline comments |
| `README.md` | This file |
| `DAtask.csv` | Source event data |

---

## How to Run

1. Place `DAtask.csv` in the same directory as the notebook
2. `pip install pandas numpy matplotlib seaborn scipy scikit-learn`


---


