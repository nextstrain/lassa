"""
This part of the workflow handles running Nextclade on the curated metadata
and sequences to split the sequences into L and S segments.

REQUIRED INPUTS:

    metadata     = data/subset_metadata.tsv
    all_metadata = results/all/metadata.tsv
    sequences    = results/all/sequences.fasta

OUTPUTS:

    metadata        = results/{segment}/metadata.tsv
    sequences       = results/{segment}/sequences.fasta

See Nextclade docs for more details on usage, inputs, and outputs if you would
like to customize the rules:
https://docs.nextstrain.org/projects/nextclade/page/user/nextclade-cli.html
"""

rule run_nextclade_to_identify_segment:
    input:
        metadata = "data/subset_metadata.tsv",
        sequences = "results/all/sequences.fasta",
        segment_reference = config["nextclade"]["segment_reference"],
    output:
        sequences = "data/{segment}/sequences.fasta",
    params:
        min_seed_cover = config["nextclade"]["min_seed_cover"],
    shell:
        """
        nextclade run \
            --input-ref {input.segment_reference} \
            --output-fasta {output.sequences} \
            --min-seed-cover {params.min_seed_cover} \
            --retry-reverse-complement true \
            --silent \
            {input.sequences}
        """

rule subset_metadata_by_segment:
    input:
        segment_sequences = "data/{segment}/sequences.fasta",
        metadata = "results/all/metadata.tsv",
        sequences = "results/all/sequences.fasta",
    output:
        metadata = "results/{segment}/metadata.tsv",
        sequences = "results/{segment}/sequences.fasta",
    params:
        strain_id_field = config["curate"]["output_id_field"],
    shell:
        """
        augur filter \
            --sequences {input.segment_sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --output-metadata {output.metadata}

        augur filter \
            --sequences {input.sequences} \
            --metadata {output.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --output-sequences {output.sequences}
        """
