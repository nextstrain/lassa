"""
This part of the workflow prepares sequences for constructing the phylogenetic tree.

REQUIRED INPUTS:

    metadata    = data/metadata.tsv
    sequences   = data/sequences.fasta
    reference   = ../shared/reference.fasta

OUTPUTS:

    prepared_sequences = results/prepared_sequences.fasta

This part of the workflow usually includes the following steps:

    - augur index
    - augur filter
    - augur align
    - augur mask

See Augur's usage docs for these commands for more details.
"""

rule download:
    """Downloading sequences and metadata from data.nextstrain.org"""
    output:
        sequences = "data/{segment}/sequences.fasta.zst",
        metadata = "data/{segment}/metadata.tsv.zst"
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
        sequences = "data/{segment}/sequences.fasta.zst",
        metadata = "data/{segment}/metadata.tsv.zst"
    output:
        sequences = "data/{segment}/sequences.fasta",
        metadata = "data/{segment}/metadata.tsv"
    shell:
        """
        zstd -d -c {input.sequences} > {output.sequences}
        zstd -d -c {input.metadata} > {output.metadata}
        """

rule filter:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
    """
    input:
        sequences = "data/{segment}/sequences.fasta",
        metadata = "data/{segment}/metadata.tsv",
        exclude = config['filter']['exclude']
    output:
        sequences = "results/{segment}/filtered.fasta"
    params:
        strain_id_field = config["strain_id_field"],
        min_length = config['filter']['min_length'],
        exclude = config['filter']['exclude'],
        query = config['filter']['query'],
        custom_params = config['filter']['custom_params'],
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --output {output.sequences} \
            --min-length {params.min_length} \
            --exclude {input.exclude} \
            --query "{params.query}" \
            {params.custom_params}
        """

rule align:
    """
    Aligning sequences to {input.reference}
      - filling gaps with N
    """
    input:
        sequences = "results/{segment}/filtered.fasta",
        reference = "defaults/lassa_{segment}.gb"
    output:
        alignment = "results/{segment}/aligned.fasta"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps \
            --remove-reference
        """
