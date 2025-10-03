"""
This part of the workflow organizes the files for a Nextstrain dataset.

REQUIRED INPUTS:

    tree            = auspice/tree.nwk
    reference_files = reference.fasta, reference.gff3
    pathogen_json   = defaults/pathogen.json
    doc_files       = defaults/README.md, defaults/CHANGELOG.md
    example query   = defaults/example_sequences.fasta

OUTPUTS:

    dataset_zip     = dataset.zip
    test_output     = results of testing the example query against the Nextclade dataset

This part of the workflow usually includes the following steps:

    - zipping the final Nextclade dataset
    - running a test of the final Nextclade dataset

See the Nextclade documentation for more information:

    - https://github.com/nextstrain/nextclade_data/blob/master/docs/dataset-creation-guide.md
    - https://github.com/nextstrain/nextclade_data/blob/master/docs/dataset-curation-guide.md

"""

rule assemble_dataset:
    input:
        tree="auspice/tree_{segment}.json",
        reference="defaults/{segment}/reference.fasta",
        annotation="defaults/{segment}/reference.gff",
        sequences="defaults/{segment}/sequences.fasta",
        pathogen="defaults/{segment}/pathogen.json",
        readme="defaults/{segment}/README.md",
        changelog="defaults/CHANGELOG.md",
    output:
        tree="dataset/{segment}/tree.json",
        reference="dataset/{segment}/reference.fasta",
        annotation="dataset/{segment}/genome_annotation.gff3",
        sequences="dataset/{segment}/sequences.fasta",
        pathogen="dataset/{segment}/pathogen.json",
        readme="dataset/{segment}/README.md",
        changelog="dataset/{segment}/CHANGELOG.md",
    shell:
        r"""
        cp {input.tree:q} {output.tree:q}
        cp {input.reference:q} {output.reference:q}
        cp {input.annotation:q} {output.annotation:q}
        cp {input.sequences:q} {output.sequences:q}
        cp {input.pathogen:q} {output.pathogen:q}
        cp {input.readme:q} {output.readme:q}
        cp {input.changelog:q} {output.changelog:q}
        """

rule test:
    input:
        dataset="dataset.zip",
        sequences="defaults/{segment}/example_sequences.fasta",
    output:
        output=directory("test_out/{segment}/"),
    shell:
        r"""
        nextclade3 run \
            --input-dataset {input.dataset:q} \
            --output-all {output.output:q} \
            {input.sequences:q}
        """
