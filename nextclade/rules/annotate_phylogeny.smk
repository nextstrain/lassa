"""
This part of the workflow creates additonal annotations for the reference tree
of the Nextclade dataset.

REQUIRED INPUTS:

    metadata            = data/metadata.tsv
    prepared_sequences  = results/prepared_sequences.fasta
    tree                = results/tree.nwk

OUTPUTS:

    nt_muts     = results/nt_muts.json
    aa_muts     = results/aa_muts.json
    clades      = results/clades.json

This part of the workflow usually includes the following steps:

    - augur ancestral
    - augur translate
    - augur clades

See Augur's usage docs for these commands for more details.
"""


rule ancestral:
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/tree.nwk",
        alignment = "data/sequences.fasta",
    output:
        node_data = "results/nt_muts.json"
    log:
        "logs/ancestral.txt",
    benchmark:
        "benchmarks/ancestral.txt"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference} \
            2>&1 | tee {log}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/tree.nwk",
        node_data = "results/nt_muts.json",
        reference = "../phylogenetic/defaults/lassa_gpc.gb"
    output:
        node_data = "results/aa_muts.json"
    log:
        "logs/translate.txt",
    benchmark:
        "benchmarks/translate.txt"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output-node-data {output.node_data} \
            2>&1 | tee {log}
        """

rule traits:
    """Inferring ancestral traits for {params.columns!s}"""
    input:
        tree = "results/tree.nwk",
        metadata = "data/metadata.tsv",
    output:
        node_data = "results/traits.json",
    log:
        "logs/traits.txt",
    benchmark:
        "benchmarks/traits.txt"
    params:
        strain_id_field = config["strain_id_field"],
        columns = config['traits']['columns']
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --output-node-data {output.node_data} \
            --columns {params.columns} \
            --confidence \
            2>&1 | tee {log}
        """
