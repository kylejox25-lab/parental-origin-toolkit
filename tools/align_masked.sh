bowtie2 \
    -x GRCm38_masked_idx \
    -1 ./trimmed_results/SRR4014452_1_val_1.fq.gz \
    -2 ./trimmed_results/SRR4014452_2_val_2.fq.gz \
    -N 1 \
    -L 25 \
    -p 28 \
    -S aligned_masked.sam \
    2> bowtie2_stats.txt

samtools view -bS aligned_masked.sam | samtools sort -@ 28 -o aligned_masked.sorted.bam
samtools index aligned_masked.sorted.bam
