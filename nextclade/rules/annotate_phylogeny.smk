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
        reference_fasta = "defaults/reference_gpc.fasta",
    output:
        node_data = "results/nt_muts.json"
    log:
        "logs/ancestral.txt",
    benchmark:
        "benchmarks/ancestral.txt"
    params:
        inference = "joint"
    shell:
        r"""
        augur ancestral \
            --tree {input.tree:q} \
            --alignment {input.alignment:q} \
            --output-node-data {output.node_data:q} \
            --inference {params.inference:q} \
            --root-sequence {input.reference_fasta:q} \
            2>&1 | tee {log:q}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/tree.nwk",
        node_data = "results/nt_muts.json",
        reference = "../phylogenetic/defaults/gpc/reference.gb"
    output:
        node_data = "results/aa_muts.json"
    log:
        "logs/translate.txt",
    benchmark:
        "benchmarks/translate.txt"
    shell:
        r"""
        augur translate \
            --tree {input.tree:q} \
            --ancestral-sequences {input.node_data:q} \
            --reference-sequence {input.reference:q} \
            --output-node-data {output.node_data:q} \
            2>&1 | tee {log:q}
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
        r"""
        augur traits \
            --tree {input.tree:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.strain_id_field:q} \
            --output-node-data {output.node_data:q} \
            --columns {params.columns:q} \
            --confidence \
            2>&1 | tee {log:q}
        """
