[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## SamnTrek

`SamnTrek` enables rapid integration of NCBI Pathogen Detection (NPD) data to place local *Salmonella* strains in a global context. Specifically, given any *Salmonella* genomes, `SamnTrek` identifies closely matching strains in NPD and constructs a phylogeny to contextualize the (local) query sequences with close matching (global) hits. The sequence similarity search algorithm has been optimized extensively, rendering it possible to search through >400,000 *Salmonella* genomes in minutes using minimal resources.

![workflow](https://github.com/jimmyliu1326/SamnTrek/blob/main/assets/SamnTrek_Flowchart.png?raw=true)

## Quick start

This section is dedicated to those who cannot be bothered with the fine details and are simply seeking to get the pipeline up and running asap.

### Minimal prerequisites

- One of the supported containerization platforms installed: `Singularity` or `Docker`
- `Nextflow` >= v23.0.0
- `Git`
- Internet connection

Once all the prerequisites have been installed, run the following command in the terminal to verify all dependencies have been set up correctly:

```bash
nextflow run jimmyliu1326/SamnTrek \
   -r [version] --help
```

> Note: Replace `[version]` with the latest release tag, which can be found [here](https://github.com/jimmyliu1326/SamnTrek/releases)

If successful, the complete pipeline help message will be printed to screen.

### Configuring the input samplesheet
The input sequence data must be formatted as a `.csv` file containing two columns: `sample` and `genome`

- The `sample` column contains unique identifiers to each query genome i.e. sample ID
- The `genome` column contains the path to each query genome
- The sample sheet must contain column headers `sample` and `genome`

Example samplesheet:

```
sample,genome
Sample_A,/path/to/Sample_A.fasta
Sample_B,/path/to/Sample_B.fasta
```

### Downloading the database
Precomputed NPD database can be downloaded by running the following command:

```
nextflow run jimmyliu1326/SamnTrek \
   -r [version] \
   -profile <docker/singularity> \
   --wf download_db \
   --download_path /path/to/SamnTrek_db
```

- `-profile` indicates which containerization platform to use for process execution i.e. Docker or Singularity
- `--wf download_db` signals the pipeline to only download the database
- `--download_path` specifies where to save the downloaded database files

With all of the above steps completed, the full pipeline can be executed by specifying `--wf all` 

```
nextflow run jimmyliu1326/SamnTrek \
   -r [version] \
   -profile <docker/singularity> \
   --wf all \
   --input samplesheet.csv \
   --outdir /path/to/results
   --db /path/to/SamnTrek_db
```

- `--input` specifies the path to input samplesheet
- `--outdir` specifies the path to save the output results
- `--db` specifies the path to the directory containing predownloaded database files

## Credits

`SamnTrek` was originally written by Jimmy Liu.

<!-- We thank the following people for their extensive assistance in the development of this pipeline: -->

<!-- ## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md). -->

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf/samntrek for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

<!--An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file. -->

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
