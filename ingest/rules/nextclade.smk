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
        sequences = "results/all/sequences.fasta",
        segment_reference = config["nextclade"]["segment_reference"],
    output:
        sequences = "data/{segment}/sequences.fasta",
        segment = temp("data/{segment}/segment.tsv"),
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

        echo "accession|segment" \
            | tr '|' '\t' \
            > {output.segment}

        grep ">" {output.sequences} \
            | sed 's/>//g' \
            | awk '{{print $1"\t{wildcards.segment}"}}' \
            >> {output.segment}
        """

rule run_nextclade:
    """
    Lassa lineage call based on the GPC region (within the S segment)
    """
    input:
        sequences="results/all/sequences.fasta",
        dataset="../nextclade_data",
    output:
        nextclade="results/nextclade.tsv",
    threads: 4
    params:
        min_length=config["nextclade"]["min_length"],
    log:
        "logs/run_nextclade.txt",
    benchmark:
        "benchmarks/run_nextclade.txt",
    shell:
        r"""
        nextclade3 run \
            --input-dataset {input.dataset} \
            -j {threads} \
            --output-tsv {output.nextclade} \
            --silent \
            --min-length {params.min_length} \
            {input.sequences} \
          &> {log:q}
        """

rule select_nextclade_results:
    """
    Select fields from the Nextclade results
    """
    input:
        nextclade="results/nextclade.tsv",
    output:
        nextclade=temp("data/nextclade_selected.tsv"),
    params:
        input_nextclade_fields=",".join([f'{key}' for key, value in config["nextclade"]["field_map"].items()]),
        output_nextclade_fields=",".join([f'{value}' for key, value in config["nextclade"]["field_map"].items()]),
    log:
        "logs/select_nextclade_results.txt",
    benchmark:
        "benchmarks/select_nextclade_results.txt",
    shell:
        """
        echo "{params.output_nextclade_fields}" \
        | tr ',' '\t' \
        > {output.nextclade}

        tsv-select -H -f "{params.input_nextclade_fields}" {input.nextclade} \
        | awk 'NR>1 {{print}}' \
        >> {output.nextclade}
        """

rule append_nextclade_columns:
    """
    Append the Nextclade results to the metadata
    """
    input:
        metadata="data/subset_metadata.tsv",
        nextclade="data/nextclade_selected.tsv",
        s_segment="data/s/segment.tsv",
        l_segment="data/l/segment.tsv",
    output:
        metadata="results/all/metadata.tsv",
    params:
        metadata_id_field=config["curate"]["output_id_field"],
        nextclade_id_field=config["nextclade"]["id_field"],
    log:
        "logs/append_nextclade_columns.txt",
    benchmark:
        "benchmarks/append_nextclade_columns.txt",
    shell:
        """
        augur merge \
            --metadata \
                metadata={input.metadata:q} \
                nextclade={input.nextclade:q} \
                s_segment={input.s_segment:q} \
                l_segment={input.l_segment:q} \
            --metadata-id-columns \
                metadata={params.metadata_id_field:q} \
                nextclade={params.nextclade_id_field:q} \
                s_segment={params.metadata_id_field:q} \
                l_segment={params.metadata_id_field:q} \
            --output-metadata {output.metadata:q} \
            --no-source-columns \
        &> {log:q}
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
