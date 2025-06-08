### Chapter 20: Quick Reference

#### 20.1 Syntax Comparison Table

This comprehensive comparison shows Python syntax alongside its Jac equivalent, helping you quickly translate between the two languages.

### Basic Syntax Elements

| Python | Jac | Notes |
|--------|-----|-------|
| `# Comment` | `# Comment` | Single-line comments identical |
| `"""Docstring"""` | `"""Docstring"""` | Multi-line strings identical |
| `pass` | `{}` or `;` | Empty statement/block |
| `:` (colon) | `{` ... `}` | Block delimiters |
| Indentation | Curly braces | Structural delimiter |
| No semicolons | `;` required | Statement terminator |

### Variable Declaration

| Python | Jac | Notes |
|--------|-----|-------|
| `x = 42` | `x = 42;` | Implicit declaration |
| `x: int = 42` | `let x: int = 42;` | Explicit typed declaration |
| `global x` | `:g: x;` or `glob x = 42;` | Global variable |
| `nonlocal x` | `:nl: x;` | Nonlocal variable |

### Functions

| Python | Jac | Notes |
|--------|-----|-------|
| `def func():` | `can func {` | Function declaration |
| `def func(x: int) -> str:` | `can func(x: int) -> str {` | Typed function |
| `return value` | `return value;` | Return statement |
| `lambda x: x * 2` | `lambda x: int : x * 2` | Lambda (types required) |
| `@decorator` | `@decorator` | Decorators work similarly |
| `def __init__(self):` | `can init {` | Constructor |
| N/A | `can postinit {` | Post-initialization hook |

### Classes and Objects

| Python | Jac | Notes |
|--------|-----|-------|
| `class MyClass:` | `obj MyClass {` | Standard class |
| `class MyClass:` | `class MyClass {` | Python-compatible class |
| `self.attr = value` | `has attr: type = value;` | Instance variables |
| `@staticmethod` | `static can method {` | Static methods |
| `super()` | `super` | Parent class access |
| N/A | `node MyNode {` | Graph node class |
| N/A | `edge MyEdge {` | Graph edge class |
| N/A | `walker MyWalker {` | Walker class |

### Control Flow

| Python | Jac | Notes |
|--------|-----|-------|
| `if x:` | `if x {` | Conditional |
| `elif y:` | `elif y {` | Else-if |
| `else:` | `else {` | Else clause |
| `while condition:` | `while condition {` | While loop |
| `for x in items:` | `for x in items {` | For-in loop |
| `for i in range(n):` | `for i=0 to i<n by i+=1 {` | Explicit counter loop |
| `break` | `break;` | Exit loop |
| `continue` | `continue;` | Skip iteration |
| `match value:` | `match value {` | Pattern matching |

#### Exception Handling

| Python | Jac | Notes |
|--------|-----|-------|
| `try:` | `try {` | Try block |
| `except Exception as e:` | `except Exception as e {` | Catch exception |
| `finally:` | `finally {` | Finally block |
| `raise Exception()` | `raise Exception();` | Raise exception |
| `assert condition` | `assert condition;` | Assertion |

### Data Types

| Python | Jac | Notes |
|--------|-----|-------|
| `list` | `list` | Lists identical |
| `dict` | `dict` | Dictionaries identical |
| `set` | `set` | Sets identical |
| `tuple` | `tuple` | Positional tuples |
| N/A | `(x=1, y=2)` | Keyword tuples |
| `None` | `None` | Null value |
| `True/False` | `True/False` | Booleans identical |

### Operators

| Python | Jac | Notes |
|--------|-----|-------|
| `and` | `and` or `&&` | Logical AND |
| `or` | `or` or `||` | Logical OR |
| `not` | `not` | Logical NOT |
| `is` | `is` | Identity comparison |
| `in` | `in` | Membership test |
| `:=` | `:=` | Walrus operator |
| N/A | `|>` | Pipe forward |
| N/A | `<|` | Pipe backward |
| N/A | `:>` | Atomic pipe forward |
| N/A | `<:` | Atomic pipe backward |

### Imports

| Python | Jac | Notes |
|--------|-----|-------|
| `import module` | `import:py module;` | Python module import |
| `from module import item` | `import:py from module { item };` | Selective import |
| `import module as alias` | `import:py module as alias;` | Import with alias |
| N/A | `import:jac module;` | Jac module import |
| N/A | `include module;` | Include all exports |

#### 20.2 Built-in Functions and Types

### Core Built-in Functions

