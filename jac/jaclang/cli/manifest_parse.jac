import argparse;
import from jaclang.cli.command { Arg, CommandSpec }

def add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None;
def build_command_parser(meta: CommandSpec) -> argparse.ArgumentParser;
