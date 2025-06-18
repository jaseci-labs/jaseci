### Chapter 4: Data Structures and Collections

Jac's data structures will feel familiar to Python developers, but they come with enhanced type safety, powerful new operations, and unique features like keyword tuples and pipe operators. This chapter explores how to work with collections effectively in Jac.

#### 4.1 Collections Comparison

### Lists, Tuples, Dicts, Sets - Familiar but Enhanced

Let's start by comparing Python and Jac collections:

```python
# Python - Dynamic typing, flexible but potentially error-prone
numbers = [1, 2, 3]
numbers.append("four")  # Allowed, but might cause issues later

person = ("Alice", 30)  # Simple tuple
scores = {"Alice": 95, "Bob": 87}
tags = {"python", "programming", "tutorial"}
```

```jac
# Jac - Static typing, safe and predictable
let numbers: list[int] = [1, 2, 3];
with entry {
    numbers.append("four");
    print(numbers);
}

let person: tuple = ("Alice", 30);  # Positional tupl
let scores: dict[str, int] = {"Alice": 95, "Bob": 87};
let tags: set[str] = {"python", "programming", "tutorial"};
```

### Working with Lists

Lists in Jac maintain order and allow duplicates, just like Python, but with type safety:

```jac
# List creation and basic operations
let fruits: list[str] = ["apple", "banana", "cherry"];
let numbers: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];

let unique_sorted: list[int] = sorted(set(numbers));  # Remove duplicates and sort → [1, 2, 3, 4, 5, 6, 9]
let subset: list[int] = numbers[2:5];  # Slice → [4, 1, 5]
let reversed: list[int] = numbers[::-1];  # Reverse the list → [6, 2, 9, 5, 1, 4, 1, 3]

with entry {
    fruits.append("date");
    fruits.insert(1, "blueberry");

    print("fruits after update: ", fruits);
    # ['apple', 'blueberry', 'banana', 'cherry', 'date']

    numbers.sort();
    print("numbers sorted: ", numbers);
    # [1, 1, 2, 3, 4, 5, 6, 9]

    print("unique sorted numbers: ", unique_sorted);
    # [1, 2, 3, 4, 5, 6, 9]

    print("subset [2:5]: ", subset);
    # [4, 1, 5]

    print("reversed numbers: ", reversed);
    # [6, 2, 9, 5, 1, 4, 1, 3]
}


# Multi-dimensional lists
let matrix: list[list[int]] = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
];

with entry {
    print("matrix:");
    for row in matrix {
        print(row);
    }

    print("element at [0][1]:", matrix[0][1]);  # 2
    print("element at [2][2]:", matrix[2][2]);  # 9
}
```

### Advanced List Operations

```jac
# List comprehensions with filtering
let numbers: list[int] = range(1, 21);
let evens: list[int] = [n for n in numbers if n % 2 == 0];
let squares: list[int] = [n * n for n in numbers];
let even_squares: list[int] = [n * n for n in numbers if n % 2 == 0];

# Nested comprehensions
let coords: list[tuple] = [(x, y) for x in range(3) for y in range(3)];
# [(0,0), (0,1), (0,2), (1,0), (1,1), (1,2), (2,0), (2,1), (2,2)]

# Functional-style operations
let doubled: list[int] = [x * 2 for x in numbers];
let filtered: list[int] = [x for x in numbers if x > 10];
let total: int = 0;

with entry {
    for x in numbers {
    total += x;
    }
}

# List flattening
let nested: list[list[int]] = [[1, 2], [3, 4], [5, 6]];
let flat: list[int] = [item for sublist in nested for item in sublist];

with entry {
    print("numbers:", list(numbers));
    print("evens:", evens);
    print("squares:", squares);
    print("even_squares:", even_squares);
}

with entry {
    print("coordinates:", coords);
}

with entry {
    print("doubled:", doubled);
    print("filtered (>10):", filtered);
    print("total sum:", total);
}

with entry {
    print("nested:", nested);
    print("flat:", flat);
}
```

### Dictionaries with Type Safety

