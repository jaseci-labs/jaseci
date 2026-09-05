import from core.source.files {
    source_tree,
    source_file,
    source_span,
    example_sources,
    SourceFile,
    SourceView,
    SourceSpan
}
import from core.docs.graph { docs_status, doc_tree, doc_page, llms_txt }
import from core.docs.sync { docs_sync_tick }
import from core.install { ensure_install, install_sh }
import from core.leaderboard.board { submit_repo, leaderboard, board_status }

import ".styles.global.css";
import ".styles.site.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
