# CHANGELOG

We use this CHANGELOG to document breaking changes, new features, bug fixes,
and config value changes that may affect both the usage of the workflows and
the outputs of the workflows.

## 2026

* 13 October 2026: phylogenetic - support use of cached remote inputs [PR #89](https://github.com/nextstrain/lassa/pull/89) @joverlee521
    * See https://github.com/nextstrain/shared/pull/87 for more details.

## 2025

* 17 October 2025: phylogenetic and nextclade - Major update to the definition of inputs. ([#77][])
  * Switch to use shared/vendor scripts in workflows where possible

The configuration has been updated from top level keys:

```yaml
sequences_url: "https://data.nextstrain.org/files/workflows/lassa/{segment}/sequences.fasta.zst"
metadata_url: "https://data.nextstrain.org/files/workflows/lassa/{segment}/metadata.tsv.zst"
```

to named dictionary key of multiple inputs in phylogenetic:

```yaml
inputs:
  - name: ncbi
    sequences: "https://data.nextstrain.org/files/workflows/lassa/{segment}/sequences.fasta.zst"
    metadata: "https://data.nextstrain.org/files/workflows/lassa/{segment}/metadata.tsv.zst"
```

and to named dictionary key of multiple inputs in nextclade:

```yaml
inputs:
  - name: ncbi
    sequences: "https://data.nextstrain.org/files/workflows/lassa/all/sequences.fasta.zst"
    metadata: "https://data.nextstrain.org/files/workflows/lassa/all/metadata.tsv.zst"
```

[#77]: https://github.com/nextstrain/lassa/pull/77
