#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

from review import store, validation

usage = """Usage:
  review_window.py validate --session <name> --attempt <n> --subject <text> [--job <id>] [--original <url or path>]
                                    file the image of that attempt in the gallery and print its file name
  review_window.py --setup          create what is missing of the store structure, then exit
  review_window.py --match <image>  print the store line whose fingerprint is nearest to the image's, within 10 bits
  review_window.py --help           print this usage

The store structure is stated in the README."""


def refused_path(error: OSError) -> str:
    reason = error.strerror or str(error)
    return reason if error.filename is None else f"{error.filename}: {reason}"


def print_flaws(flaws: list[store.Flaw]) -> None:
    for flaw in flaws:
        print(f"{flaw.kind}: {flaw.path}", file=sys.stderr)


def set_up_store() -> int:
    try:
        for created in store.set_up():
            print(f"created: {created}", flush=True)
    except OSError as error:
        print(f"refused: {error.filename}: {error.strerror}", file=sys.stderr)
    flaws = store.flaws()
    print_flaws(flaws)
    return 1 if flaws else 0


def print_match(image: Path) -> int:
    try:
        match = validation.match_of(image)
    except OSError as error:
        print(f"unreadable: {refused_path(error)}", file=sys.stderr)
        return 2
    if match is None:
        print(f"no match within {validation.match_bits} bits")
        return 1
    print(json.dumps(match.line))
    print(f"distance: {match.distance}")
    return 0


def validated(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="review_window.py validate", add_help=False)
    parser.add_argument("--session", required=True)
    parser.add_argument("--attempt", required=True, type=int)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--job")
    parser.add_argument("--original")
    try:
        parsed = parser.parse_args(arguments)
    except SystemExit:
        print(usage, file=sys.stderr)
        return 2
    flaws = store.flaws()
    if flaws:
        print_flaws(flaws)
        return 1
    try:
        print(validation.validate(parsed.session, parsed.attempt, parsed.job, parsed.subject, parsed.original))
        return 0
    except (validation.NotShown, store.AlreadyFiled, validation.HiggsfieldFailed) as refusal:
        print(str(refusal), file=sys.stderr)
        return 1
    except OSError as error:
        print(refused_path(error), file=sys.stderr)
        return 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--help"]:
        print(usage)
        return 0
    if argv[1:] == ["--setup"]:
        return set_up_store()
    if len(argv) == 3 and argv[1] == "--match":
        return print_match(Path(argv[2]).absolute())
    if len(argv) > 1 and argv[1] == "validate":
        return validated(argv[2:])
    print(usage, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
