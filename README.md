# parental-origin-toolkit

A reproducible bioinformatics toolkit for identifying and analyzing
parental-origin signals from high-throughput sequencing data (mouse F1 hybrids,
RNA-seq / ChIP-seq / ATAC-seq).

## Design

- `tools/` — one single-purpose, independently runnable script per task
  (`pot-*`). Every tool reads the same `config.yaml` and prints logs to
  stderr / data to stdout, so they compose with pipes and shell scripts.
- `pipelines/` — example bash/python scripts that chain the tools into batch
  runs driven by `samples.tsv`.
- **One-time preparation** per strain pair (masked genome + dSNP set) is
  deliberately NOT part of the per-sample pipeline: run it once, reuse for
  every sample of that cross.

Read [docs/design.md](docs/design.md) for conventions and gotchas
(genome1/2 vs maternal/paternal, reciprocal crosses, dSNP logic), and
[docs/reference.md](docs/reference.md) for per-tool usage.

## Install

```bash
conda env create -f environment.yml
conda activate parental_toolkit
```

The old hardcoded scripts of the first release are kept in `legacy/`.

## Quickstart

1. Copy and edit the configuration:

   ```bash
   cp config.example.yaml config.yaml     # set local paths
   cp samples.example.tsv samples.tsv     # one row per sample
   ```

2. One-time preparation for a strain pair (e.g. BL6 x PWK_PhJ):

   ```bash
   pipelines/prepare.sh PWK_PhJ BL6 -c config.yaml
   ```

   This downloads the MGP v5 strain VCF, builds the dSNP set and the
   N-masked genome + bowtie2 index. Update `config.yaml` (`dsnp.*`,
   `genomes.masked`, `genomes.bowtie2_index`, `dsnp.snp_file`) with the
   printed paths.

3. Per-sample analysis (align manually with `pot-align`, or use existing
   masked-genome BAMs):

   ```bash
   pipelines/run_pipeline.sh -c config.yaml
   # or, with parallelism:  python pipelines/run_pipeline.py --parallel 4
   ```

   Per sample this runs: `pot-split` -> `pot-qc` -> `pot-split-bw`
   (ChIP/ATAC tracks) -> `pot-ase` (RNA-seq, gene-level).

## Tool overview

| Stage | Tool | Function |
|---|---|---|
| Prep (once per strain pair) | `pot-get-strain` | download MGP v5 strain VCFs (resume, verify, `--list`) |
| | `pot-build-dsnp` | strain pair -> dSNP VCF + origin TSV + BED |
| | `pot-build-masked` | SNPsplit genome preparation + bowtie2 index |
| Alignment | `pot-align` | bowtie2 / hisat2 / STAR wrapper |
| | `pot-dedup` | picard MarkDuplicates wrapper |
| Splitting | `pot-split` | SNPsplit wrapper + assignment stats + parental labels |
| Quantification | `pot-count` | region/window genome1/2 counts (bedtools multicov) |
| | `pot-ase` | gene-level ASE (featureCounts + binomial test) |
| | `pot-split-bw` | parent-specific CPM bigWigs |
| Statistics | `pot-test` | binomial test + BH FDR on a count TSV |
| QC | `pot-qc` | split rates + dSNP site coverage |

## Gotchas

- SNPsplit's `genome1/genome2` follow the dSNP VCF sample order, **not**
  biology. Reciprocal crosses flip the parental direction per sample —
  `samples.tsv` maps `genome1/genome2` -> strains -> `maternal/paternal`
  per sample.
- `BL6`/`C57BL_6J`/`GRCm38`/`mm10`/`reference` are reference-genome aliases
  in prep tools (no MGP VCF needed for the reference parent).
- The masked genome + dSNP set are **per strain pair**. A different cross
  needs its own `prepare.sh` run and config entries.

## Roadmap

- WGBS/EM-seq support (allele-specific methylation, ASM)
- SNP-level ASE (per-dSNP-site counts)
- Indel-based dSNPs
- testdata + CI smoke tests
