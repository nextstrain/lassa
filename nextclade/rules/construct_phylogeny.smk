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

rule tree:
    """Building tree"""
    input:
        alignment = "data/sequences.fasta"
    output:
        tree = "results/tree_raw.nwk"
    log:
        "logs/tree.txt",
    benchmark:
        "benchmarks/tree.txt"
    params:
        method = "iqtree"
    shell:
        r"""
        augur tree \
            --alignment {input.alignment:q} \
            --output {output.tree:q} \
            --method {params.method:q} \
            2>&1 | tee {log:q}
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
        root = lambda wildcards: config['refine']['root'],
    shell:
        r"""
        augur refine \
            --tree {input.tree:q} \
            --alignment {input.alignment:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.strain_id_field:q} \
            --output-tree {output.tree:q} \
            --output-node-data {output.node_data:q} \
            --timetree \
            --coalescent {params.coalescent:q} \
            --clock-rate {params.clock_rate:q} \
            --date-confidence \
            --date-inference {params.date_inference:q} \
            --root {params.root:q} \
            2>&1 | tee {log:q}
        """
