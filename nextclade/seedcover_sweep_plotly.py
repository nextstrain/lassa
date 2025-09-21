#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
End-to-end Nextclade v3 seed-cover sweep with Plotly visualizations.

What it does
------------
1) Sweeps --min-seed-cover over a range you provide.
2) Captures NDJSON output so we reliably see PASS/FAIL for every sequence.
3) Finds the smallest threshold where *only* keep-regex (e.g., LASV) still PASS.
4) Writes tidy CSVs, per-threshold PASS lists, and two interactive HTML plots.

Outputs
-------
<out>/
  nextclade_version.txt
  summary.txt
  per_threshold_pass/
      pass_t_0.01.txt
      pass_t_0.02.txt
      ...
  long_results.csv               # threshold, seq, virus, status, is_keep
  first_elimination_thresholds.csv
  pass_fail_matrix.csv
  virus_elimination_median.csv
  elim_bar.html                  # interactive Plotly bar
  pass_fail_heatmap.html         # interactive Plotly heatmap

Usage example
-------------
python seedcover_sweep_plotly.py \
  --dataset nextclade_data/lassa/S \
  --fasta data/mammarenavirus_refseq.fasta \
  --out runs_seedcover_S \
  --keep-regex 'Lassa|LASV|Lassa_virus' \
  --min 0.01 --max 0.30 --step 0.01
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go


# --------------------------- utilities ---------------------------

def shell(cmd, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=False, text=True, capture_output=True, **kwargs)

def ensure_nextclade_v3(outdir: Path):
    """Require Nextclade v3.x and write version file."""
    cp = shell(["nextclade", "--version"])
    version = (cp.stdout or cp.stderr).strip()
    (outdir / "nextclade_version.txt").write_text(version + "\n")
    if not version:
        sys.exit("Error: could not read nextclade version. Is it installed?")
    # Accept formats like "v3.18.0", "Nextclade v3.18.0", or "nextclade 3.17.0"
    m = re.search(r"(?:v)?(\d+)\.", version)
    if not (m and m.group(1) == "3"):
        sys.exit(f"Error: this workflow requires Nextclade v3.x (found: '{version}')")

def thresholds(min_v: float, max_v: float, step: float):
    t = min_v
    out = []
    while t <= max_v + 1e-12:
        out.append(round(t, 6))
        t += step
    return out

def run_sweep(dataset_dir: Path, fasta: Path, outdir: Path, tvals):
    for t in tvals:
        tag = f"{t:.3f}"
        od = outdir / f"minseed_{tag}"
        od.mkdir(parents=True, exist_ok=True)
        cmd = [
            "nextclade", "run",
            "--input-dataset", str(dataset_dir),
            "--min-seed-cover", f"{t}",
            "--output-ndjson", str(od / "results.ndjson"),
            "--output-tsv", str(od / "results.tsv"),
            str(fasta)
        ]
        # Don't abort if nextclade returns non-zero due to per-sequence errors
        _ = shell(cmd)
        # also write STDERR for debugging
        (od / "stderr.log").write_text(_.stderr or "")

def parse_results(outdir: Path, keep_regex: str) -> pd.DataFrame:
    rows = []
    for nd in sorted(outdir.glob("minseed_*/results.ndjson")):
        tag = nd.parent.name.split("_")[-1]
        try:
            t = float(tag)
        except ValueError:
            continue
        with nd.open() as fh:
            for line in fh:
                if not line.strip():
                    continue
                rec = json.loads(line)
                name = rec.get("seqName")
                errs = rec.get("errors", []) or []
                status = "pass" if len(errs) == 0 else "fail"
                # virus/species label from header: token before first space or pipe
                virus = re.split(r"[| ]", name or "")[0]
                rows.append({
                    "threshold": t,
                    "seq": name,
                    "virus": virus,
                    "status": status
                })
    df = pd.DataFrame(rows)
    if df.empty:
        sys.exit("No NDJSON parsed. Did Nextclade write results?")
    df["is_keep"] = df["seq"].str.contains(keep_regex, case=False, regex=True)
    return df

