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
        colors = config['export']['colors'],
        description = config['export']['description'],
        auspice_config = config['export']['auspice_config'],
    output:
        auspice = "auspice/lassa_{segment}.json",
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
            --include-root-sequence-inline
        """