| Function | Description | Example |
|----------|-------------|---------|
| `print(...)` | Output to console | `print("Hello", name);` |
| `len(obj)` | Get length/size | `len([1, 2, 3])` → `3` |
| `type(obj)` | Get object type | `type(42)` → `int` |
| `isinstance(obj, type)` | Type checking | `isinstance(x, str)` |
| `hasattr(obj, attr)` | Check attribute exists | `hasattr(node, "value")` |
| `getattr(obj, attr)` | Get attribute value | `getattr(node, "value")` |
| `setattr(obj, attr, val)` | Set attribute value | `setattr(node, "value", 42)` |
| `range(start, stop, step)` | Generate number sequence | `range(0, 10, 2)` |
| `enumerate(iterable)` | Get index with items | `enumerate(["a", "b"])` |
| `zip(iter1, iter2, ...)` | Combine iterables | `zip([1, 2], ["a", "b"])` |
| `map(func, iterable)` | Apply function to items | `map(str.upper, ["a", "b"])` |
| `filter(func, iterable)` | Filter items by predicate | `filter(is_even, [1, 2, 3])` |
| `sum(iterable)` | Sum numeric values | `sum([1, 2, 3])` → `6` |
| `min(iterable)` | Find minimum value | `min([3, 1, 4])` → `1` |
| `max(iterable)` | Find maximum value | `max([3, 1, 4])` → `4` |
| `abs(number)` | Absolute value | `abs(-42)` → `42` |
| `round(number, digits)` | Round to digits | `round(3.14159, 2)` → `3.14` |
| `sorted(iterable)` | Sort items | `sorted([3, 1, 4])` → `[1, 3, 4]` |
| `reversed(iterable)` | Reverse items | `reversed([1, 2, 3])` |
| `all(iterable)` | All items truthy | `all([True, True])` → `True` |
| `any(iterable)` | Any item truthy | `any([False, True])` → `True` |

### Type Constructors

| Type | Constructor | Example |
|------|-------------|---------|
| `int` | `int(value)` | `int("42")` → `42` |
| `float` | `float(value)` | `float("3.14")` → `3.14` |
| `str` | `str(value)` | `str(42)` → `"42"` |
| `bool` | `bool(value)` | `bool(1)` → `True` |
| `list` | `list(iterable)` | `list((1, 2, 3))` → `[1, 2, 3]` |
| `tuple` | `tuple(iterable)` | `tuple([1, 2, 3])` → `(1, 2, 3)` |
| `dict` | `dict(pairs)` | `dict([("a", 1)])` → `{"a": 1}` |
| `set` | `set(iterable)` | `set([1, 2, 2])` → `{1, 2}` |

### Object-Spatial Built-ins

| Keyword/Function | Description | Example |
|------------------|-------------|---------|
| `root` | Current user's root node | `root ++> MyNode();` |
| `here` | Walker's current location | `here.process_data();` |
| `visitor` | Current visiting walker | `visitor.report_result();` |
| `spawn` | Activate walker | `spawn MyWalker() on node;` |
| `visit` | Queue traversal destination | `visit [-->];` |
| `disengage` | Terminate walker | `disengage;` |
| `skip` | Skip to next location | `skip;` |
| `report` | Report walker result | `report {"result": 42};` |

### Edge Reference Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `[-->]` | Outgoing edges/nodes | `for n in [-->] { ... }` |
| `[<--]` | Incoming edges/nodes | `for n in [<--] { ... }` |
| `[<-->]` | Bidirectional edges/nodes | `neighbors = [<-->];` |
| `[-->:EdgeType:]` | Typed outgoing edges | `[-->:Follows:]` |
| `[-->(condition)]` | Filtered edges | `[-->(?.weight > 0.5)]` |
| `++>` | Create directed edge | `node1 ++> node2;` |
| `<++` | Create reverse edge | `node1 <++ node2;` |
| `<++>` | Create bidirectional edge | `node1 <++> node2;` |

#### 20.3 Standard Library Overview

### Core Modules

#### `math` - Mathematical Functions
```jac
import:py math;

# Constants
math.pi      # 3.14159...
math.e       # 2.71828...

# Functions
math.sqrt(16)     # 4.0
math.pow(2, 3)    # 8.0
math.sin(math.pi/2)  # 1.0
math.log(10)      # Natural log
```

#### `datetime` - Date and Time
```jac
import:py from datetime { datetime, timedelta };

# Current time
now = datetime.now();
timestamp = now.isoformat();

# Date arithmetic
tomorrow = now + timedelta(days=1);
diff = tomorrow - now;  # timedelta object
```

#### `json` - JSON Handling
```jac
import:py json;

# Serialize
data = {"name": "Jac", "version": 1.0};
json_str = json.dumps(data);

# Deserialize
parsed = json.loads(json_str);
```

#### `random` - Random Numbers
```jac
import:py random;

# Random values
random.random()          # 0.0 to 1.0
random.randint(1, 10)    # 1 to 10 inclusive
random.choice([1, 2, 3]) # Pick from list
random.shuffle(my_list)  # Shuffle in place
```

