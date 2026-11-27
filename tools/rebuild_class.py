"""Rebuild selected materialized AS3 classes into the verified reference mod."""

import argparse
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from modkit.patcher import expand_swf, patch_swf, read_payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-swf", required=True, type=pathlib.Path)
    parser.add_argument("--sources", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--java", default="java")
    parser.add_argument("--ffdec", required=True, type=pathlib.Path)
    parser.add_argument("--class", dest="classes", action="append", required=True)
    args = parser.parse_args()
    if args.original_swf.resolve() == args.output.resolve():
        raise SystemExit("Output must differ from the original SWF")
    selected = []
    for name in args.classes:
        if not all(part.isidentifier() for part in name.split(".")):
            raise SystemExit("Invalid class name")
        path = args.sources.joinpath(*name.split(".")).with_suffix(".as")
        if not path.is_file():
            raise SystemExit("Source missing: " + str(path))
        selected.extend([name, str(path.resolve())])
    manifest, patch = read_payload(ROOT / "payload")
    seed = patch_swf(args.original_swf.read_bytes(), manifest, patch)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(seed)
    command = [args.java, "-Xmx4096m", "-jar", str(args.ffdec.resolve()), "-air", "-replace",
               str(args.output.resolve()), str(args.output.resolve()), *selected]
    subprocess.run(command, check=True)
    expand_swf(args.output.read_bytes())
    print("Compiled and validated " + str(args.output))


if __name__ == "__main__":
    main()
