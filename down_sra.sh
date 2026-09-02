#!/bin/bash

mkdir -p sra logs

parallel -j 16 \
    --retries 3 \
    --joblog pn_sra_download.joblog \
    'prefetch --max-size 100G --output-directory ./sra {} > logs/{}.log 2>&1' \
    :::: pn_list.txt