#### `re` - Regular Expressions
```jac
import:py re;

# Pattern matching
pattern = r"\d+";
matches = re.findall(pattern, "abc123def456");  # ["123", "456"]

# Substitution
result = re.sub(r"\d+", "X", "abc123def");  # "abcXdef"
```

### File Operations

```jac
# Reading files
with open("file.txt", "r") as f {
    content = f.read();
    # or line by line
    for line in f {
        process_line(line.strip());
    }
}

# Writing files
with open("output.txt", "w") as f {
    f.write("Hello, Jac!\n");
    f.write(f"Timestamp: {timestamp_now()}\n");
}

# JSON files
import:py json;
with open("data.json", "r") as f {
    data = json.load(f);
}
```

### Common Patterns Reference

#### Graph Creation Patterns
```jac
# Linear chain
prev = root;
for i in range(5) {
    node = Node(id=i);
    prev ++> node;
    prev = node;
}

# Star topology
hub = root ++> Hub();
for i in range(10) {
    hub ++> Node(id=i);
}

# Fully connected
nodes = [Node(id=i) for i in range(5)];
for i, n1 in enumerate(nodes) {
    for n2 in nodes[i+1:] {
        n1 <++> n2;
    }
}
```

#### Walker Patterns
```jac
# Visitor pattern
walker Visitor {
    can process with Node entry {
        here.visit_count += 1;
        visit [-->];
    }
}

# Collector pattern
walker Collector {
    has items: list = [];

    can collect with entry {
        if matches_criteria(here) {
            self.items.append(here);
        }
        visit [-->];
    }
}

# Transformer pattern
walker Transformer {
    can transform with entry {
        here.value = transform_function(here.value);
        visit [-->];
    }
}
```

#### Error Handling Patterns
```jac
# Safe traversal
walker SafeTraverser {
    can traverse with entry {
        try {
            process_node(here);
            visit [-->];
        } except ProcessingError as e {
            report {"error": str(e), "node": here.id};
            skip;  # Continue to next node
        } except CriticalError as e {
            report {"critical": str(e)};
            disengage;  # Stop traversal
        }
    }
}

# Retry pattern
can retry_operation(func: callable, max_attempts: int = 3) -> any {
    for attempt in range(max_attempts) {
        try {
            return func();
        } except TemporaryError as e {
            if attempt == max_attempts - 1 {
                raise e;
            }
            sleep(2 ** attempt);  # Exponential backoff
        }
    }
}
```

#### Type Checking Patterns
```jac
# Runtime type checking
can process_value(value: any) -> str {
    match type(value) {
        case int: return f"Integer: {value}";
        case str: return f"String: {value}";
        case list: return f"List with {len(value)} items";
        case dict: return f"Dict with keys: {list(value.keys())}";
        case _: return f"Unknown type: {type(value).__name__}";
    }
}

# Node type discrimination
walker TypedProcessor {
    can process with entry {
        match here {
            case UserNode: process_user(here);
            case DataNode: process_data(here);
            case _: visit [-->];  # Skip unknown types
        }
    }
}
```

#### Performance Patterns
```jac
# Lazy evaluation
can lazy_range(start: int, stop: int) {
    current = start;
    while current < stop {
        yield current;
        current += 1;
    }
}

# Memoization
glob memo_cache: dict = {};

can memoized_fibonacci(n: int) -> int {
    if n in memo_cache {
        return memo_cache[n];
    }

    if n <= 1 {
        result = n;
    } else {
        result = memoized_fibonacci(n-1) + memoized_fibonacci(n-2);
    }

    memo_cache[n] = result;
    return result;
}
```

### Quick Conversion Guide

#### Python Class to Jac Node
```python
# Python
class User:
    def __init__(self, name, email):
        self.name = name
        self.email = email
        self.friends = []

    def add_friend(self, other):
        self.friends.append(other)
```

```jac
# Jac
node User {
    has name: str;
    has email: str;
}

edge Friend;

walker AddFriend {
    has other_user: User;

    can add with User entry {
        here ++>:Friend:++> self.other_user;
    }
}
```

#### Python Function to Jac Walker
```python
# Python
def find_users_by_name(graph, name_pattern):
    results = []
    for user in graph.get_all_users():
        if name_pattern in user.name:
            results.append(user)
    return results
```

```jac
# Jac
walker FindUsersByName {
    has name_pattern: str;
    has results: list = [];

    can search with User entry {
        if self.name_pattern in here.name {
            self.results.append(here);
        }
        visit [-->];
    }

    can return_results with `root exit {
        report self.results;
    }
}
```

This quick reference provides the essential syntax mappings and patterns you'll need for day-to-day Jac development. Keep it handy as you transition from Python to Jac's object-spatial paradigm!