def choose_cutoff(df: pd.DataFrame):
    """Smallest threshold where ONLY keep-regex sequences remain passing."""
    cutoff = None
    for t in sorted(df["threshold"].unique()):
        sub = df[df["threshold"] == t]
        pass_only = sub[sub["status"] == "pass"]
        if pass_only.empty:
            continue
        if pass_only["is_keep"].all():
            cutoff = t
            break
    return cutoff

def summarize_tables(df: pd.DataFrame, outdir: Path):
    # First-fail per sequence (earliest threshold with FAIL)
    first_fail = (df[df.status == "fail"]
                  .sort_values(["seq", "threshold"])
                  .groupby("seq", as_index=False)
                  .first()[["seq", "threshold"]]
                  .rename(columns={"threshold": "first_fail_threshold"}))
    all_seqs = df["seq"].drop_duplicates().to_frame()
    elim = all_seqs.merge(first_fail, on="seq", how="left")
    sentinel = df["threshold"].max() + 1e-3
    elim["first_fail_threshold"] = elim["first_fail_threshold"].fillna(sentinel)
    # annotate labels
    seq_labels = df[["seq", "virus", "is_keep"]].drop_duplicates()
    elim = elim.merge(seq_labels, on="seq", how="left")

    # Pass/fail matrix
    mat = (df.assign(val=(df.status == "pass").astype(int))
             .pivot_table(index="seq", columns="threshold", values="val", aggfunc="max"))
    order = elim.sort_values("first_fail_threshold", ascending=True)["seq"].tolist()
    mat = mat.loc[order]

    # Per-virus summary
    by_virus = (elim.groupby("virus", as_index=False)["first_fail_threshold"].median()
                   .sort_values("first_fail_threshold"))

    # Write
    df.to_csv(outdir / "long_results.csv", index=False)
    elim.to_csv(outdir / "first_elimination_thresholds.csv", index=False)
    mat.to_csv(outdir / "pass_fail_matrix.csv")
    by_virus.to_csv(outdir / "virus_elimination_median.csv", index=False)
    return elim, mat

def write_pass_lists(df: pd.DataFrame, outdir: Path):
    """Write per-threshold PASS sequence lists, plus a summary counts table."""
    pdir = outdir / "per_threshold_pass"
    pdir.mkdir(exist_ok=True)
    rows = []
    for t, sub in df.groupby("threshold", sort=True):
        passes = sub[sub.status == "pass"]["seq"].tolist()
        (pdir / f"pass_t_{t:.3f}.txt").write_text("\n".join(passes) + ("\n" if passes else ""))
        rows.append({"threshold": t, "n_pass": len(passes), "n_keep_pass": int(sub[(sub.status=="pass") & (sub.is_keep)].shape[0])})
    pd.DataFrame(rows).sort_values("threshold").to_csv(outdir / "pass_counts_by_threshold.csv", index=False)

def plot_bar(elim: pd.DataFrame, out_html: Path, cutoff: float | None):
    # Rank by earliest dropout (first eliminated on top, last below)
    dd = elim.sort_values("first_fail_threshold", ascending=True).copy()
    dd["label"] = dd["seq"]  # Show full sequence names, no truncation
    
    fig = px.bar(
        dd,
        y="label",
        x="first_fail_threshold",
        color="is_keep",
        color_discrete_map={True: "#1f77b4", False: "#d62728"},
        title="Mammarenavirus species assignment across minSeedCover thresholds",
        labels={"label": "Sequences (ranked by earliest dropout)", "first_fail_threshold": "First FAIL threshold", "is_keep": "Keep (LASV)"},
        orientation='h'  # Make bars horizontal
    )
    
    # Calculate height based on number of sequences
    num_sequences = len(dd)
    height = max(600, num_sequences * 25)  # 25px per sequence, minimum 600px
    
    fig.update_layout(
        yaxis_tickangle=0, 
        hovermode="y unified",
        height=height,  # Dynamic height based on number of sequences
        margin=dict(l=300, r=100, t=100, b=100),  # More left margin for full sequence names
        yaxis=dict(
            tickfont=dict(size=10),  # Smaller font for better fit
            showticklabels=True,     # Ensure all labels are shown
            tickmode='linear'        # Show all ticks
        )
    )
    
    if cutoff is not None:
        fig.add_vline(x=cutoff, line_dash="dash", line_width=2, annotation_text=f"Optimal {cutoff:.3f}", annotation_position="top right")
    
    fig.write_html(str(out_html), include_plotlyjs="cdn")

