# Design

## Conventions

- Every tool is one executable script in `tools/`, named `pot-<task>`.
- Common CLI contract:
  - `-c/--config FILE` (default `config.yaml`; env var `POT_CONFIG`
    overrides the default)
  - `-h/--help` prints the usage block from the script header
  - logs go to stderr, data goes to stdout — tools compose with pipes
  - non-zero exit codes on failure; bash tools run with `set -euo pipefail`
- Config keys are dotted paths resolved from `config.yaml` via
  `tools/lib/pot_config.py`; bash tools use the `potcfg` helper from
  `tools/lib/pot-common.sh`.
- Batch runs are driven by `samples.tsv` (header row required):
  `sample_id, bam, genome1, genome2, maternal, paternal`.

## Why masked genome + dSNP are outside the pipeline

The masked reference genome and the dSNP set depend only on the **strain
pair**, not on the samples. Building them requires large downloads and
long-running steps, and they are reused by every sample of a cross
(including reciprocal crosses). They are therefore one-time prep tools
(`pot-get-strain`, `pot-build-dsnp`, `pot-build-masked`), chained by
`pipelines/prepare.sh`, and excluded from `run_pipeline.*`.

## dSNP construction

Source: Sanger Mouse Genomes Project v5 per-strain VCFs
(`<STRAIN>.mgp.v5.snps.dbSNP142.vcf.gz` under
`current_snps/strain_specific_vcfs/`; JAX mirror:
`ftp://ftp.jax.org/SNPtools/variants/`). Each VCF records a strain's
variants against the GRCm38 (C57BL/6) reference.

- **reference x strain** (e.g. BL6 x PWK_PhJ): dSNPs = the strain VCF's
  hom-ALT sites. The reference parent is 0/0 everywhere by definition.
- **strain x strain** (neither is the reference): A-specific =
  A hom-ALT and B hom-REF; B-specific symmetric. The two sets are merged
  into one two-sample VCF (`bcftools merge -0` fills the absent sample
  with 0/0), which is exactly what `SNPsplit_genome_preparation
  --dual_hybrid` expects.

Default site filter: `GT="1/1" && QUAL>=30 && FMT/DP>=10`
(config `defaults.dsnp_filter`).

## Masked genome

`pot-build-masked` wraps `SNPsplit_genome_preparation` and detects the
mode from the dSNP VCF: single sample -> `--strain`, two samples ->
`--dual_hybrid`. Output paths (N-masked fasta dir, `all_SNPs_*.txt.gz`
snp_file) are located by pattern, not hardcoded, so minor SNPsplit layout
changes do not break the tool. The masked fasta is concatenated into
`masked.fa`, indexed with `samtools faidx`, and a bowtie2 index is built.

## genome1/genome2 vs maternal/paternal

SNPsplit assigns reads by the dSNP VCF: reads matching the **first sample
column's** ALT allele go to `genome1`. This is a property of the VCF, not
of biology — in a reciprocal cross the maternal strain flips between
samples while `genome1` stays the same strain. Therefore:

- `samples.tsv` records per sample which strain is `genome1`/`genome2`
  and which strain is `maternal`/`paternal`;
- `pot-split` writes `maternal.bam`/`paternal.bam` symlinks from that
  mapping; downstream tools report counts by strain name.

For the common reference-x-strain setup (VCF from `--strain` mode),
`genome1` = the non-reference strain.

## Multi-aligner support

`pot-align` wraps bowtie2 (default; DNA/ChIP/ATAC, configurable params,
default `-N 1 -L 25`), hisat2 and STAR (spliced RNA-seq). Indexes come
from per-aligner config keys (`genomes.bowtie2_index` etc.).

## Statistics

`pot-ase` (gene level) and `pot-test` (any two-column count TSV) apply a
two-sided binomial test (exact for n <= 2000, normal approximation above)
and Benjamini-Hochberg FDR — implemented in `tools/lib/pot_stats.py`
without scipy.

## Environment

`environment.yml` lists only top-level dependencies. For users in China,
the Tsinghua bioconda mirror can be prepended to `channels`:

```yaml
channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge
```

## Roadmap

- WGBS/EM-seq: allele-specific methylation (ASM) per dSNP site/window
- SNP-level ASE
- Indel dSNPs (MGP v5 indel VCFs already downloadable with `--indels`)
- testdata + CI smoke tests
