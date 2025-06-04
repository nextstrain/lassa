#!/usr/bin/env python3

import csv
import argparse

def parse_args():
    parser = argparse.ArgumentParser(
        description="If clade_membership is empty, fill with lineage value",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--input-metadata",
        type=str,
        required=True,
        help="Path to input metadata TSV file",
    )
    parser.add_argument(
        "--output-metadata",
        type=str,
        required=True,
        help="Path to output metadata TSV file",
    )
    parser.add_argument(
        "--clade-membership-column",
        type=str,
        default="clade_membership",
        help="Name of the column to fill if empty",
    )
    parser.add_argument(
        "--genotype-column",
        type=str,
        default="lineage",
        help="Name of the column to use as a fallback",
    )
    return parser.parse_args()

def fill_clade_membership(input_path, output_path, clade_membership_col, fill_col):
    with open(input_path, newline='', encoding='utf-8') as infile, \
         open(output_path, 'w', newline='', encoding='utf-8') as outfile:

        reader = csv.DictReader(infile, delimiter='\t')
        fieldnames = reader.fieldnames

        if clade_membership_col not in fieldnames or fill_col not in fieldnames:
            raise ValueError(f"Input file must contain '{clade_membership_col}' and '{fill_col}' columns")

        writer = csv.DictWriter(outfile, fieldnames=fieldnames, delimiter='\t')
        writer.writeheader()

        for row in reader:
            if row.get(clade_membership_col, '').strip() == '':
                row[clade_membership_col] = row.get(fill_col, '')
            writer.writerow(row)

def main():
    args = parse_args()
    fill_clade_membership(
        args.input_metadata,
        args.output_metadata,
        args.clade_membership_column,
        args.genotype_column
    )

if __name__ == '__main__':
    main()
