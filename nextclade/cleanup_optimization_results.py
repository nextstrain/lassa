#!/usr/bin/env python3
"""
Clean up optimization results to keep only essential files.
Removes large NDJSON/TSV files but keeps CSV summaries and HTML plots.
"""

import os
import shutil
from pathlib import Path

def cleanup_sweep_directory(sweep_dir: Path):
    """Clean up a sweep directory, keeping only essential files."""
    
    if not sweep_dir.exists():
        print(f"Directory {sweep_dir} does not exist, skipping...")
        return
    
    print(f"Cleaning up {sweep_dir}...")
    
    # Remove large directories
    for item in sweep_dir.iterdir():
        if item.is_dir() and item.name.startswith("minseed_"):
            print(f"  Removing {item}")
            shutil.rmtree(item)
    
    # Remove large files
    large_files = [
        "*.ndjson",
        "*.tsv", 
        "stderr.log"
    ]
    
    for pattern in large_files:
        for file in sweep_dir.glob(pattern):
            print(f"  Removing {file}")
            file.unlink()
    
    # Keep essential files:
    # - summary.txt
    # - *.csv files
    # - *.html files
    # - per_threshold_pass/ directory
    
    print(f"  Kept essential files in {sweep_dir}")

def main():
    """Clean up both L and GPC segment sweep directories."""
    
    # Clean up L segment
    cleanup_sweep_directory(Path("l_segment_sweep"))
    
    # Clean up GPC segment  
    cleanup_sweep_directory(Path("gpc_segment_sweep"))
    
    print("\nCleanup complete!")
    print("Essential files kept:")
    print("- summary.txt")
    print("- *.csv files (analysis results)")
    print("- *.html files (interactive plots)")
    print("- per_threshold_pass/ (pass lists)")
    print("\nLarge files removed:")
    print("- minseed_*/ directories")
    print("- *.ndjson files")
    print("- *.tsv files")
    print("- stderr.log files")

if __name__ == "__main__":
    main()