```jac
# Dictionary creation and manipulation
glob user_scores: dict[str, int] = {
    "Alice": 95,
    "Bob": 87,
    "Charlie": 92
};

# Safe access patterns
glob alice_score: int = user_scores.get("Alice", 0);
glob david_score: int = user_scores.get("David", 0);

# Dictionary comprehensions
glob squared_scores: dict[str, int] = {};

with entry {
    for (name, score) in user_scores.items() {
        squared_scores[name] = score * score;
    }
}

# Nested dictionaries
glob user_profiles: dict[str, dict[str, any]] = {
    "alice": {
        "email": "alice@example.com",
        "age": 30,
        "scores": [95, 87, 91]
    },
    "bob": {
        "email": "bob@example.com",
        "age": 25,
        "scores": [87, 89, 85]
    }
};

# Merging dictionaries
glob defaults: dict[str, any] = {"status": "active", "role": "user"};
glob user_data: dict[str, any] = {"name": "Alice", "role": "admin"};
glob merged: dict[str, any] = {**defaults, **user_data};
```

### Sets for Unique Collections

```jac
# Set operations
let skills_a: set[str] = {"Python", "Jac", "SQL", "Git"};
let skills_b: set[str] = {"Jac", "JavaScript", "Git", "Docker"};

# Set operations
let common: set[str] = skills_a & skills_b;  # {"Jac", "Git"}
let all_skills: set[str] = skills_a | skills_b;  # Union
let unique_to_a: set[str] = skills_a - skills_b;  # {"Python", "SQL"}
let symmetric_diff: set[str] = skills_a ^ skills_b;  # Unique to either

# Set comprehensions
let numbers: set[int] = {x * x for x in range(10) if x % 2 == 0};
# {0, 4, 16, 36, 64}

# Frozen sets (immutable)
let constants: frozenset[str] = frozenset(["PI", "E", "PHI"]);
```

### Special Comprehensions and Filter Syntax

Jac introduces powerful filter comprehensions with null-safety:

```jac
# Special filter syntax for graph operations
node User {
    has name: str;
    has age: int;
    has active: bool;
    has visited: bool = False;  # Default value
    has timestamp: datetime = now();  # Default to current time
}


# Standard filter (may fail on null)
# let active_users = [user for user in users if user.is_active];

# # Null-safe filter with ? operator
# let active_users_safe = [user for user in users if user.is_active];

with entry {
    root ++> User(name= "Alice", age= 30, active= True);
    root ++> User(name= "Bob", age= 17, active= False);
    root ++> User(name= "Charlie", age= 25, active= True);
    root ++> User(name= "Diana", age= 22, active= False);
    root ++> User(name= "Eve", age= 19, active= True);
    root ++> User(name= "Frank", age= 40, active= True);
    root ++> User(name= "Grace", age= 15, active= False);
    root ++> User(name= "Hank", age= 35, active= True);
    root ++> User(name= "Ivy", age= 28, active= False);
    root ++> User(name= "Jack", age= 20, active= True);
}

walker FindActiveAdults {
    can search with entry {
        # Filter nodes with special syntax
        adults = [-->(?age >= 18)];  # Null-safe property access
        active_adults = [-->(?age >= 18, active == True)];
        print("Active adults:", active_adults);
        # Type-specific filtering
        user_nodes = [-->(`?User)];  # Only User nodes
        print("User nodes:", user_nodes);
        typed_adults = [-->(`?User)](?age >= 18);  # Typed + filtered , age >= 18
        print("Typed adults:", typed_adults);
    }
}

# Assignment comprehensions - unique to Jac!
walker UpdateNodes {
    can update with entry {
        # Update all connected nodes
        [-->](=visited: True, =timestamp: now());

        # Conditional update
        [-->(?score < 50)](=needs_review: true);

        # Update specific types
        [-->(`User: ?age >= 18)](=adult: true);
    }
}


with entry {
    root spawn FindActiveAdults();
}
```

#### 4.2 Pipe Operators

### Forward Pipe (`|>`)

Pipe operators transform nested function calls into readable pipelines:

```jac
# Define the data and functions first
glob data: str = "hello world";

def parse(text: str) -> str {
    return f"parsed({text})";
}

def validate(text: str) -> str {
    return f"validated({text})";
}

def transform(text: str) -> str {
    return f"transformed({text})";
}

def process(text: str) -> str {
    return f"processed({text})";
}

with entry {
    # Traditional nested approach (hard to read)
    let result1 = process(transform(validate(parse(data))));
    print("Nested approach:", result1);

    # With forward pipe (left-to-right flow)
    let result2 = data
        |> parse
        |> validate
        |> transform
        |> process;
    print("Forward pipe:", result2);
}
```

### Real-World Pipeline Examples

```jac
import string;

