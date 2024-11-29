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

# Manually pull GPC manually aligned sequences and metadata
# And place in data folder
#
# augur filter \
# --sequences ../phylogenetic/results/gpc/aligned.fasta \
# --metadata ../phylogenetic/data/gpc/metadata.tsv \
# --metadata-id-columns accession \
# --exclude-all \
# --include defaults/include.txt \
# --output-metadata data/metadata.tsv \
# --output-sequences data/sequences.fasta
#
# Add the clade_membership and lineage_name columns to the metadata
