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
        metadata = "data/metadata.tsv",
    output:
        colors = "results/colors.tsv"
    log:
        "logs/colors.txt",
    benchmark:
        "benchmarks/colors.txt"
    shell:
        """
        python3 ../phylogenetic/scripts/assign-colors.py \
            --color-schemes {input.color_schemes} \
            --ordering {input.color_orderings} \
            --metadata {input.metadata} \
            --output {output.colors} \
            2>&1 | tee {log}
        """

rule export:
    """Exporting data files for for auspice"""
    input:
        tree = "results/tree.nwk",
        metadata = "data/metadata.tsv",
        branch_lengths = "results/branch_lengths.json",
        traits = "results/traits.json",
        nt_muts = "results/nt_muts.json",
        aa_muts = "results/aa_muts.json",
        colors = "results/colors.tsv",
        description = config['export']['description'],
        auspice_config = config['export']['auspice_config'],
    output:
        auspice = "results/lassa.json",
    log:
        "logs/export.txt",
    benchmark:
        "benchmarks/export.txt"
    params:
        strain_id_field = config["strain_id_field"],
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --node-data {input.branch_lengths} {input.traits} {input.nt_muts} {input.aa_muts} \
            --colors {input.colors} \
            --description {input.description} \
            --auspice-config {input.auspice_config} \
            --output {output.auspice} \
            --include-root-sequence-inline \
            2>&1 | tee {log}
        """

rule final_strain_name:
    input:
        auspice_json="results/lassa.json",
        metadata="data/metadata.tsv",
    output:
        auspice_json="auspice/tree.json",
    log:
        "logs/final_strain_name.txt",
    benchmark:
        "benchmarks/final_strain_name.txt"
    params:
        strain_id_field=config["strain_id_field"],
        display_strain_field=config["display_strain_field"],
    shell:
        """
        python3 ../phylogenetic/scripts/set_final_strain_name.py \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --input-auspice-json {input.auspice_json} \
            --display-strain-name {params.display_strain_field} \
            --output {output.auspice_json} \
            2>&1 | tee {log}
        """