# Data processing pipeline
def clean_text(text: str) -> str {
    return text.strip().lower();
}

def remove_punctuation(text: str) -> str {
    return "".join([c for c in text if c not in string.punctuation]);
}

def tokenize(text: str) -> list[str] {
    return text.split();
}

def remove_stopwords(words: list[str]) -> list[str] {
    let stopwords = {"the", "a", "an", "and", "or", "but", "in", "on", "at"};
    return [w for w in words if w not in stopwords];
}

walker TextProcessingPipeline {
    has text: str;

    can clean_text with entry {
        self.text = clean_text(self.text);
        print("After cleaning:", self.text);
    }
    can remove_punctuation with entry {
        self.text = remove_punctuation(self.text);
        print("After removing punctuation:", self.text);
    }
    can tokenize with entry {
        self.tokens = tokenize(self.text);
        print("After tokenizing:", self.tokens);
    }
    can remove_stopwords with entry {
        self.tokens = remove_stopwords(self.tokens);
        print("After removing stopwords:", self.tokens);
    }
}

# Using the pipeline
with entry {
    raw_text = "  The Quick Brown Fox Jumps Over the Lazy Dog!  ";
    text_processor = root spawn TextProcessingPipeline(text=raw_text);
    processed = text_processor.tokens;
    print("Raw text:", raw_text);
    print("Processed tokens:", processed);  # ["quick", "brown", "fox", "jumps", "over", "lazy", "dog"]
}
```

### Atomic Pipes (`:>` and `<:`)

Atomic pipes have higher precedence for tighter binding:

```jac
# Standard pipe vs atomic pipe precedence
let data = [1, 2, 3, 4, 5];

# Standard pipe (lower precedence)
let result1 = data |> sum |> str;  # "15"

# Atomic pipe (higher precedence)
let result2 = data :> filter(lambda x: int -> bool : x > 2) :> sum;  # 12

# Mixing operators (atomic binds tighter)
let result3 = data
    :> filter(lambda x: int -> bool : x % 2 == 0)  # [2, 4]
    |> sum  # 6
    |> lambda x: int -> str : f"Sum: {x}";  # "Sum: 6"
```

### Replacing Nested Function Calls

```jac
# Complex nested calls (traditional)
can traditional_approach(users: list[User]) -> dict[str, list[str]] {
    return group_by(
        map(
            lambda u: User -> tuple : (u.department, u.name),
            filter(
                lambda u: User -> bool : u.active and u.age >= 18,
                sort(users, key=lambda u: User -> str : u.name)
            )
        ),
        key=lambda t: tuple -> str : t[0]
    );
}

# Same logic with pipes (much clearer!)
can piped_approach(users: list[User]) -> dict[str, list[str]] {
    return users
        |> sort(key=lambda u: User -> str : u.name)
        |> filter(lambda u: User -> bool : u.active and u.age >= 18)
        |> map(lambda u: User -> tuple : (u.department, u.name))
        |> group_by(key=lambda t: tuple -> str : t[0]);
}
```

### Integration with Method Chaining

```jac
# Combining pipes with method chaining
obj DataProcessor {
    has data: list[dict[str, any]];

    can filter_by(key: str, value: any) -> DataProcessor {
        self.data = [d for d in self.data if d.get(key) == value];
        return self;
    }

    can sort_by(key: str) -> DataProcessor {
        self.data.sort(key=lambda d: dict -> any : d.get(key, 0));
        return self;
    }

    can transform(func: callable) -> DataProcessor {
        self.data = [func(d) for d in self.data];
        return self;
    }

    can get_results() -> list[dict[str, any]] {
        return self.data;
    }
}

# Using pipes with methods
let processor = DataProcessor(data=raw_data);
let results = processor
    |> .filter_by("status", "active")
    |> .sort_by("priority")
    |> .transform(lambda d: dict -> dict : {**d, "processed": true})
    |> .get_results();

# Or with method chaining directly
let results2 = processor
    .filter_by("status", "active")
    .sort_by("priority")
    .transform(lambda d: dict -> dict : {**d, "processed": true})
    .get_results();
```

### Advanced Pipeline Patterns

```jac
# Error handling in pipelines
can safe_pipeline[T, R](
    data: T,
    *funcs: list[callable]
) -> R? {
    try {
        let result: any = data;
        for func in funcs {
            result = func(result);
        }
        return result;
    } except Exception as e {
        print(f"Pipeline failed: {e}");
        return None;
    }
}

