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

DATASET_NAMES = config["nextclade"]["dataset_name"]

wildcard_constraints:
    DATASET_NAME = "|".join(DATASET_NAMES)

rule run_nextclade_to_identify_segment:
    input:
        sequences = "results/all/sequences.fasta",
        segment_reference = config["nextclade_segment"]["segment_reference"],
    output:
        sequences = "data/{segment}/sequences.fasta",
        segment = temp("data/{segment}/segment.tsv"),
    log:
        "logs/{segment}/run_nextclade_to_identify_segment.txt"
    benchmark:
        "benchmarks/{segment}/run_nextclade_to_identify_segment.txt"
    params:
        min_seed_cover = config["nextclade_segment"]["min_seed_cover"],
    shell:
        r"""
        exec &> >(tee {log:q})

        nextclade run \
            --input-ref {input.segment_reference:q} \
            --output-fasta {output.sequences:q} \
            --min-seed-cover {params.min_seed_cover:q} \
            --retry-reverse-complement true \
            --silent \
            {input.sequences:q}

        echo "accession|segment" \
            | tr '|' '\t' \
            > {output.segment:q}

        grep ">" {output.sequences:q} \
            | sed 's/>//g' \
            | awk '{{print $1"\t{wildcards.segment}"}}' \
            >> {output.segment:q}
        """

rule run_nextclade:
    """
    Lassa lineage calls
    """
    input:
        sequences="results/all/sequences.fasta",
        dataset=lambda wildcards: directory(f"../nextclade_data/{wildcards.DATASET_NAME}"),
    output:
        nextclade="results/{DATASET_NAME}/nextclade.tsv",
    threads: 4
    log:
        "logs/{DATASET_NAME}/run_nextclade.txt",
    benchmark:
        "benchmarks/{DATASET_NAME}/run_nextclade.txt",
    shell:
        r"""
        exec &> >(tee {log:q})

        nextclade3 run \
            --input-dataset {input.dataset:q} \
            -j {threads:q} \
            --output-tsv {output.nextclade:q} \
            --silent \
            {input.sequences:q} \
          &> {log:q}
        """

rule nextclade_metadata:
    input:
        nextclade="results/{DATASET_NAME}/nextclade.tsv",
    output:
        nextclade_metadata=temp("results/{DATASET_NAME}/nextclade_metadata.tsv"),
    log:
        "logs/{DATASET_NAME}/nextclade_metadata.txt",
    benchmark:
        "benchmarks/{DATASET_NAME}/nextclade_metadata.txt",
    params:
        nextclade_id_field=config["nextclade"]["id_field"],
        nextclade_field_map=lambda wildcard: [f"{old}={new}" for old, new in config["nextclade"][wildcard.DATASET_NAME]["field_map"].items()],
        nextclade_fields=lambda wildcard: ",".join(config["nextclade"][wildcard.DATASET_NAME]["field_map"].values()),
    shell:
        r"""
        exec &> >(tee {log:q})

        augur curate rename \
            --metadata {input.nextclade:q} \
            --id-column {params.nextclade_id_field:q} \
            --field-map {params.nextclade_field_map:q} \
            --output-metadata - \
        | csvtk cut -t --fields {params.nextclade_fields:q} \
        > {output.nextclade_metadata:q} \
        2>&1 | tee {log:q}
        """

rule append_nextclade_columns:
    """
    Append the Nextclade results to the metadata
    """
    input:
        metadata="data/subset_metadata.tsv",
        gpc_nextclade="results/gpc/nextclade_metadata.tsv",
        l_nextclade="results/l/nextclade_metadata.tsv",
        s_nextclade="results/s/nextclade_metadata.tsv",
        sub_lineage=config["sublineage_metadata"],
        s_segment="data/s/segment.tsv",
        l_segment="data/l/segment.tsv",
    output:
        metadata="results/all/metadata.tsv",
    params:
        metadata_id_field=config["curate"]["output_id_field"],
    log:
        "logs/append_nextclade_columns.txt",
    benchmark:
        "benchmarks/append_nextclade_columns.txt",
    shell:
        r"""
        exec &> >(tee {log:q})

        augur merge \
            --metadata \
                metadata={input.metadata:q} \
                gpc_nextclade={input.gpc_nextclade:q} \
                l_nextclade={input.l_nextclade:q} \
                s_nextclade={input.s_nextclade:q} \
                sublineage_nextclade={input.sub_lineage:q} \
                s_segment={input.s_segment:q} \
                l_segment={input.l_segment:q} \
            --metadata-id-columns {params.metadata_id_field:q} \
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
    log:
        "logs/{segment}/subset_metadata_by_segment.txt",
    benchmark:
        "benchmarks/{segment}/subset_metadata_by_segment.txt",
    params:
        strain_id_field = config["curate"]["output_id_field"],
    shell:
        r"""
        exec &> >(tee {log:q})

        augur filter \
            --sequences {input.segment_sequences:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.strain_id_field:q} \
            --output-metadata {output.metadata:q}

        augur filter \
            --sequences {input.sequences:q} \
            --metadata {output.metadata:q} \
            --metadata-id-columns {params.strain_id_field:q} \
            --output-sequences {output.sequences:q}
        """
