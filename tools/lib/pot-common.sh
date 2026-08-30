#!/usr/bin/env bash
# Shared helpers for pot-* tools (parental-origin-toolkit).
# Usage (from a tool in tools/):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/pot-common.sh"

set -euo pipefail

POT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[pot] $(date +%H:%M:%S) $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

# Reference-genome strain aliases: these resolve to the reference genome
# itself (no MGP VCF exists for them).
REF_ALIASES=(BL6 C57BL_6J GRCm38 mm10 reference)

is_ref_strain() {
  local s="$1" r
  for r in "${REF_ALIASES[@]}"; do
    [[ "$s" == "$r" ]] && return 0
  done
  return 1
}

# potcfg <dotted.key>  -> value from the config file (empty if unset)
potcfg() {
  python3 "$POT_LIB_DIR/pot_config.py" --get "$1" --config "${POT_CONFIG_FILE:-config.yaml}"
}

# pot_sample <sample_id> <field>  -> field value from samples.tsv
pot_sample() {
  python3 "$POT_LIB_DIR/pot_config.py" --sample "$1" --field "$2" --config "${POT_CONFIG_FILE:-config.yaml}"
}

# pot_resolve <tools.KEY> <fallback-name>  -> executable path
# Prefers the config value; falls back to PATH lookup.
pot_resolve() {
  local p
  p="$(potcfg "$1")"
  if [[ -n "$p" ]]; then
    echo "$p"
  else
    command -v "$2" || die "command not found: $2 (set $1 in config.yaml)"
  fi
}

# Standard pre-parser: pulls -c/--config out of "$@" into POT_CONFIG_FILE.
# Remaining args are collected in the POT_ARGS array.
parse_pot_args() {
  POT_CONFIG_FILE="config.yaml"
  POT_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config) POT_CONFIG_FILE="$2"; shift 2 ;;
      *) POT_ARGS+=("$1"); shift ;;
    esac
  done
}

# find_split_bams <sample_id> <split_dir>  -> sets G1_BAM / G2_BAM
# SNPsplit output names are detected by glob, not assumed.
find_split_bams() {
  local dir="$1" g1 g2
  g1=$(ls "$dir"/*.genome1.bam 2>/dev/null | head -1 || true)
  g2=$(ls "$dir"/*.genome2.bam 2>/dev/null | head -1 || true)
  [[ -n "$g1" && -n "$g2" ]] || die "split BAMs not found in $dir (run pot-split first)"
  G1_BAM="$g1"
  G2_BAM="$g2"
}

# sizes_from_bam <bam>  -> chrom sizes (chr<TAB>len) from the BAM header
sizes_from_bam() {
  local st
  st="$(pot_resolve tools.samtools samtools)"
  "$st" view -H "$1" | awk '/^@SQ/{gsub(/SN:/, "", $2); gsub(/LN:/, "", $3); print $2 "\t" $3}'
}
