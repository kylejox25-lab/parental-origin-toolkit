#!/bin/bash
set -euo pipefail

cd "${1:-.}"

JOBS=4
FASTP_THREADS=8
FASTQC_THREADS=2

for cmd in fastp fastqc multiqc parallel gzip; do
    command -v "$cmd" >/dev/null || { echo "Missing program: $cmd" >&2; exit 1; }
done

qc_one() {
    set -e
    r1=$1
    dataset=${r1%%/fastq/*}
    group=$(basename "$(dirname "$r1")")
    sample=$(basename "$r1" .fastq.gz)
    r2=""

    case "$sample" in
        *_R1_001) r2=${r1/_R1_001/_R2_001}; sample=${sample%_R1_001} ;;
        *_R1)     r2=${r1/_R1/_R2};         sample=${sample%_R1} ;;
        *_1)      r2=${r1%_1.fastq.gz}_2.fastq.gz; sample=${sample%_1} ;;
    esac

    case "${group,,}" in
        *_rnaseq)                 min_len=20 ;;
        *_h3k4me3|*_h3k27me3)    min_len=25 ;;
        *) echo "Unknown assay directory: $group" >&2; return 1 ;;
    esac

    out=$dataset/qc

    mkdir -p \
        "$out/clean_fastq/$group" \
        "$out/fastp/$group" \
        "$out/fastqc_raw/$group" \
        "$out/fastqc_clean/$group" \
        "$out/logs/$group"

    if [[ -n $r2 ]]; then
        [[ -f $r2 ]] || { echo "Missing mate: $r2" >&2; return 1; }
        clean1=$out/clean_fastq/$group/${sample}_R1.clean.fastq.gz
        clean2=$out/clean_fastq/$group/${sample}_R2.clean.fastq.gz

        gzip -t "$r1" "$r2"
        fastqc -t "$FASTQC_THREADS" -o "$out/fastqc_raw/$group" "$r1" "$r2" \
            > "$out/logs/$group/${sample}.raw_fastqc.log" 2>&1
        fastp -i "$r1" -I "$r2" -o "$clean1" -O "$clean2" \
            --detect_adapter_for_pe \
            -q 20 -u 40 -n 5 -l "$min_len" \
            --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 \
            -w "$FASTP_THREADS" \
            -h "$out/fastp/$group/${sample}.html" \
            -j "$out/fastp/$group/${sample}.json" \
            > "$out/logs/$group/${sample}.fastp.log" 2>&1
        fastqc -t "$FASTQC_THREADS" -o "$out/fastqc_clean/$group" "$clean1" "$clean2" \
            > "$out/logs/$group/${sample}.clean_fastqc.log" 2>&1
    else
        clean=$out/clean_fastq/$group/${sample}.clean.fastq.gz

        gzip -t "$r1"
        fastqc -t "$FASTQC_THREADS" -o "$out/fastqc_raw/$group" "$r1" \
            > "$out/logs/$group/${sample}.raw_fastqc.log" 2>&1
        fastp -i "$r1" -o "$clean" \
            -q 20 -u 40 -n 5 -l "$min_len" \
            --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 \
            -w "$FASTP_THREADS" \
            -h "$out/fastp/$group/${sample}.html" \
            -j "$out/fastp/$group/${sample}.json" \
            > "$out/logs/$group/${sample}.fastp.log" 2>&1
        fastqc -t "$FASTQC_THREADS" -o "$out/fastqc_clean/$group" "$clean" \
            > "$out/logs/$group/${sample}.clean_fastqc.log" 2>&1
    fi

    echo "done: $dataset/$group/$sample"
}

export -f qc_one
export FASTP_THREADS FASTQC_THREADS

roots=()
for dataset in pn k4 k27; do
    [[ -d $dataset/fastq ]] && roots+=("$dataset/fastq")
done
(( ${#roots[@]} )) || { echo "No pn/k4/k27 fastq directory found" >&2; exit 1; }

find "${roots[@]}" -type f -name '*.fastq.gz' \
    ! -name '*_R2*.fastq.gz' ! -name '*_2.fastq.gz' -print0 |
parallel -0 -j "$JOBS" --retries 2 --joblog fastq_qc.joblog --line-buffer \
    --halt soon,fail=1 qc_one {}

for dataset in pn k4 k27; do
    [[ -d $dataset/qc/fastp ]] || continue
    mkdir -p "$dataset/qc/multiqc"
    multiqc "$dataset/qc/fastqc_raw" "$dataset/qc/fastp" "$dataset/qc/fastqc_clean" \
        -o "$dataset/qc/multiqc" \
        -n "${dataset}_fastq_qc.html" -f \
        > "$dataset/qc/multiqc.log" 2>&1
    echo "report: $dataset/qc/multiqc/${dataset}_fastq_qc.html"
done
