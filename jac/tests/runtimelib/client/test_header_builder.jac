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


test "external scripts render src plus boolean flags" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [
                {"src": "https://js.stripe.com/v3", "defer": True},
                {"src": "/legacy.js", "nomodule": True, "async": True},
                {"src": "/mod.js", "type": "module", "defer": False}
            ]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<script src="https://js.stripe.com/v3" defer></script>' in head;
    assert '<script src="/legacy.js" nomodule async></script>' in head;
    assert '<script src="/mod.js" type="module"></script>' in head;
}


test "a bare string entry is shorthand for src" {
    hb = HeaderBuilder(
        meta_data={"scripts": ["https://cdn.example.com/sdk.js"]}, function_name="app"
    );
    assert '<script src="https://cdn.example.com/sdk.js"></script>' in hb.build_head();
}


test "attribute values are escaped inside their quotes" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [
                {
                    "src": "https://cdn.example.com/a.js?x=1&y=2",
                    "integrity": "sha384-abc\"def",
                    "crossorigin": "anonymous",
                    "data_site_id": "jac-1"
                }
            ]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert 'src="https://cdn.example.com/a.js?x=1&amp;y=2"' in head;
    assert 'integrity="sha384-abc&quot;def"' in head;
    assert 'crossorigin="anonymous"' in head;
    assert 'data-site-id="jac-1"' in head;
}


test "event handler attributes are never emitted" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [{"src": "/a.js", "onload": "alert(1)", "onerror": "alert(2)"}]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<script src="/a.js"></script>' in head;
    assert "onload" not in head;
    assert "alert" not in head;
}


test "attributes are validated by shape, not by a vocabulary list" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [
                {"src": "/a.js", "blocking": "render", "data_flag": True, "tabindex": 3}
            ]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<script src="/a.js" blocking="render" data-flag tabindex="3"></script>'
        in head;
}


test "inline content renders as a script body" {
    hb = HeaderBuilder(
        meta_data={"scripts": [{"content": "window.dataLayer=window.dataLayer||[];"}]},
        function_name="app"
    );
    assert '<script>window.dataLayer=window.dataLayer||[];</script>' in hb.build_head();
}


test "a closing script tag inside inline content cannot break out" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [{"content": 'var a = "</script><img src=x onerror=alert(1)>";'}]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert '<\\/script>' in head;
    assert '"</script>' not in head;
    assert head.count("</script>") == 1;
}


test "entries with neither src nor content are skipped" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [{"defer": True}, {"src": "   "}, {}, "", {"src": "/real.js"}]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert head.count("<script") == 1;
    assert '<script src="/real.js"></script>' in head;
}


test "scripts come last so crawler tags stay at the top of the head" {
    hb = HeaderBuilder(
        meta_data={
            "title": "My App",
            "og_title": "My App",
            "icon": "/favicon.png",
            "scripts": [{"src": "/a.js"}]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert head.index("<script") > head.index('<link rel="icon"');
    assert head.index("<script") > head.index("<meta property=\"og:title\"");
}


test "a missing or malformed scripts key emits nothing" {
    for value in [None, "", [], {}, "not-a-list", 42] {
        hb = HeaderBuilder(meta_data={"scripts": value}, function_name="app");
        assert "<script" not in hb.build_head();
    }
}


test "a single table entry works without the array wrapper" {
    hb = HeaderBuilder(
        meta_data={"scripts": {"src": "/one.js", "defer": True}}, function_name="app"
    );
    assert '<script src="/one.js" defer></script>' in hb.build_head();
}


test "src wins when both src and content are given" {
    hb = HeaderBuilder(
        meta_data={"scripts": [{"src": "/a.js", "content": "ignored()"}]},
        function_name="app"
    );
    head = hb.build_head();
    assert '<script src="/a.js"></script>' in head;
    assert "ignored()" not in head;
}


test "uppercase closing tags are neutralized too" {
    hb = HeaderBuilder(
        meta_data={"scripts": [{"content": 'var a = "</SCRIPT ><b>";'}]},
        function_name="app"
    );
    head = hb.build_head();
    assert '<\\/SCRIPT' in head;
    assert "</SCRIPT" not in head;
    assert head.count("</script>") == 1;
}


test "unrelated closing tags in inline content are left alone" {
    hb = HeaderBuilder(
        meta_data={"scripts": [{"content": 'var a = "</div></span>";'}]},
        function_name="app"
    );
    head = hb.build_head();
    assert '</div></span>' in head;
    assert "<\\/" not in head;
}


test "a data key cannot smuggle extra attribute names" {
    hb = HeaderBuilder(
        meta_data={
            "scripts": [
                {
                    "src": "/a.js",
                    "data_x onmouseover": "alert(1)",
                    'data_y" onclick="alert(1)': "v",
                    "data_UPPER": "v",
                    "data_ok": "1"
                }
            ]
        },
        function_name="app"
    );
    head = hb.build_head();
    assert 'data-ok="1"' in head;
    assert "onmouseover" not in head;
    assert "onclick" not in head;
    assert "data-UPPER" not in head;
}
