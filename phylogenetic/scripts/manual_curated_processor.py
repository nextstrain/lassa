from Bio import SeqIO
import argparse

def load_fasta_ids(fasta_file):
    """
    Load sequence IDs from a FASTA file into a set.
    """
    return {record.id for record in SeqIO.parse(fasta_file, "fasta")}

def filter_sequences(input_fasta, ids_to_exclude, output_fasta):
    """
    Write sequences to a file that are not in the ids_to_exclude set.
    """
    with open(output_fasta, "w") as output_handle:
        SeqIO.write((record for record in SeqIO.parse(input_fasta, "fasta") if record.id not in ids_to_exclude),
                    output_handle, "fasta")

def remove_already_exist(alignment_fasta, full_fasta, output_fasta):
    # Step 1: Load IDs from the alignment FASTA file
    alignment_ids = load_fasta_ids(alignment_fasta)
    print(f"Number of sequences in alignment: {len(alignment_ids)}")

    # Step 2: Filter sequences from the full FASTA file that are not in the alignment
    filter_sequences(full_fasta, alignment_ids, output_fasta)

    print(f"Sequences not in alignment have been written to {output_fasta}")

if __name__=="__main__":
    parser = argparse.ArgumentParser(
        description="Find and remove existing sequences for GPC segment. This identifies new sequences that need to be passed to augur align --existing-alignment to maintain codon positions.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument('--sequences', type=str, required=True, help="input sequences FASTA")
    parser.add_argument('--manual-curated-alignment', type=str, required=True, help="input manually curated FASTA alignment")
    parser.add_argument('--output-sequences', type=str, required=True, help="output new sequences FASTA")
    args = parser.parse_args()

    remove_already_exist(args.manual_curated_alignment, args.sequences, args.output_sequences)