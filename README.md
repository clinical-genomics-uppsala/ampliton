# ampliton

## Introduction

**ampliton** is a bioinformatics pipeline for nanopore amplicons, with a focus on epidemiological typing.
The pipeline is under development and currently performs the following:
1. Removal of adapters sequences with [`Porechop_ABI`](https://github.com/bonsai-team/Porechop_ABI)
2. Length and quality filtering with [`nanoq`](https://github.com/esteinig/nanoq)
3. Removal of primers and splitting of targets with [`cutadapt`](https://cutadapt.readthedocs.io/)
4. Multi-locus sequence typing with [`krocus`](https://github.com/andrewjpage/krocus)
5. Generation of amplicon sequence variants (ASVs) with [`savont`](https://github.com/bluenote-1577/savont)
6. Spa-typing of ASVs with [`spaTyper`](https://github.com/HCGB-IGTP/spaTyper) for *Staphylococcus aureus*
7. Present QC with [`MultiQC`](http://multiqc.info/)

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/get_started/environment_setup/overview) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/get_started/run-your-first-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1
SAMPLE_NAME,sample.fastq.gz
```

Each row represents a fastq file (single-end).

You also need a target sheet describing the amplicons and what analysis to be performed:

`targets.csv`:

```csv
target,FW_primer,RV_primer,min_length,max_length,analysis
arcC,TTGATTCACCAGCGCGTATTGTC,CGCTGATTGAAGCAGATACCT,,,MLST
...
...
SPA,AGACGATCCTTCGGTGAGC,CAGTAAATGACATTGCAAAAGC,200,700,SPA
```
For each amplicon, indicate the name, the primer sequences and the type of analysis.
The forward primer sequence should be given in 5'-3' direction and the reverse primer sequence should be given as the reverse complementary.
For ASV, and SPA analysis the minimum and maximum amplicon length is required.
All samples will be analysed for the same set of targets.

| Analysis | Description | Status |
| -------- | ----------- | ------ |
| MLST | runs krocus on MLST reads | draft |
| ASV | generates amplicon sequence variants with savont from any amplicon | draft |
| SPA | runs spaTyper on spa asvs | draft |
| COUNT | output the number of reads from any amplicon | planned |


To analyse MLST, download the [PubMLST database](https://pubmlst.org) for the species of interest, and run the pipeline with:

```bash
nextflow run main.nf \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --targets targets.csv \
   --krocus_scheme path/to/mlst/database/ \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

## Credits

ampliton was originally written by Ida Karlsson.


## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](docs/CONTRIBUTING.md).


## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
