#!/bin/bash

mkdir -p fastq fastq_logs tmp

convert_one() {
    srr=$1

    fasterq-dump "sra/$srr/$srr.sra" \
        --split-files -e 8 -t tmp -O fastq \
        > "fastq_logs/$srr.log" 2>&1 &&
    pigz -p 8 fastq/"$srr"*.fastq \
        >> "fastq_logs/$srr.log" 2>&1
}

export -f convert_one

parallel -j 4 --retries 2 --joblog fasterq.joblog \
    convert_one {} :::: ../sralist/pn_list.txt
