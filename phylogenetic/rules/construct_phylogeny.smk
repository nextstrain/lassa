"""
This part of the workflow constructs the phylogenetic tree.

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
        alignment = "results/{segment}/aligned.fasta"
    output:
        tree = "results/{segment}/tree_raw.nwk"
    log:
        "logs/{segment}/tree.txt",
    benchmark:
        "benchmarks/{segment}/tree.txt"
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
        tree = "results/{segment}/tree_raw.nwk",
        alignment = "results/{segment}/aligned.fasta",
        metadata = "data/{segment}/metadata.tsv",
    output:
        tree = "results/{segment}/tree.nwk",
        node_data = "results/{segment}/branch_lengths.json"
    log:
        "logs/{segment}/refine.txt",
    benchmark:
        "benchmarks/{segment}/refine.txt"
    params:
        strain_id_field = config["strain_id_field"],
        coalescent = config['refine']['coalescent'],
        date_inference = config['refine']['date_inference'],
        literature_clock_rate = config['refine']['literature_clock_rate'],
        root = lambda wildcards: config['refine']['root'][wildcards.segment],
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
            --date-confidence \
            --date-inference {params.date_inference:q} \
            --root {params.root:q} \
            --clock-rate {params.literature_clock_rate:q} \
            2>&1 | tee {log:q}
        """
