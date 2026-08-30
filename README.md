# parental-origin-toolkit
A reproducible bioinformatics toolkit for identifying and analyzing parental-origin signals from high-throughput sequencing data.
## install step by step
```
conda create -n parental_toolkit
conda activate parental_toolkit
conda install -c conda-forge -c bioconda \
    bcftools \
    snpsplit \
    bowtie2 \
    samtools \
    picard
```
