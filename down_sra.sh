#!/bin/bash

mkdir -p sra logs

download_one() {
    srr="$1"
    sra_file="sra/$srr/$srr.sra"

    # 已经存在则验证
    if [ -f "$sra_file" ]; then
        if vdb-validate "$sra_file" >/dev/null 2>&1; then
            echo "[SKIP] $srr already downloaded and valid"
            return 0
        else
            echo "[INVALID] $srr, downloading again"
            rm -rf "sra/$srr"
        fi
    fi

    echo "[DOWNLOAD] $srr"

    prefetch \
        --max-size 100G \
        --output-directory ./sra \
        "$srr" \
        > "logs/${srr}.log" 2>&1
}

export -f download_one

parallel -j 4 \
    --retries 3 \
    --joblog sra_download.joblog \
    download_one {} \
    :::: ../sralist/list.txt
