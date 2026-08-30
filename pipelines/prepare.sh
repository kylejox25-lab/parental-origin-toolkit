#!/usr/bin/env bash
# prepare.sh — one-time preparation for a strain pair.
# NOT part of the per-sample pipeline: run once per strain pair.
#
# Usage: prepare.sh STRAIN_A STRAIN_B [-c config.yaml]
#   prepare.sh PWK_PhJ BL6          (reference x strain)
#   prepare.sh CAST_EiJ PWK_PhJ     (arbitrary pair)
#
# Steps: pot-get-strain -> pot-build-dsnp -> pot-build-masked
# Afterwards update config.yaml (dsnp.*, genomes.masked, genomes.bowtie2_index,
# dsnp.snp_file) with the paths printed by the tools.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$DIR/../tools"

A="${1:?usage: prepare.sh STRAIN_A STRAIN_B [-c config.yaml]}"
B="${2:?usage: prepare.sh STRAIN_A STRAIN_B [-c config.yaml]}"
shift 2

"$TOOLS/pot-get-strain"   "$A" "$B" "$@"
"$TOOLS/pot-build-dsnp"   -1 "$A" -2 "$B" "$@"
"$TOOLS/pot-build-masked" "$@"

echo "prepare.sh done. Now update config.yaml (dsnp.vcf, dsnp.bed, dsnp.snp_file,"
echo "genomes.masked, genomes.bowtie2_index) with the paths printed above."
