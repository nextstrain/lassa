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
        include = config['filter']['include'],
        exclude = config['filter']['exclude']
    output:
        sequences = "results/{segment}/filtered.fasta"
    log:
        "logs/{segment}/filter.txt",
    benchmark:
        "benchmarks/{segment}/filter.txt"
    params:
        strain_id_field = config["strain_id_field"],
        min_length = lambda wildcards: config['filter']['min_length'][wildcards.segment],
        query = config['filter']['query'],
        custom_params = config['filter']['custom_params'],
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --include {input.include} \
            --exclude {input.exclude} \
            --min-length {params.min_length} \
            --query "{params.query}" \
            --output {output.sequences} \
            
            2>&1 | tee {log}
        """
#{params.custom_params} \
rule download_alignment:
    """
    Download the manually fixed GPC alignment that maintains codon alignment
    """
    output:
        manual_curated_alignment = "data/gpc/manual_alignment.fasta"
    params:
        gpc_manual_alignment=config["gpc_manual_alignment"]
    shell:
        """
        curl -fsSL  {params.gpc_manual_alignment} --output {output.manual_curated_alignment}
        """

rule find_and_remove_existing:
    """
    Find and remove existing sequences for GPC segment
    """
    input:
        sequences="data/gpc/sequences.fasta",
        manual_curated_alignment = "data/gpc/manual_alignment.fasta"
    output:
        sequences="results/gpc/new_sequences.fasta"
    benchmark:
        "benchmarks/gpc/find_and_remove_existing.txt"
    log:
        "logs/gpc/find_and_remove_existing.txt",
    shell:
        """
        python scripts/manual_curated_processor.py \
            --sequences {input.sequences} \
            --manual-curated-alignment {input.manual_curated_alignment} \
            --output-sequences {output.sequences} \
            2>&1 | tee {log}
        """

rule align:
    """
    Align sequences based on segment type:
      - Augur align for S and L segments
    """
    input:
        sequences = "results/{segment}/filtered.fasta",
        reference = "defaults/lassa_{segment}.gb"
    output:
        alignment = "results/{segment}/aligned.fasta"
    log:
        "logs/{segment}/align.txt"
    benchmark:
        "benchmarks/{segment}/align.txt"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps \
            --remove-reference \
            2>&1 | tee {log}
        """

ruleorder: align_gpc > align

rule align_gpc:
    """
    Align new GPC sequences with existing alignment:
      - Augur align with --existing-alignment for GPC segment to maintain codon alignment
    """
    input:
        sequences = "results/gpc/new_sequences.fasta",
        manual_alignment = "data/gpc/manual_alignment.fasta"
    output:
        alignment = "results/gpc/aligned_with_new.fasta"
    log:
        "logs/gpc/align.txt"
    benchmark:
        "benchmarks/gpc/align_gpc.txt"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --existing-alignment {input.manual_alignment} \
            --output {output.alignment} \
            2>&1 | tee {log}
        """

ruleorder: filter_gpc > align

rule filter_gpc:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
      - including strains in {input.include}
    """
    input:
        sequences = "results/gpc/aligned_with_new.fasta",
        metadata = "data/gpc/metadata.tsv",
        include = config['filter']['include'],
        exclude = config['filter']['exclude']
    output:
        sequences = "results/gpc/aligned.fasta"
    log:
        "logs/gpc/filter_gpc.txt",
    benchmark:
        "benchmarks/gpc/filter_gpc.txt"
    params:
        strain_id_field = config["strain_id_field"],
        min_length = lambda wildcards: config['filter']['min_length']['gpc'],
        query = config['filter']['query'],
        custom_params = config['filter']['custom_params'],
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --include {input.include} \
            --exclude {input.exclude} \
            --min-length {params.min_length} \
            --query "{params.query}" \
            --output {output.sequences} \
            {params.custom_params} \
            2>&1 | tee {log}
        """
        #{params.custom_params} \