#!/usr/bin/env bash
# run_pipeline.sh — per-sample parental-origin pipeline.
#
# Reads samples.tsv (header + columns:
#   sample_id  bam  genome1  genome2  maternal  paternal;
# '#'-prefixed lines are ignored). Runs for each sample:
#   pot-split -> pot-qc -> pot-split-bw -> pot-ase
#
# ChIP/ATAC-only data: comment out the pot-ase line.
# RNA-only data:       comment out the pot-split-bw line.
#
# Usage: run_pipeline.sh [-c config.yaml]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$DIR/../tools"

CONFIG="config.yaml"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config) CONFIG="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

SAMPLES="$(python3 "$TOOLS/lib/pot_config.py" --get samples --config "$CONFIG")"
[[ -n "$SAMPLES" ]] || SAMPLES="samples.tsv"
[[ -s "$SAMPLES" ]] || { echo "ERROR: samples.tsv not found: $SAMPLES (see samples.example.tsv)" >&2; exit 1; }

mkdir -p qc ase

grep -v '^#' "$SAMPLES" | tail -n +2 | while IFS=$'\t' read -r sid bam g1 g2 mat pat; do
  [[ -z "$sid" || -z "$bam" ]] && continue
  echo "==> $sid"
  "$TOOLS/pot-split"    -b "$bam" -s "$sid" -c "$CONFIG"
  "$TOOLS/pot-qc"       -s "$sid" -c "$CONFIG" -o "qc/${sid}.qc.tsv"
  "$TOOLS/pot-split-bw" -s "$sid" -c "$CONFIG"
  "$TOOLS/pot-ase"      -s "$sid" -c "$CONFIG" -o "ase/${sid}.ase.tsv"
done

echo "run_pipeline.sh done."
