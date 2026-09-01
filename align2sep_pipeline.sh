#!/bin/bash
# ============================================================
# Parent-of-origin analysis pipeline
#
# Father : PWK_PhJ
# Mother : B6
# Genome : GRCm38
#
# Input:
#   trimmed_results/*_1_val_1.fq.gz
#   trimmed_results/*_2_val_2.fq.gz
#
# Existing Bowtie2 index:
#   GRCm38_masked_idx
#
# SNPsplit SNP file:
#   all_SNPs_PWK_PhJ_GRCm38.txt.gz
#
# Steps:
#   1. Bowtie2 alignment
#   2. samtools sort + index
#   3. Picard duplicate removal
#   4. SNPsplit parental assignment
#
# Multiple samples are processed in parallel.
# ============================================================

set -eo pipefail


# ============================================================
# Configuration
# ============================================================
# Threads used by each sample
THREADS=28
# Maximum number of samples processed simultaneously
MAX_JOBS=2
# Input FASTQ directory
TRIMMED_DIR="./trimmed_results"
# Existing Bowtie2 index
BOWTIE_INDEX="GRCm38_masked_idx"
# SNPsplit SNP annotation
SNP_FILE="all_SNPs_PWK_PhJ_GRCm38.txt.gz"
# Output directory
OUTPUT_DIR="./results"
mkdir -p "${OUTPUT_DIR}"
# ============================================================
# Conda initialization
# ============================================================
source ~/miniconda3/etc/profile.d/conda.sh
# ============================================================
# Function: process one sample
# ============================================================
process_sample() {
    SAMPLE="$1"
    echo ""
    echo "=========================================="
    echo "Processing: ${SAMPLE}"
    echo "=========================================="

    # --------------------------------------------------------
    # Input FASTQ
    # --------------------------------------------------------

    R1="${TRIMMED_DIR}/${SAMPLE}_1_val_1.fq.gz"
    R2="${TRIMMED_DIR}/${SAMPLE}_2_val_2.fq.gz"

    if [[ ! -f "${R1}" ]]; then
        echo "ERROR: ${R1} not found"
        return 1
    fi

    if [[ ! -f "${R2}" ]]; then
        echo "ERROR: ${R2} not found"
        return 1
    fi


    # --------------------------------------------------------
    # Sample output directory
    # --------------------------------------------------------

    SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE}"

    mkdir -p "${SAMPLE_DIR}"


    # ========================================================
    # STEP 1
    # Bowtie2 alignment
    # Environment: alignment
    # ========================================================

    conda activate alignment

    echo "[${SAMPLE}] Bowtie2 alignment..."

    bowtie2 \
        -x "${BOWTIE_INDEX}" \
        -1 "${R1}" \
        -2 "${R2}" \
        -N 1 \
        -L 25 \
        -p "${THREADS}" \
        -S "${SAMPLE_DIR}/aligned_masked.sam" \
        2> "${SAMPLE_DIR}/bowtie2_stats.txt"


    # ========================================================
    # STEP 2
    # SAM -> sorted BAM
    # ========================================================

    echo "[${SAMPLE}] Sorting BAM..."

    samtools view \
        -bS "${SAMPLE_DIR}/aligned_masked.sam" \
        | samtools sort \
            -@ "${THREADS}" \
            -o "${SAMPLE_DIR}/aligned_masked.sorted.bam"


    echo "[${SAMPLE}] Indexing BAM..."

    samtools index \
        "${SAMPLE_DIR}/aligned_masked.sorted.bam"


    # ========================================================
    # STEP 3
    # Picard duplicate removal
    # Environment: hum_sperm
    # ========================================================

    conda activate hum_sperm

    echo "[${SAMPLE}] Removing duplicates..."

    picard MarkDuplicates \
        I="${SAMPLE_DIR}/aligned_masked.sorted.bam" \
        O="${SAMPLE_DIR}/align_masked_dedup.bam" \
        M="${SAMPLE_DIR}/align_masked_metrics.txt" \
        REMOVE_DUPLICATES=true \
        CREATE_INDEX=true \
        ASSUME_SORTED=true


    # ========================================================
    # STEP 4
    # SNPsplit parental assignment
    # Environment: parental_sep
    # ========================================================

    conda activate parental_sep

    echo "[${SAMPLE}] Running SNPsplit..."

    mkdir -p "${SAMPLE_DIR}/SNPsplit_output"

    SNPsplit \
        --snp_file "${SNP_FILE}" \
        --paired \
        --no_sort \
        --conflicting \
        -o "${SAMPLE_DIR}/SNPsplit_output/" \
        "${SAMPLE_DIR}/align_masked_dedup.bam"


    # ========================================================
    # Finished
    # ========================================================

    echo ""
    echo "=========================================="
    echo "${SAMPLE} completed successfully"
    echo "=========================================="

}


# ============================================================
# Find all samples
# ============================================================

echo "=========================================="
echo "Searching for samples..."
echo "=========================================="

for R1 in "${TRIMMED_DIR}"/*_1_val_1.fq.gz
do

    # If no files are found
    [[ -e "${R1}" ]] || continue

    SAMPLE=$(basename "${R1}" "_1_val_1.fq.gz")

    echo "Found sample: ${SAMPLE}"

done


# ============================================================
# Parallel processing
# ============================================================

echo ""
echo "=========================================="
echo "Starting parallel processing"
echo "MAX_JOBS = ${MAX_JOBS}"
echo "THREADS  = ${THREADS}"
echo "=========================================="


for R1 in "${TRIMMED_DIR}"/*_1_val_1.fq.gz
do

    [[ -e "${R1}" ]] || continue

    SAMPLE=$(basename "${R1}" "_1_val_1.fq.gz")

    process_sample "${SAMPLE}" &


    # --------------------------------------------------------
    # Limit number of simultaneous samples
    # --------------------------------------------------------

    while [[ $(jobs -rp | wc -l) -ge ${MAX_JOBS} ]]
    do
        wait -n
    done

done
# ============================================================
# Wait for remaining jobs
# ============================================================
wait
echo ""
echo "=========================================="
echo "ALL SAMPLES COMPLETED"
echo "=========================================="
echo "Results:"
echo "${OUTPUT_DIR}/"
echo "=========================================="
