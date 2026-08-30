#!/usr/bin/env python3
"""run_pipeline.py — python version of the per-sample pipeline.

Usage: run_pipeline.py [-c config.yaml]
                       [--steps split,qc,split-bw,ase] [--parallel N] [--dry-run]

Reads samples.tsv and runs the selected pot-* tools per sample.
--parallel N runs up to N samples concurrently (per-sample steps stay serial).
"""
import argparse
import concurrent.futures
import os
import subprocess
import sys

TOOLS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
sys.path.insert(0, os.path.join(TOOLS, "lib"))
import pot_config as pc

ALL_STEPS = ["split", "qc", "split-bw", "ase"]


def build_cmds(sid, bam, steps, config):
    cmds = []
    if "split" in steps:
        cmds.append([os.path.join(TOOLS, "pot-split"), "-b", bam, "-s", sid, "-c", config])
    if "qc" in steps:
        cmds.append([os.path.join(TOOLS, "pot-qc"), "-s", sid, "-c", config,
                     "-o", f"qc/{sid}.qc.tsv"])
    if "split-bw" in steps:
        cmds.append([os.path.join(TOOLS, "pot-split-bw"), "-s", sid, "-c", config])
    if "ase" in steps:
        cmds.append([os.path.join(TOOLS, "pot-ase"), "-s", sid, "-c", config,
                     "-o", f"ase/{sid}.ase.tsv"])
    return cmds


def run_sample(sid, bam, steps, config, dry):
    for cmd in build_cmds(sid, bam, steps, config):
        print(f"[{sid}] " + " ".join(cmd), flush=True)
        if not dry:
            subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser(description="Per-sample parental-origin pipeline")
    ap.add_argument("-c", "--config", default=None)
    ap.add_argument("--steps", default=",".join(ALL_STEPS),
                    help="comma-separated steps (default: split,qc,split-bw,ase)")
    ap.add_argument("--parallel", type=int, default=1)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    steps = [s.strip() for s in args.steps.split(",") if s.strip()]
    for s in steps:
        if s not in ALL_STEPS:
            sys.exit(f"unknown step '{s}'; available: {','.join(ALL_STEPS)}")

    cfg = pc.load_config(args.config)
    rows = pc.load_samples(cfg)

    os.makedirs("qc", exist_ok=True)
    os.makedirs("ase", exist_ok=True)

    if args.parallel <= 1:
        for sid, row in rows.items():
            run_sample(sid, row.get("bam", ""), steps, cfg["_path"], args.dry_run)
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.parallel) as ex:
            futures = [
                ex.submit(run_sample, sid, row.get("bam", ""), steps, cfg["_path"], args.dry_run)
                for sid, row in rows.items()
            ]
            for fut in concurrent.futures.as_completed(futures):
                fut.result()  # re-raise on failure


if __name__ == "__main__":
    main()
