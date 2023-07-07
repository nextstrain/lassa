SEGMENTS = ["l", "s"]

rule all:
    input:
        auspice_tree = expand("auspice/lassa_{segment}_tree.json", segment=SEGMENTS),
        auspice_meta = expand("auspice/lassa_{segment}_meta.json", segment=SEGMENTS)

rule files:
    params:
        dropped_strains = "config/dropped_strains.txt",
        reference = "config/lassa_{segment}.gb",
        colors = "config/colors.tsv",
        auspice_config = "config/auspice_config.json"

files = rules.files.params

rule filter:
    """
    Filtering to
      - {params.sequences_per_group} sequence(s) per {params.group_by!s}
      - excluding strains in {input.exclude}
    """
    input:
        sequences = "data/sequences_{segment}.fasta",
        metadata = "data/metadata_{segment}.tsv",
        exclude = files.dropped_strains
    output:
        sequences = "results/filtered_{segment}.fasta"
    params:
        group_by = "country year",
        sequences_per_group = 2,
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --exclude {input.exclude} \
            --output {output.sequences} \
            --group-by {params.group_by} \
            --sequences-per-group {params.sequences_per_group}
        """

rule align:
    """
    Aligning sequences to {input.reference}
      - filling gaps with N
    """
    input:
        sequences = "results/filtered_{segment}.fasta",
        reference = files.reference
    output:
        alignment = "results/aligned_{segment}.fasta"
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --output {output.alignment} \
            --fill-gaps
        """

rule tree:
    """Building tree"""
    input:
        alignment = "results/aligned_{segment}.fasta"
    output:
        tree = "results/tree_raw_{segment}.nwk"
    params:
        method = "iqtree"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree} \
            --method {params.method}
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
        tree = "results/tree_raw_{segment}.nwk",
        alignment = "results/aligned_{segment}.fasta",
        metadata = "data/metadata_{segment}.tsv",
    output:
        tree = "results/tree_{segment}.nwk",
        node_data = "results/branch_lengths_{segment}.json"
    params:
        coalescent = "opt",
        date_inference = "marginal",
        clock_rate = 0.0006
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --timetree \
            --coalescent {params.coalescent} \
            --clock-rate {params.clock_rate} \
            --date-confidence \
            --date-inference {params.date_inference}
        """

rule ancestral:
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/tree_{segment}.nwk",
        alignment = "results/aligned_{segment}.fasta",
    output:
        node_data = "results/nt_muts_{segment}.json"
    params:
        inference = "joint"
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/tree_{segment}.nwk",
        node_data = "results/nt_muts_{segment}.json",
        reference = files.reference
    output:
        node_data = "results/aa_muts_{segment}.json"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output-node-data {output.node_data}
        """

rule traits:
    """Inferring ancestral traits for {params.columns!s}"""
    input:
        tree = "results/tree_{segment}.nwk",
        metadata = "data/metadata_{segment}.tsv",
    output:
        node_data = "results/traits_{segment}.json",
    params:
        columns = "country"
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --output-node-data {output.node_data} \
            --columns {params.columns} \
            --confidence
        """

rule export:
    """Exporting data files for for auspice"""
    input:
        tree = "results/tree_{segment}.nwk",
        metadata = "data/metadata_{segment}.tsv",
        branch_lengths = "results/branch_lengths_{segment}.json",
        traits = "results/traits_{segment}.json",
        nt_muts = "results/nt_muts_{segment}.json",
        aa_muts = "results/aa_muts_{segment}.json",
        colors = files.colors,
        auspice_config = files.auspice_config
    output:
        auspice_tree = "auspice/lassa_{segment}_tree.json",
        auspice_meta = "auspice/lassa_{segment}_meta.json"
    shell:
        """
        augur export v1 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.nt_muts} {input.aa_muts} \
            --colors {input.colors} \
            --auspice-config {input.auspice_config} \
            --output-tree {output.auspice_tree} \
            --output-meta {output.auspice_meta}
        """
