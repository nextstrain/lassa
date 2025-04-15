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
        tree="auspice/tree.json",
        reference="defaults/reference_gpc.fasta",
        annotation="defaults/reference_gpc.gff3",
        sequences="defaults/example_sequences.fasta",
        pathogen="defaults/pathogen.json",
        readme="defaults/README.md",
        changelog="defaults/CHANGELOG.md",
    output:
        tree="dataset/tree.json",
        reference="dataset/reference.fasta",
        annotation="dataset/genome_annotation.gff3",
        sequences="dataset/sequences.fasta",
        pathogen="dataset/pathogen.json",
        readme="dataset/README.md",
        changelog="dataset/CHANGELOG.md",
        dataset_zip="dataset.zip",
    shell:
        r"""
        cp {input.tree:q} {output.tree:q}
        cp {input.reference:q} {output.reference:q}
        cp {input.annotation:q} {output.annotation:q}
        cp {input.sequences:q} {output.sequences:q}
        cp {input.pathogen:q} {output.pathogen:q}
        cp {input.readme:q} {output.readme:q}
        cp {input.changelog:q} {output.changelog:q}
        zip -rj dataset.zip  dataset/*
        """

rule test:
    input:
        dataset="dataset.zip",
        sequences="defaults/example_sequences.fasta",
    output:
        output=directory("test_out"),
    shell:
        r"""
        nextclade3 run \
            --input-dataset {input.dataset:q} \
            --output-all {output.output:q} \
            {input.sequences:q}
        """
