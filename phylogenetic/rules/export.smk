"""
This part of the workflow collects the phylogenetic tree and annotations to
export a Nextstrain dataset.

REQUIRED INPUTS:

    metadata        = data/metadata.tsv
    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json
    node_data       = results/*.json

OUTPUTS:

    auspice_json = auspice/${build_name}.json

    There are optional sidecar JSON files that can be exported as part of the dataset.
    See Nextstrain's data format docs for more details on sidecar files:
    https://docs.nextstrain.org/page/reference/data-formats.html

This part of the workflow usually includes the following steps:

    - augur export v2
    - augur frequencies

See Augur's usage docs for these commands for more details.
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