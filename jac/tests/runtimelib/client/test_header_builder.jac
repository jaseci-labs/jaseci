"""HeaderBuilder must emit crawler-parseable meta tags.

Unquoted attribute values end at the first space per HTML parsing rules,
so `content=The Jac Programming Language` reads back as content="The" -
exactly what link-preview crawlers (LinkedIn, Slack, X) then display.
"""

import from jaclang.runtimelib.client.serving { HeaderBuilder }


test "attribute values are quoted so spaces survive crawlers" {
    hb = HeaderBuilder(
        meta_data={
            "title": "The Jac Programming Language",
            "description": "One language, one compiler, the whole stack.",
            "og_title": "The Jac Programming Language",
            "og_description": "One language, one compiler, the whole stack.",
            "og_url": "https://jaclang.org/",
            "icon": "/static/assets/jac-logo.png",
            "meta_color_scheme": "dark light"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<title>The Jac Programming Language</title>' in head;
    assert '<meta property="og:title" content="The Jac Programming Language" />'
        in head;
    assert '<meta name="description" content="One language, one compiler, the whole stack." />'
        in head;
    assert '<link rel="icon" href="/static/assets/jac-logo.png" />' in head;
    assert '<meta name="color-scheme" content="dark light" />' in head;
    assert "content=The " not in head;
    assert "content=One " not in head;
}


test "og property names keep their spec underscores" {
    hb = HeaderBuilder(
        meta_data={
            "og_site_name": "jaclang.org",
            "og_image_secure_url": "https://jaclang.org/logo.png",
            "og_locale_alternate": "en_GB",
            "og_image_width": "1200"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta property="og:site_name" content="jaclang.org" />' in head;
    assert '<meta property="og:image:secure_url" content="https://jaclang.org/logo.png" />'
        in head;
    assert '<meta property="og:locale:alternate" content="en_GB" />' in head;
    assert '<meta property="og:image:width" content="1200" />' in head;
    assert "og:site:name" not in head;
}


test "twitter keys emit twitter colon names" {
    hb = HeaderBuilder(
        meta_data={
            "twitter_card": "summary",
            "twitter_image": "https://jaclang.org/logo.png",
            "twitter_image_alt": "Jac logo"
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<meta name="twitter:card" content="summary" />' in head;
    assert '<meta name="twitter:image" content="https://jaclang.org/logo.png" />'
        in head;
    assert '<meta name="twitter:image:alt" content="Jac logo" />' in head;
}


test "values are escaped inside their quotes" {
    hb = HeaderBuilder(meta_data={"og_title": 'A "B" & <C>'}, function_name="app");
    head = hb.build_head();
    assert 'content="A &quot;B&quot; &amp; &lt;C&gt;"' in head;
}


"""Both tag shapes in one pass. The external entry's exact string pins every
attribute rule at once: src escaping, a bare flag from `true`, `false` omitting
`async`, `0` and `""` surviving as real values, underscore folding, a name no
whitelist knew (`blocking`), an event handler (the CDN fallback pattern), and
insertion order. Because the match is exact, it also proves the four malformed
keys built nothing. The inline entry pins that a body renders raw but cannot
close the tag early, in any case, while unrelated tags pass through."""
test "script entries render every attribute and body rule" {
    hb = HeaderBuilder(
        meta_data={
            "title": "My App",
            "og_title": "My App",
            "icon": "/favicon.png",
            "scripts": [
                {
                    "src": "https://cdn.example.com/a.js?x=1&y=2",
                    "defer": True,
                    "async": False,
                    "type": "module",
                    "integrity": "sha384-abc\"def",
                    "data_site_id": "jac & co",
                    "blocking": "render",
                    "tabindex": 0,
                    "data_empty": "",
                    "onerror": "fallback()",
                    "data_x onmouseover": "alert(1)",
                    'data_y" onclick="alert(2)': "v",
                    "data_UPPER": "v",
                    "data_": "v"
                },
                {"content": 'var a = "</script><b>", b = "</SCRIPT>", c = "</div>";'}
            ]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert (
        '<script src="https://cdn.example.com/a.js?x=1&amp;y=2" defer type="module"'
        ' integrity="sha384-abc&quot;def" data-site-id="jac &amp; co"'
        ' blocking="render" tabindex="0" data-empty=""'
        ' onerror="fallback()"></script>'
    )
        in head;
    assert '"<\\/script><b>", b = "<\\/SCRIPT>", c = "</div>";' in head;
    assert head.count("</script>") == 2;
    assert head.index("<script") > head.index('<link rel="icon"');
    assert head.index("<script") > head.index('<meta property="og:title"');
}


"""Every accepted spelling reaches the same renderer, and anything malformed
degrades to no output rather than an error or a broken tag."""
test "all input shapes are accepted and malformed config emits nothing" {
    shapes = [
        ["https://cdn.example.com/sdk.js"],
        {"src": "https://cdn.example.com/sdk.js"},
        [{"src": "https://cdn.example.com/sdk.js", "content": "ignored()"}]
    ];
    for value in shapes {
        head = HeaderBuilder(
            meta_data={"scripts": value}, function_name="app"
        ).build_head();
        assert '<script src="https://cdn.example.com/sdk.js"></script>' in head;
        assert "ignored()" not in head;
    }
    for value in [None, "", [], {}, "not-a-list", 42] {
        hb = HeaderBuilder(meta_data={"scripts": value}, function_name="app");
        assert "<script" not in hb.build_head();
    }
    head = HeaderBuilder(
        meta_data={
            "scripts": [{"defer": True}, {"src": "  "}, {}, "", 42, {"src": "/real.js"}]
        },
        function_name="app"
    ).build_head();
    assert head.count("<script") == 1;
    assert '<script src="/real.js"></script>' in head;
}
