import from jaclang.compiler.driver.dependency_graph { dependency_groups }

test "dependency groups preserve cycles and omit unreachable nodes" {
    graph = {
        "root": ["left", "right"],
        "left": ["base", "right"],
        "right": ["left"],
        "base": [],
        "unused": ["missing"]
    };
    assert dependency_groups(graph, ["root"])
        == [["base"], ["left", "right"], ["root"]];
    assert dependency_groups({"self": ["self"]}, ["self"]) == [["self"]];
}

test "deep dependency chains do not depend on the interpreter recursion limit" {
    graph: dict[str, list[str]] = {};
    for i in range(2000) {
        graph[str(i)] = [str(i + 1)];
    }
    groups = dependency_groups(graph, ["0"]);
    assert len(groups) == 2001;
    assert groups[0] == ["2000"];
    assert groups[-1] == ["0"];
}
