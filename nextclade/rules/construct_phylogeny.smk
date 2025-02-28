"""
This part of the workflow constructs the reference tree for the Nextclade dataset

REQUIRED INPUTS:

    metadata            = data/metadata.tsv
    prepared_sequences  = results/prepared_sequences.fasta

OUTPUTS:

    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json

This part of the workflow usually includes the following steps:

    - augur tree
    - augur refine

See Augur's usage docs for these commands for more details.
"""

rule add_outgroup:
    """Add outgroup"""
    input:
        alignment = "data/sequences.fasta",
        outgroup = "../phylogenetic/defaults/gpc/outgroup.fasta",
    output:
        alignment_with_outgroup = "results/sequences_with_outgroup.fasta",
    log:
        "logs/add-outgroup.txt",
    benchmark:
        "benchmarks/add-outgroup.txt",
    shell:
        """
        augur align \
            --sequences {input.outgroup} \
            --existing-alignment {input.alignment} \
            --output {output.alignment_with_outgroup} \
            2>&1 | tee {log}
        """

rule tree:
    """Building tree"""
    input:
        alignment = "results/sequences_with_outgroup.fasta"
    output:
        tree = "results/tree_raw.nwk"
    log:
        "logs/tree.txt",
    benchmark:
        "benchmarks/tree.txt"
    params:
        method = "iqtree"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --method {params.method} \
            2>&1 | tee {log}
        """

rule refine:
    """
    Refining tree
      - estimate timetree
      - use {params.coalescent} coalescent timescale
      - estimate {params.date_inference} node dates
      - fix clock rate at {params.clock_rate}
    """
    input:
        tree = "results/tree_raw.nwk",
        alignment = "data/sequences.fasta",
        metadata = "data/metadata.tsv",
    output:
        tree = "results/tree.nwk",
        node_data = "results/branch_lengths.json"
    log:
        "logs/refine.txt",
    benchmark:
        "benchmarks/refine.txt"
    params:
        strain_id_field = config["strain_id_field"],
        coalescent = config['refine']['coalescent'],
        date_inference = config['refine']['date_inference'],
        clock_rate = config['refine']['clock_rate'],
        root = lambda wildcards: config['refine']['outgroup'],
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id_field} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --timetree \
            --coalescent {params.coalescent} \
            --clock-rate {params.clock_rate} \
            --date-confidence \
            --date-inference {params.date_inference} \
            --root {params.root} \
            --remove-outgroup \
            2>&1 | tee {log}
        """
