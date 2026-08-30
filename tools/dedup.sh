picard MarkDuplicates \
        I=aligned_masked.sorted.bam \
        O=align_masked_dedup.bam \
        M=align_masked_metrics.txt \
        REMOVE_DUPLICATES=true \
        CREATE_INDEX=true \
        ASSUME_SORTED=true \
