# GPC Segment `minSeedCover` Optimization — Summary

## Goal
Pick a `minSeedCover` for the GPC Nextclade dataset that maximizes specificity against mammarenavirus RefSeq while keeping LASV sensitivity.

## Data & Method
- **Sequences:** 44 mammarenavirus RefSeq (1 LASV NC_004296.1; 43 non-LASV)
- **Sweep:** `minSeedCover` 0.01–0.30 in 0.01 steps (30 thresholds)
- **Criteria:** LASV must pass; non-LASV should fail QC / receive no lineage

## Result
- **Chosen `minSeedCover`:** **0.16**
- **LASV sensitivity:** **100%** (NC_004296.1 passes across the tested range)
- **Specificity at 0.16:** **~98%** (42/43 non-LASV rejected)
- **Elimination notes:** Most non-LASV fail by ≤0.14; **gairoense** fails at 0.16; 

## Implementation
Update these files:
1. `defaults/gpc/pathogen.json`
2. `dataset/gpc/pathogen.json`

Parameter block:
```json
{
  "alignmentParams": {
    "minSeedCover": 0.16,
    "minLength": 663,
    "allowedMismatches": 10,
    "penaltyGapExtend": 1,
    "penaltyGapOpen": 8,
    "penaltyMismatch": 1,
    "scoreMatch": 5,
    "retryReverseComplement": true
  }
}
*Nextclade version: 3.17.0* *Analysis tool: seedcover_sweep_plotly.py*