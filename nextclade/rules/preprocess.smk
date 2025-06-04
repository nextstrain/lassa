"""
This part of the workflow preprocesses any data and files related to the
lineages/clades designations of the pathogen.

REQUIRED INPUTS:

    None

OUTPUTS:

    metadata    = data/metadata.tsv
    sequences   = data/sequences.fasta

    There will be many pathogen specific outputs from this part of the workflow
    due to the many ways lineages and/or clades are maintained and defined.

This part of the workflow usually includes steps to download and curate the required files.
"""

rule download:
    """Downloading sequences and metadata from data.nextstrain.org"""
    output:
        sequences = "data/sequences.fasta.zst",
        metadata = "data/metadata.tsv.zst"
    params:
        sequences_url = config["sequences_url"],
        metadata_url = config["metadata_url"],
    shell:
        """
        curl -fsSL --compressed {params.sequences_url:q} --output {output.sequences}
        curl -fsSL --compressed {params.metadata_url:q} --output {output.metadata}
        """

rule decompress:
    """Decompressing sequences and metadata"""
    input:
        sequences = "data/sequences.fasta.zst",
        metadata = "data/metadata.tsv.zst"
    output:
        sequences = "data/sequences.fasta",
        metadata = "data/metadata.tsv"
    shell:
        """
        zstd -d -c {input.sequences} > {output.sequences}
        zstd -d -c {input.metadata} > {output.metadata}
        """

rule merge_clade_membership:
    input:
        metadata="data/metadata.tsv",
        clade_membership=config['clade_membership']['metadata'],
    output:
        merged_metadata="data/{segment}/metadata_merged_raw.tsv",
    benchmark:
        "benchmarks/{segment}/merge_clade_membership.txt",
    params:
        metadata_id='accession',
        clade_membership_id='accession',
    shell:
        r"""
        augur merge \
        --metadata a={input.metadata:q} b={input.clade_membership:q} \
        --metadata-id-columns a={params.metadata_id:q} b={params.clade_membership_id:q} \
        --output-metadata {output.merged_metadata:q}
        """

rule fill_in_clade_membership:
    input:
        merged_metadata="data/{segment}/metadata_merged_raw.tsv",
    output:
        merged_metadata="data/{segment}/metadata_merged.tsv",
    log:
        "logs/{segment}/fill_in_clade_membership.txt",
    benchmark:
        "benchmarks/{segment}/fill_in_clade_membership.txt",
    params:
        clade_membership_column="clade_membership",
        genotype_column=config['clade_membership']['fallback']
    shell:
        r"""
        exec &> >(tee {log:q})

        python scripts/fill-clade-membership.py \
          --input-metadata {input.merged_metadata:q} \
          --output-metadata {output.merged_metadata:q} \
          --clade-membership-column {params.clade_membership_column:q} \
          --genotype-column {params.genotype_column:q}
        """

rule filter:
    """
    Filtering to
      - various criteria based on the auspice JSON target
      - excluding strains in {input.exclude}
      - including strains in {input.include}
    """
    input:
        sequences = "data/sequences.fasta",
        metadata = "data/{segment}/metadata_merged.tsv",
        exclude = "defaults/{segment}/exclude.txt",
        include = "defaults/{segment}/include.txt",
    output:
        sequences = "results/{segment}/filtered.fasta",
        metadata = "results/{segment}/metadata.tsv",
    log:
        "logs/{segment}/filtered.txt",
    benchmark:
        "benchmarks/{segment}/filtered.txt",
    params:
        filter_params = lambda wildcard: config['filter'][wildcard.segment],
        strain_id = config.get("strain_id_field", "strain"),
    shell:
        r"""
        augur filter \
            --sequences {input.sequences:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.strain_id:q} \
            --exclude {input.exclude:q} \
            --include {input.include:q} \
            --output-sequence {output.sequences:q} \
            --output-metadata {output.metadata:q} \
            {params.filter_params} 2>&1 | tee {log:q}
        """
