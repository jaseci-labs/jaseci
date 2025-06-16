# todo_app.jac
import from datetime { datetime }
import json;

# Define our data structures
node TodoList {
    has name: str;
    has created_at: str;
}

node TodoItem {
    has title: str;
    has created_at: str;
    has completed: bool = False;
    has due_date: str = "";

}

edge Contains{}
edge NextItem{}

# Walker to add new todos
walker AddTodo {
    has title: str;
    has due_date: str = "";

    can add with TodoList entry;
}

# Walker to list todos
walker ListTodos {
    has show_completed: bool = False;
    has items: list = [];

    can collect with TodoList entry;

    can display with TodoList exit;
}

# Walker to complete todos
walker CompleteTodo {
    has item_index: int;

    can complete with TodoList entry;
}

impl AddTodo.add {
    new_item = here +>:Contains:+> TodoItem(
        title=self.title,
        created_at=datetime.now().isoformat(),
        due_date=self.due_date
    );

    # Link to previous items
    last_item = [->:Contains:->(`?TodoItem)][-2:];
    if last_item {
        last_item[0] +>:NextItem:+> new_item;
    }

    report f"Added: {self.title}";
}

impl ListTodos.collect {
    temp = [->:Contains:->(`?TodoItem)];
    for item in [->:Contains:->(`?TodoItem)] {
        if not item.completed or self.show_completed {
            self.items.append({
                "title": item.title,
                "completed": item.completed,
                "created": item.created_at,
                "due": item.due_date
            });
        }
    }
}

impl ListTodos.display {
    print("=== Todo List ===");
    for (i, item) in enumerate(self.items) {
        status = f"✓" if item["completed"] else f"○";
        due = f" (due: {item['due']})" if item["due"] else "";
        print(f"{i+1}. {status} {item['title']}{due}");
    }
    print(f"Total: {len(self.items)} items");
}

impl CompleteTodo.complete {
    items = [->:Contains:->(`?TodoItem)];
    if 0 <= self.item_index < len(items) {
        items[self.item_index].completed = True;
        report f"Completed: {items[self.item_index].title}";
    } else {
        report "Invalid item index!";
    }
}

# Main program
with entry {
    # Create or get existing todo list
    my_list = TodoList(
        name="My Tasks",
        created_at=datetime.now().isoformat()
    );

    # Example: Add some todos
    AddTodo(title="Learn Jac basics", due_date="2024-12-31") spawn my_list;
    AddTodo(title="Build first Jac app") spawn my_list;
    AddTodo(title="Master object-spatial programming") spawn my_list;

    # List all todos
    ListTodos(show_completed=True) spawn my_list;
}