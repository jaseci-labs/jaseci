"""Compose TODO — Jetpack Compose example using the native Compose pipeline.

    jac setup android
    jac build --client android --platform android
    jac start --client android

Reactive task list with on-device walkers when [sv] deploy = "device".
"""

node Todo {
    has title: str;
}

walker:pub add_todo {
    has title: str;

    can add with Root entry {
        new_todo = here ++> Todo(title=self.title);
        report new_todo.title;
    }
}

walker:pub list_todos {
    can list with Root entry {
        for t in [root-->][?:Todo] {
            report t.title;
        }
    }
}

walker:pub clear {
    can clear_all with Root entry {
        for t in [root-->][?:Todo] {
            del t;
        }
    }
}

def:pub app -> Composable {
    has titles: list[str] = [],
        draft: str = "";

    async can with entry {
        result = root spawn list_todos();
        titles = result.reports;
    }

    return
        <Column modifier={Modifier.fillMaxSize().padding(16.dp)}>
            <Text style={Typography.titleLarge}>"Jac TODO"</Text>
            <Text style={Typography.bodyMedium}>{f"{titles.len} tasks"}</Text>
            <Text style={Typography.labelSmall}>
                "Add a task — ! and urgent bump priority"
            </Text>
            <Row modifier={Modifier.fillMaxWidth().padding(top=8.dp, bottom=8.dp)}>
                <Raw
                    kotlin={"coil.compose.AsyncImage(model = \"https://www.gstatic.com/images/icons/material/system/2x/task_alt_black_24dp.png\", contentDescription = null, modifier = Modifier.size(28.dp).padding(end = 8.dp))"}
                />
                <OutlinedTextField
                    modifier={Modifier.padding(end=8.dp)}
                    value={draft}
                    onValueChange={lambda (v: str) { draft = v; }}
                />
                <Button
                    onClick={lambda {
                        if draft != "" {
                            score: int = 0;
                            if "!" in draft {
                                score = score + 20;
                            }
                            if "urgent" in draft {
                                score = score + 50;
                            }
                            if score > 100 {
                                score = 100;
                            }
                            label = draft;
                            if score > 0 {
                                label = f"{draft} (p{score})";
                            }
                            resp = root spawn add_todo(title=label);
                            titles = titles + resp.reports;
                            draft = "";
                        }
                    }}
                >
                    <Text>"Add"</Text>
                </Button>
            </Row>
            <Column modifier={Modifier.fillMaxWidth()}>
                {[
                    <Card modifier={Modifier.fillMaxWidth().padding(bottom=8.dp)}>
                        <Text modifier={Modifier.padding(12.dp)}>{title}</Text>
                    </Card>
                    for title in titles
                ]}
            </Column>
            <OutlinedButton
                onClick={lambda {
                    root spawn clear();
                    titles = [];
                }}
            >
                <Text>"Clear all"</Text>
            </OutlinedButton>
        </Column>;
}
