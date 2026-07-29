import argparse;
import from jaclang.cli.manifest { ArgMeta, CommandMeta }

def add_argument(parser: argparse.ArgumentParser, arg: ArgMeta) -> None;
def build_command_parser(meta: CommandMeta) -> argparse.ArgumentParser;
