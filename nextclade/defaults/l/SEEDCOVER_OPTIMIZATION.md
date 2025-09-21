# L Segment `minSeedCover` Optimization — Summary

## Goal
Select a `minSeedCover` for the L-segment Nextclade dataset that maximizes specificity against mammarenavirus RefSeq while retaining LASV sensitivity.

## Data & Method
- **Sequences:** 44 mammarenavirus RefSeq (1 LASV NC_004297.1; 43 non-LASV)
- **Sweep:** `minSeedCover` 0.01–0.30 in 0.01 steps (30 thresholds)
- **Criteria:** LASV must pass; non-LASV should fail QC / receive no lineage

## Result
- **Chosen `minSeedCover`:** **0.12**
- **LASV sensitivity:** **100%** (NC_004297.1 passes across the tested range)
- **Specificity at 0.12:** **100%** (43/43 non-LASV rejected)
- **Elimination notes:** Many non-LASV fail by ≤0.11; **dhati-welelense** is last to fail at **0.12**; LASV never fails within the tested range

## Implementation
Update these files:
1. `defaults/l/pathogen.json` (0.13 → **0.12**)
2. `dataset/l/pathogen.json` (0.13 → **0.12**)

Parameter block:
```json
{
  "alignmentParams": {
    "minSeedCover": 0.12,
    "minLength": 800,
    "allowedMismatches": 10,
    "penaltyGapExtend": 1,
    "penaltyGapOpen": 8,
    "penaltyMismatch": 1,
    "scoreMatch": 5,
    "retryReverseComplement": true
  }
}