def plot_heatmap(mat: pd.DataFrame, out_html: Path, cutoff: float | None):
    # mat: rows=seq, cols=threshold; values 0/1
    z = mat.values
    y = [s if len(s) <= 60 else s[:57] + "…" for s in mat.index.tolist()]
    x = [f"{float(t):.3f}" for t in mat.columns.tolist()]
    fig = go.Figure(data=go.Heatmap(z=z, x=x, y=y, colorbar=dict(title="Pass (1) / Fail (0)")))
    fig.update_layout(
        title="Pass/Fail across minSeedCover thresholds",
        xaxis_title="minSeedCover",
        yaxis_title="Sequences",
        xaxis_tickangle=60,
    )
    if cutoff is not None:
        # nearest column to cutoff
        tcol = int(np.argmin(np.abs(np.array(mat.columns, float) - cutoff)))
        fig.add_vline(x=tcol, line_dash="dash", line_width=2)
    fig.write_html(str(out_html), include_plotlyjs="cdn")


# --------------------------- main ---------------------------

def main():
    ap = argparse.ArgumentParser(description="Nextclade v3 min-seed-cover sweep (Plotly version)")
    ap.add_argument("--dataset", required=True, help="Path to Nextclade dataset (L/S/GPC)")
    ap.add_argument("--fasta", required=True, help="Path to input multi-FASTA (headers contain viral name)")
    ap.add_argument("--out", required=True, help="Output directory")
    ap.add_argument("--keep-regex", default=r"Lassa|LASV|Lassa_virus",
                    help="Regex matching headers to KEEP (e.g., LASV). Default matches common LASV tokens.")
    ap.add_argument("--min", type=float, default=0.01)
    ap.add_argument("--max", type=float, default=0.30)
    ap.add_argument("--step", type=float, default=0.01)
    args = ap.parse_args()

    dataset = Path(args.dataset)
    fasta = Path(args.fasta)
    outdir = Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)

    if not shutil.which("nextclade"):
        sys.exit("Error: nextclade CLI not found on PATH.")
    if not dataset.exists():
        sys.exit(f"Dataset not found: {dataset}")
    if not fasta.exists():
        sys.exit(f"FASTA not found: {fasta}")

    # 1) Require Nextclade v3
    ensure_nextclade_v3(outdir)

    # 2) Build threshold grid and run sweep
    tvals = thresholds(args.min, args.max, args.step)
    print(f"[1/5] Running Nextclade sweep across {len(tvals)} thresholds…")
    run_sweep(dataset, fasta, outdir, tvals)

    # 3) Parse results
    print("[2/5] Parsing NDJSON & classifying PASS/FAIL…")
    df = parse_results(outdir, args.keep_regex)

    # 4) Choose cutoff and write PASS lists each time
    print("[3/5] Choosing cutoff where only KEEP sequences still PASS…")
    cutoff = choose_cutoff(df)
    print(f"Suggested min-seed-cover cutoff: {cutoff}")
    print("[4/5] Writing per-threshold PASS lists and summary tables…")
    write_pass_lists(df, outdir)
    elim, mat = summarize_tables(df, outdir)

    # 5) Plots
    print("[5/5] Building interactive Plotly visuals…")
    plot_bar(elim, outdir / "elim_bar.html", cutoff)
    # plot_heatmap(mat, outdir / "pass_fail_heatmap.html", cutoff)  # Skip heatmap

    # Summary file
    keep_total = df[df["is_keep"]]["seq"].nunique()
    total = df["seq"].nunique()
    (outdir / "summary.txt").write_text(
        f"Suggested min-seed-cover cutoff: {cutoff}\n"
        f"Sequences total: {total}, keep-matching (e.g., LASV): {keep_total}\n"
        f"PASS lists: per_threshold_pass/*.txt\n"
        f"Interactive plot: elim_bar.html (horizontal bar chart)\n"
    )
    print("Done. See outputs in:", outdir)

if __name__ == "__main__":
    main()