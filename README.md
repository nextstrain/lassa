# nextstrain.org/lassa

_Currently, this pathogen build is in draft state. Recent outputs are visible at [nextstrain.org/staging/lassa/l](https://nextstrain.org/staging/lassa/l) and [nextstrain.org/staging/lassa/s](https://nextstrain.org/staging/lassa/s), but it's not yet fully QCed or automated._

This repository contains two workflows for the analysis of Lassa virus data:

- [`ingest/`](./ingest) - Download data from GenBank, clean and curate it, separate into L and S segments, and upload it to S3
- [`phylogenetic/`](./phylogenetic) - Filter sequences, align, construct phylogeny and export for visualization

Each folder contains a README.md with more information.

## Installation

Follow the [standard installation instructions](https://docs.nextstrain.org/en/latest/install.html) for Nextstrain's suite of software tools.

## Quickstart

Run the default phylogenetic workflow via:
```
cd phylogenetic/
nextstrain build .
nextstrain view .
```

## Documentation

- [Running a pathogen workflow](https://docs.nextstrain.org/en/latest/tutorials/running-a-workflow.html)
- [Contributor documentation](./CONTRIBUTING.md)
