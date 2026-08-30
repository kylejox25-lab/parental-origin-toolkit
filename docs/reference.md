# Tool reference

Run any tool with `-h/--help` for the full usage block.

## Prep (once per strain pair)

### pot-get-strain

```bash
pot-get-strain [--list] [--indels] [-o DIR] [-c config.yaml] STRAIN...
```

Downloads MGP v5 strain-specific VCFs (+ .tbi) with resume and gzip
verification. `--list` shows the 36 available strains. Reference aliases
(`BL6`, `C57BL_6J`, `GRCm38`, `mm10`, `reference`) are skipped.
Base URL: config `mgp.base_url`; output dir: `-o` or `mgp.cache_dir`.

### pot-build-dsnp

```bash
pot-build-dsnp -1 STRAIN_A -2 STRAIN_B [-o PREFIX] [--filter EXPR]
               [--min-qual Q] [--min-dp D] [-c config.yaml]
```

Builds the discriminating SNP set. One of the strains may be a reference
alias. Outputs `<PREFIX>.vcf.gz` (SNPsplit prep input), `.origin.tsv.gz`,
`.dsnp.bed.gz` (pot-qc input), `.meta.txt`.

### pot-build-masked

```bash
pot-build-masked [-v VCF] [--reference-genome DIR] [-o DIR]
                 [--no-index] [-t N] [-c config.yaml]
```

Wraps `SNPsplit_genome_preparation` (auto `--strain` / `--dual_hybrid`),
concatenates the N-masked genome, indexes it (`samtools faidx`), builds a
bowtie2 index, and reports the `all_SNPs_*.txt.gz` snp_file path.
Update `config.yaml` (`dsnp.snp_file`, `genomes.masked`,
`genomes.bowtie2_index`) afterwards.

## Alignment

### pot-align

```bash
pot-align -1 R1.fq.gz -2 R2.fq.gz -s SAMPLE [--aligner bowtie2|hisat2|star]
          [--index PATH] [--params "..."] [-t N] [-o DIR] [-c config.yaml]
pot-align -U READS.fq.gz -s SAMPLE ...        # single-end
```

Outputs `<DIR>/<SAMPLE>.sorted.bam` (+ .bai).

### pot-dedup

```bash
pot-dedup -b IN.bam [-o OUT.bam] [-m METRICS] [--keep-dups]
          [--java-opts "-Xmx8g"] [-c config.yaml]
```

Picard MarkDuplicates on coordinate-sorted BAM (duplicates removed by
default).

## Splitting

### pot-split

```bash
pot-split -b IN.bam -s SAMPLE_ID [--snp-file FILE] [--single]
          [--conflicting|--no-conflicting] [--sort] [-o DIR] [-c config.yaml]
```

Runs SNPsplit; outputs `*.genome1.bam`, `*.genome2.bam`,
`*.conflicting.bam`, `split_stats.tsv`, `snpsplit.log`, and
`<SAMPLE>.maternal.bam` / `paternal.bam` symlinks from the samples.tsv
mapping. Default output dir: `config defaults.split_dir/<SAMPLE_ID>`.

## Quantification

### pot-count

```bash
pot-count -s SAMPLE_ID [--split-dir DIR] [--regions BED | -w SIZE]
          [--labels A B] [-o FILE] [-c config.yaml]
pot-count -1 G1.bam -2 G2.bam ...             # direct BAMs
```

bedtools multicov per region/window: `chr start end name <g1> <g2> total`.
Pipes into `pot-test`.

### pot-ase

```bash
pot-ase -s SAMPLE_ID [--split-dir DIR] [--gtf FILE] [--paired]
        [--stranded 0|1|2] [--feature-type exon] [--attr-type gene_id]
        [-t N] [-o FILE] [-c config.yaml]
```

Gene-level allele-specific expression: featureCounts on the split BAMs,
then two-sided binomial test + BH FDR per gene.
Columns: `gene_id length <g1> <g2> total <g1>_ratio p_value q_value`
(`<g1>/<g2>` are the strain names from samples.tsv).

### pot-split-bw

```bash
pot-split-bw -s SAMPLE_ID [--split-dir DIR] [--bs 50]
             [--no-cpm | --scale F] [-o DIR] [-c config.yaml]
```

CPM-scaled bigWigs (`genome1.bw`, `genome2.bw`, plus `maternal.bw` /
`paternal.bw` symlinks). Scale factors logged in `scale_factors.txt`.
Default output dir: `bigwig/<SAMPLE_ID>`.

## Statistics

### pot-test

```bash
pot-test -i FILE [--col1 NAME --col2 NAME] [--expected P] [-o FILE]
```

Appends `p_value` and `q_value` (BH FDR) to any two-column count TSV.

## QC

### pot-qc

```bash
pot-qc -s SAMPLE_ID [--split-dir DIR] [--dsnp-bed FILE]
       [--per-site FILE] [-o FILE] [-c config.yaml]
```

One-row summary: SNPsplit assignment rates (from `split_stats.tsv`) +
dSNP site coverage (sites covered, exclusive/shared, read counts) from
`bedtools multicov` on the dSNP BED.
