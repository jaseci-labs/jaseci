"""Handle jac compile data for jaclang.org.

This script is used to handle the jac compile data for jac playground.
"""

import os
import shutil
import subprocess
import time
import zipfile

from jaclang.utils.lang_tools import AstTool

TARGET_FOLDER = "../jac/jaclang"
EXTRACTED_FOLDER = "docs/playground"
PLAYGROUND_ZIP_PATH = os.path.join(EXTRACTED_FOLDER, "jaclang.zip")
ZIP_FOLDER_NAME = "jaclang"
UNIIR_NODE_DOC = "docs/internals/uniir_node.md"
LANG_REF_DOC = "docs/learn/jac_ref.md"
TOP_CONTRIBUTORS_DOC = "docs/communityhub/top_contributors.md"
AST_TOOL = AstTool()
EXAMPLE_SOURCE_FOLDER = "../jac/examples"
EXAMPLE_TARGET_FOLDER = "docs/assets/examples"


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")
    copy_example_folder()
    if os.path.exists(PLAYGROUND_ZIP_PATH):
        print(f"Removing existing zip file: {PLAYGROUND_ZIP_PATH}")
        os.remove(PLAYGROUND_ZIP_PATH)
    create_playground_zip()
    print("Jaclang zip file created successfully.")

    if is_file_older_than_minutes(UNIIR_NODE_DOC, 5):
        with open(UNIIR_NODE_DOC, "w") as f:
            f.write(AST_TOOL.autodoc_uninode())
    else:
        print(f"File is recent: {UNIIR_NODE_DOC}. Skipping creation.")

    if is_file_older_than_minutes(LANG_REF_DOC, 5):
        with open(LANG_REF_DOC, "w") as f:
            f.write(AST_TOOL.automate_ref())
    else:
        print(f"File is recent: {LANG_REF_DOC}. Skipping creation.")

    if is_file_older_than_minutes(TOP_CONTRIBUTORS_DOC, 5):
        with open(TOP_CONTRIBUTORS_DOC, "w") as f:
            f.write(get_top_contributors())
    else:
        print(f"File is recent: {TOP_CONTRIBUTORS_DOC}. Skipping creation.")


def is_file_older_than_minutes(file_path: str, minutes: int) -> bool:
    """Check if a file is older than the specified number of minutes."""
    if not os.path.exists(file_path):
        return True

    file_time = os.path.getmtime(file_path)
    current_time = time.time()
    time_diff_minutes = (current_time - file_time) / 60

    return time_diff_minutes > minutes


def create_playground_zip() -> None:
    """Create a zip file containing the jaclang folder.

    The zip file is created in the EXTRACTED_FOLDER directory.
    """
    print("Creating final zip...")

    if not os.path.exists(TARGET_FOLDER):
        raise FileNotFoundError(f"Folder not found: {TARGET_FOLDER}")

    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(TARGET_FOLDER):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.join(
                    ZIP_FOLDER_NAME, os.path.relpath(file_path, TARGET_FOLDER)
                )
                zipf.write(file_path, arcname)

    print("Zip saved to:", PLAYGROUND_ZIP_PATH)


def get_top_contributors() -> str:
    """Get the top contributors for the jaclang repository."""
    return subprocess.check_output(["python", "../scripts/top_contributors.py"]).decode(
        "utf-8"
    )


def copy_example_folder() -> None:
    """Copy only .jac files from the example folder to the documentation assets, preserving the folder structure."""
    try:
        if os.path.exists(EXAMPLE_TARGET_FOLDER):
            print(
                f"Destination folder '{EXAMPLE_TARGET_FOLDER}' already exists. Removing it..."
            )
            shutil.rmtree(EXAMPLE_TARGET_FOLDER)

        for root, _dirs, files in os.walk(EXAMPLE_SOURCE_FOLDER):
            rel_path = os.path.relpath(root, EXAMPLE_SOURCE_FOLDER)
            target_dir = os.path.join(EXAMPLE_TARGET_FOLDER, rel_path)
            os.makedirs(target_dir, exist_ok=True)

            for file in files:
                if file.endswith(".jac"):
                    src_file = os.path.join(root, file)
                    dst_file = os.path.join(target_dir, file)
                    shutil.copy2(src_file, dst_file)

        print(
            f"Copied only .jac files from '{EXAMPLE_SOURCE_FOLDER}' to "
            f"'{EXAMPLE_TARGET_FOLDER}' preserving folder structure."
        )

    except Exception as e:
        print(f"Error occurred: {e}")


pre_build_hook()
