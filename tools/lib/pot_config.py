#!/usr/bin/env python3
"""Shared config/sample helpers for parental-origin-toolkit (pot-*) tools.

Config file resolution order: --config/-c flag > POT_CONFIG env var > ./config.yaml.
Dotted keys, e.g. `genomes.masked`. Missing optional keys return "".

CLI (used by bash tools via pot-common.sh):
    pot_config.py --get genomes.masked --config config.yaml
    pot_config.py --sample SAMPLE_ID --field maternal --config config.yaml
"""
import os
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("ERROR: PyYAML is required: conda install pyyaml")


def find_config(cli_path=None):
    if cli_path:
        return cli_path
    if os.environ.get("POT_CONFIG"):
        return os.environ["POT_CONFIG"]
    return "config.yaml"


def load_config(cli_path=None):
    path = find_config(cli_path)
    if not os.path.exists(path):
        sys.exit(
            f"ERROR: config file not found: {path}\n"
            "copy config.example.yaml to config.yaml and edit the local paths"
        )
    with open(path, encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh) or {}
    cfg["_path"] = path
    return cfg


def get_cfg(cfg, dotted, default="", required=False):
    """Resolve a dotted key; exit with a clear message if required and missing."""
    node = cfg
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            if required:
                sys.exit(f"ERROR: config key '{dotted}' is required")
            return default
        node = node[part]
    return node


def load_samples(cfg):
    """Parse samples.tsv -> {sample_id: {field: value}}.

    First non-comment, non-empty line must be the header with a `sample_id`
    column. Lines starting with '#' are ignored.
    """
    path = get_cfg(cfg, "samples", default="samples.tsv")
    if not os.path.exists(path):
        sys.exit(f"ERROR: samples.tsv not found: {path} (see samples.example.tsv)")
    rows = {}
    header = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if header is None:
                header = fields
                if "sample_id" not in header:
                    sys.exit("ERROR: samples.tsv must have a 'sample_id' column")
                continue
            rows[fields[0]] = dict(zip(header, fields))
    return rows


def main(argv=None):
    import argparse

    ap = argparse.ArgumentParser(prog="pot_config.py")
    ap.add_argument("--config", default=None)
    ap.add_argument("--get", help="print value of a dotted config key")
    ap.add_argument("--sample", help="sample_id to look up in samples.tsv")
    ap.add_argument("--field", help="samples.tsv column to print (with --sample)")
    args = ap.parse_args(argv)

    cfg = load_config(args.config)
    if args.get:
        val = get_cfg(cfg, args.get, default="")
        if isinstance(val, (list, dict)):
            print(yaml.safe_dump(val, default_flow_style=True).strip())
        else:
            print("" if val is None else val)
    elif args.sample:
        rows = load_samples(cfg)
        if args.sample not in rows:
            sys.exit(f"ERROR: sample '{args.sample}' not found in samples.tsv")
        print(rows[args.sample].get(args.field or "", ""))
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
