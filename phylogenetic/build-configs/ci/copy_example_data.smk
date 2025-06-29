rule copy_example_data:
    input:
        sequences="example_data/sequences_{segment}.fasta",
        metadata="example_data/metadata_{segment}.tsv",
    output:
        sequences="data/{segment}/sequences.fasta",
        metadata="data/{segment}/metadata.tsv",
    shell:
        r"""
        cp -f {input.sequences:q} {output.sequences:q}
        cp -f {input.metadata:q} {output.metadata:q}
        """

# Add a Snakemake ruleorder directive here if you need to resolve ambiguous rules
# that have the same output as the copy_example_data rule.

ruleorder: copy_example_data > decompress