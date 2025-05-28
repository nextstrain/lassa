"""
This part of the workflow collects the phylogenetic tree and annotations to
export a reference tree and create the Nextclade dataset.

REQUIRED INPUTS:

    augur export:
        metadata            = data/metadata.tsv
        tree                = results/tree.nwk
        branch_lengths      = results/branch_lengths.json
        nt_muts             = results/nt_muts.json
        aa_muts             = results/aa_muts.json
        clades              = results/clades.json

    Nextclade dataset files:
        reference           = ../shared/reference.fasta
        pathogen            = config/pathogen.json
        genome_annotation   = config/genome_annotation.gff3
        readme              = config/README.md
        changelog           = config/CHANGELOG.md
        example_sequences   = config/sequence.fasta

OUTPUTS:

    nextclade_dataset = datasets/${build_name}/*

    See Nextclade docs on expected naming conventions of dataset files
    https://docs.nextstrain.org/projects/nextclade/page/user/datasets.html

This part of the workflow usually includes the following steps:

    - augur export v2
    - cp Nextclade datasets files to new datasets directory

See Augur's usage docs for these commands for more details.
"""

rule colors:
    input:
        color_schemes = "../phylogenetic/defaults/color_schemes.tsv",
        color_orderings = "../phylogenetic/defaults/color_orderings.tsv",
        metadata = "data/{segment}/metadata_merged.tsv",
    output:
        colors = "results/{segment}/colors.tsv"
    log:
        "logs/{segment}/colors.txt",
    benchmark:
        "benchmarks/{segment}/colors.txt"
    shell:
        r"""
        python3 ../phylogenetic/scripts/assign-colors.py \
            --color-schemes {input.color_schemes:q} \
            --ordering {input.color_orderings:q} \
            --metadata {input.metadata:q} \
            --output {output.colors:q} \
            2>&1 | tee {log:q}
        """

rule export:
    """Exporting data files for for auspice"""
    input:
        tree = "results/{segment}/tree.nwk",
        metadata = "data/{segment}/metadata_merged.tsv",
        branch_lengths = "results/{segment}/branch_lengths.json",
        traits = "results/{segment}/traits.json",
        nt_muts = "results/{segment}/nt_muts.json",
        aa_muts = "results/{segment}/aa_muts.json",
        colors = "results/{segment}/colors.tsv",
        description = config['export']['description'],
        auspice_config = config['export']['auspice_config'],
    output:
        auspice = "auspice/tree_{segment}.json",
    log:
        "logs/{segment}/export.txt",
    benchmark:
        "benchmarks/{segment}/export.txt"
    params:
        strain_id_field = config["strain_id_field"],
    shell:
        r"""
        augur export v2 \
            --tree {input.tree:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.strain_id_field:q} \
            --node-data {input.branch_lengths:q} {input.traits:q} {input.nt_muts:q} {input.aa_muts:q} \
            --colors {input.colors:q} \
            --description {input.description:q} \
            --auspice-config {input.auspice_config:q} \
            --output {output.auspice:q} \
            --include-root-sequence-inline \
            2>&1 | tee {log:q}
        """
