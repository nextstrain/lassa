"""
This part of the workflow prepares sequences for constructing the reference tree
of the Nextclade dataset.

REQUIRED INPUTS:

    metadata    = data/metadata.tsv
    sequences   = data/sequences.fasta
    reference   = ../shared/reference.fasta

OUTPUTS:

    prepared_sequences = results/prepared_sequences.fasta

This part of the workflow usually includes the following steps:

    - augur index
    - augur filter
    - nextclade run
    - augur mask

See Nextclade's and Augur's usage docs for these commands for more details.
"""

rule align:
    """
    Align sequences based on segment type:
    """
    input:
        sequences = "results/{segment}/filtered.fasta",
        reference = "../phylogenetic/defaults/{segment}/reference.gb"
    output:
        alignment = "results/{segment}/aligned.fasta"
    log:
        "logs/{segment}/align.txt"
    benchmark:
        "benchmarks/{segment}/align.txt"
    shell:
        r"""
        augur align \
            --sequences {input.sequences:q} \
            --reference-sequence {input.reference:q} \
            --output {output.alignment:q} \
            --fill-gaps \
            --remove-reference \
            2>&1 | tee {log:q}
        """