# Conditional pipelines
can process_user_data(user: User) -> dict {
    let base_pipeline = user
        |> validate_user
        |> normalize_data;

    # Conditional continuation
    if user.age >= 18 {
        return base_pipeline
            |> apply_adult_rules
            |> generate_full_profile;
    } else {
        return base_pipeline
            |> apply_minor_rules
            |> generate_restricted_profile;
    }
}

# Parallel pipelines
can parallel_process(items: list[any]) -> list[any] {
    import:py from concurrent.futures { ThreadPoolExecutor }

    can process_item(item: any) -> any {
        return item
            |> validate
            |> transform
            |> enrich;
    }

    with ThreadPoolExecutor() as executor {
        return list(executor.map(process_item, items));
    }
}
```

### Collection Pipeline Patterns

```jac
# Common collection transformations
let numbers: list[int] = range(1, 101);

# Statistical pipeline
let stats = numbers
    |> filter(lambda n: int -> bool : n % 2 == 0)  # Even numbers
    |> map(lambda n: int -> float : n ** 0.5)      # Square roots
    |> sorted                                        # Sort
    |> lambda lst: list -> tuple : (                # Create stats tuple
        min=lst[0],
        max=lst[-1],
        median=lst[len(lst)#2],
        mean=sum(lst)/len(lst)
    );

# Text processing pipeline
let words: list[str] = ["hello", "WORLD", "jAc", "PYTHON"];
let processed = words
    |> map(str.lower)                               # Lowercase all
    |> filter(lambda w: str -> bool : len(w) > 3)  # Keep long words
    |> sorted                                        # Alphabetize
    |> lambda lst: list -> dict : {                 # Group by first letter
        letter: [w for w in lst if w[0] == letter]
        for letter in set(w[0] for w in lst)
    };
```

### Pipes in Object-Spatial Context

```jac
# Using pipes with graph operations
walker DataAggregator {
    has process_node: callable;
    has combine_results: callable;

    can aggregate with entry {
        let results = [-->]                          # Get connected nodes
            |> filter(lambda n: node -> bool : n.has_data())
            |> map(self.process_node)                # Process each node
            |> filter(lambda r: any -> bool : r is not None)
            |> self.combine_results;                 # Combine all results

        report results;
    }
}

# Node data extraction pipeline
node DataNode {
    has raw_data: dict;
    has metadata: dict;

    can extract_info with Extractor entry {
        let info = self.raw_data
            |> validate_structure
            |> extract_fields(visitor.required_fields)
            |> apply_transformations(visitor.transforms)
            |> add_metadata(self.metadata);

        visitor.collect(info);
    }
}
```

### Best Practices for Collections and Pipes

1. **Type Your Collections**: Always specify element types
   ```jac
   let numbers: list[int] = [1, 2, 3];  # Good
   # let numbers = [1, 2, 3];          # Bad - missing type
   ```

2. **Use Keyword Tuples for Multiple Returns**: Clearer than positional
   ```jac
   return (success=true, data=result, errors=[]);  # Good
   return (true, result, []);                       # Less clear
   ```

3. **Build Pipelines Incrementally**: Test each stage
   ```jac
   # Debug by breaking pipeline
   let step1 = data |> clean;
   print(f"After clean: {step1}");
   let step2 = step1 |> validate;
   print(f"After validate: {step2}");
   ```

4. **Prefer Pipes Over Nesting**: For readability
   ```jac
   # Good
   result = data |> process |> transform |> format;

   # Avoid
   result = format(transform(process(data)));
   ```

5. **Use Comprehensions for Filtering**: More efficient than loops
   ```jac
   # Good
   adults = [u for u in users if u.age >= 18];

   # Less efficient
   adults = [];
   for u in users {
       if u.age >= 18 { adults.append(u); }
   }
   ```

### Summary

In this chapter, we've explored Jac's powerful collection features:

- **Type-safe collections** that prevent runtime errors
- **Special comprehensions** with null-safety and assignment operations
- **Keyword tuples** that combine structure with flexibility
- **Pipe operators** that transform nested calls into readable flows

These features work together to make data manipulation in Jac both safer and more expressive than traditional approaches. The combination of static typing and functional pipeline patterns creates code that is both robust and maintainable.

Next, we'll explore how Jac enhances object-oriented programming with archetypes, automatic constructors, and implementation separation—features that make large-scale development more manageable.