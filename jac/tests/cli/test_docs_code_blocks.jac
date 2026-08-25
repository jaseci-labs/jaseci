"""Every ```jac code block in the bundled docs corpus parses.

The suite home of what `scripts/validate_docs_code.jac` did from a ci.yml
step: extract fenced jac blocks from the corpus markdown and hold them to
the parser, in process via `parse_diags` instead of a `jac check
--parse_only` subprocess per batch. A block preceded by `<!-- jac-skip -->`
is exempt, as are the files whose blocks are deliberately not Jac.
"""

import re;
import from pathlib { Path }
import from jaclang.cli { guide_store }
import from jaclang.compiler.frontend.parser.frontend { parse_diags }

glob SKIP_FILES: list[str] = ["breaking-changes.md"],
     SKIP_DIRS: list[str] = ["release_notes"],
     FENCE = re.compile(r"^```(jac(?::\w+)?(?:\s+[^\n]*)?)\s*$"),
     SKIP_MARK = re.compile(r"<!--\s*jac-skip\s*-->");


def _extract_blocks(path: Path) -> list[tuple[str, int]] {
    blocks: list[tuple[str, int]] = [];
    lines = path.read_text(encoding="utf-8").split("\n");
    i = 0;
    while i < len(lines) {
        if FENCE.`match(lines[i]) {
            skipped = (i > 0) and SKIP_MARK.search(lines[i - 1]);
            start = i + 1;
            body: list[str] = [];
            i += 1;
            while (i < len(lines)) and not lines[i].startswith("```") {
                body.append(lines[i]);
                i += 1;
            }
            content = "\n".join(body).strip();
            if content and not skipped {
                blocks.append((content, start));
            }
        }
        i += 1;
    }
    return blocks;
}


test "docs corpus jac code blocks all parse" {
    docs_dir = Path(guide_store.__file__).parent / "docs";
    assert docs_dir.is_dir() , f"docs corpus missing at {docs_dir}";
    md_files = [
        f
        for f in sorted(docs_dir.rglob("*.md"))
        if (f.name not in SKIP_FILES) and not any(d in f.parts for d in SKIP_DIRS)
    ];
    assert md_files , "no markdown files found in the docs corpus";
    failures: list[str] = [];
    total = 0;
    for md in md_files {
        for (content, line) in _extract_blocks(md) {
            total += 1;
            (had, pd, ld) = parse_diags(content, f"{md}:{line}");
            if had {
                first = str((pd or ld or ["syntax error"])[0]);
                failures.append(f"{md}:{line}: {first}");
            }
        }
    }
    assert total > 0 , "no jac code blocks found in the docs corpus";
    assert not failures , (
        f"{len(failures)}/{total} docs code blocks fail to parse:\n"
        + "\n".join(failures[:40])
    );
}
