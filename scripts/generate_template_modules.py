#!/usr/bin/env python3
import sys
import json
from pathlib import Path

FILES = [
    "Makefile",
    "header.tex",
    "img/takibi-icon-v3.jpg",
    "slide.md",
]


def ocaml_string(data):
    return "".join(f"\\{byte:03d}" for byte in data)


def haskell_string(data):
    return "".join(f"\\{byte}\\&" for byte in data)


def quoted(text):
    return json.dumps(text)


def generate_ocaml(output, template_dir):
    lines = ["let files = [\n"]
    for name in FILES:
        data = (template_dir / name).read_bytes()
        lines.append(f"  ({quoted(name)}, \"{ocaml_string(data)}\");\n")
    lines.append("]\n")
    output.write_text("".join(lines))


def generate_haskell(output, template_dir):
    lines = [
        "module TemplateData (files) where\n",
        "\n",
        "import qualified Data.ByteString as BS\n",
        "import qualified Data.ByteString.Char8 as BSC\n",
        "\n",
        "files :: [(FilePath, BS.ByteString)]\n",
        "files =\n",
        "  [\n",
    ]
    for index, name in enumerate(FILES):
        data = (template_dir / name).read_bytes()
        comma = "," if index + 1 < len(FILES) else ""
        lines.append(f"    ({quoted(name)}, BSC.pack \"{haskell_string(data)}\"){comma}\n")
    lines.append("  ]\n")
    output.write_text("".join(lines))


def main():
    if len(sys.argv) != 4:
        print(
            "usage: generate_template_modules.py ocaml|haskell OUTPUT TEMPLATE_DIR",
            file=sys.stderr,
        )
        return 2

    language = sys.argv[1]
    output = Path(sys.argv[2])
    template_dir = Path(sys.argv[3])
    output.parent.mkdir(parents=True, exist_ok=True)

    if language == "ocaml":
        generate_ocaml(output, template_dir)
    elif language == "haskell":
        generate_haskell(output, template_dir)
    else:
        print(f"unknown language: {language}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
