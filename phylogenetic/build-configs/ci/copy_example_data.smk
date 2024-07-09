rule copy_example_data:
    input:
        sequences="example_data/sequences_{segment}.fasta",
        metadata="example_data/metadata_{segment}.tsv",
    output:
        sequences="data/sequences_{segment}.fasta",
        metadata="data/metadata_{segment}.tsv",
    shell:
        """
        cp -f {input.sequences} {output.sequences}
        cp -f {input.metadata} {output.metadata}
        """

# Add a Snakemake ruleorder directive here if you need to resolve ambiguous rules
# that have the same output as the copy_example_data rule.

# ruleorder: copy_example_data > ...
