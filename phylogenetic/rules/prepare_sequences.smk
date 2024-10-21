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
# {params.custom_params} \
rule download_alignment:
    """Download alignment only for GPC segment if it doesn't exist"""
    output:
        manual_curated_alignment = "data/manual_alignment.fasta"
    log:
        "logs/gpc/download_alignment.txt"
    run:
        # Only proceed if the file does not already exist
        if not os.path.exists(output.manual_curated_alignment):
            shell("""
                wget https://raw.githubusercontent.com/JoiRichi/LASV_ML_manuscript_data/main/alignment_preprocessing/final_passed_sequences.fasta \
                -O {output.manual_curated_alignment}
            """)
        else:
            print("Manual curated alignment already exists.")


    
rule find_and_remove_existing:
    """Find and remove existing sequences for GPC segment"""
    input:
        sequences="results/all/sequences.fasta",
        manual_curated_alignment = "data/manual_alignment.fasta"
    output:
        sequences="results/{segment}/filtered.fasta"
    log:
        "logs/{segment}/find_and_remove_existing.txt",
    run:
        # Only run if the segment is "GPC"
        if wildcards.segment == "gpc":
            # Run the function to remove existing sequences
            remove_already_exist(input.manual_curated_alignment, input.sequences, output.sequences)
        else:
            print(f"Skipping find_and_remove_existing for segment {wildcards.segment}.")


rule align:
    """
    Align sequences based on segment type:
      - MAFFT with --addfragments and --keeplength for GPC segment
      - Augur align for S and L segments
    """
    input:
        sequences = "results/{segment}/filtered.fasta",
        reference = lambda wildcards: (
            "data/manual_alignment.fasta" if wildcards.segment == "gpc" else f"defaults/lassa_{wildcards.segment}.gb"
        )
    output:
        alignment = "results/{segment}/aligned.fasta"
    log:
        "logs/{segment}/align.txt"
    benchmark:
        "benchmarks/{segment}/align.txt"
    shell:
        """
        if [[ "{wildcards.segment}" == "gpc" ]]; then
            # Use MAFFT for the GPC segment
            mafft --addfragments {input.sequences} --keeplength {input.reference} > {output.alignment} 2>&1 | tee {log}
        else
            # Use augur align for S and L segments
            augur align \
                --sequences {input.sequences} \
                --reference-sequence {input.reference} \
                --output {output.alignment} \
                --fill-gaps \
                --remove-reference \
                2>&1 | tee {log}
        fi
        """
