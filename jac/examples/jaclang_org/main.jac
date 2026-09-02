import from source.files {
    source_tree,
    source_file,
    source_span,
    example_sources,
    SourceFile,
    SourceView,
    SourceSpan
}
import from docs.graph { docs_status, doc_tree, doc_page, llms_txt }
import from docs.sync { docs_sync_tick }
import from shared.install { ensure_install, install_sh }
import from leaderboard.board { submit_repo, leaderboard, board_status }
import from socialize.social_graph {
    setup_profile,
    get_profile,
    get_all_profiles,
    follow_user,
    unfollow_user,
    create_tweet,
    delete_tweet,
    like_tweet,
    add_comment,
    load_feed,
    get_trending,
    create_channel,
    join_channel,
    leave_channel,
    get_channels,
    get_channel_detail,
    create_channel_tweet
}

import ".styles.global.css";
import ".styles.site.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
