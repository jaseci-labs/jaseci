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
// Jac - Static typing, safe and predictable
let numbers: list[int] = [1, 2, 3];
// numbers.append("four");  // Compile error: type mismatch

let person: tuple = ("Alice", 30);  // Positional tuple
let person_kw: tuple = (name="Alice", age=30);  // Keyword tuple!
let scores: dict[str, int] = {"Alice": 95, "Bob": 87};
let tags: set[str] = {"python", "programming", "tutorial"};
```

### Working with Lists

Lists in Jac maintain order and allow duplicates, just like Python, but with type safety:

```jac
// List creation and basic operations
let fruits: list[str] = ["apple", "banana", "cherry"];
fruits.append("date");
fruits.insert(1, "blueberry");
print(fruits);  // ["apple", "blueberry", "banana", "cherry", "date"]

// List methods with type safety
let numbers: list[int] = [3, 1, 4, 1, 5, 9, 2, 6];
numbers.sort();  // In-place sort
let unique_sorted: list[int] = sorted(set(numbers));  // Remove duplicates and sort

// Slicing works like Python
let subset: list[int] = numbers[2:5];  // [2, 3, 4]
let reversed: list[int] = numbers[::-1];  // Reverse the list

// Multi-dimensional lists
let matrix: list[list[int]] = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
];

// Safe access with bounds checking
can safe_get[T](lst: list[T], index: int, default: T) -> T {
    if 0 <= index < len(lst) {
        return lst[index];
    }
    return default;
}
```

### Advanced List Operations

```jac
// List comprehensions with filtering
let numbers: list[int] = range(1, 21);
let evens: list[int] = [n for n in numbers if n % 2 == 0];
let squares: list[int] = [n * n for n in numbers];
let even_squares: list[int] = [n * n for n in numbers if n % 2 == 0];

// Nested comprehensions
let coords: list[tuple] = [(x, y) for x in range(3) for y in range(3)];
// [(0,0), (0,1), (0,2), (1,0), (1,1), (1,2), (2,0), (2,1), (2,2)]

// Functional operations
let doubled: list[int] = numbers.map(lambda x: int -> int : x * 2);
let filtered: list[int] = numbers.filter(lambda x: int -> bool : x > 10);
let total: int = numbers.reduce(lambda a: int, b: int -> int : a + b, 0);

// List flattening
let nested: list[list[int]] = [[1, 2], [3, 4], [5, 6]];
let flat: list[int] = [item for sublist in nested for item in sublist];
```

### Dictionaries with Type Safety

```jac
// Dictionary creation and manipulation
let user_scores: dict[str, int] = {
    "Alice": 95,
    "Bob": 87,
    "Charlie": 92
};

// Safe access patterns
let alice_score: int = user_scores.get("Alice", 0);  // Default value
let david_score: int = user_scores.get("David", 0);  // Returns 0

// Dictionary comprehensions
let squared_scores: dict[str, int] = {
    name: score * score for name, score in user_scores.items()
};

// Nested dictionaries
let user_profiles: dict[str, dict[str, any]] = {
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

// Merging dictionaries
let defaults: dict[str, any] = {"status": "active", "role": "user"};
let user_data: dict[str, any] = {"name": "Alice", "role": "admin"};
let merged: dict[str, any] = {**defaults, **user_data};
// {"status": "active", "role": "admin", "name": "Alice"}
```

### Sets for Unique Collections

```jac
// Set operations
let skills_a: set[str] = {"Python", "Jac", "SQL", "Git"};
let skills_b: set[str] = {"Jac", "JavaScript", "Git", "Docker"};

// Set operations
let common: set[str] = skills_a & skills_b;  // {"Jac", "Git"}
let all_skills: set[str] = skills_a | skills_b;  // Union
let unique_to_a: set[str] = skills_a - skills_b;  // {"Python", "SQL"}
let symmetric_diff: set[str] = skills_a ^ skills_b;  // Unique to either

// Set comprehensions
let numbers: set[int] = {x * x for x in range(10) if x % 2 == 0};
// {0, 4, 16, 36, 64}

// Frozen sets (immutable)
let constants: frozenset[str] = frozenset(["PI", "E", "PHI"]);
```

### Special Comprehensions and Filter Syntax

Jac introduces powerful filter comprehensions with null-safety:

```jac
// Standard filter (may fail on null)
let active_users = [user for user in users if user.is_active];

// Null-safe filter with ? operator
let active_users_safe = [user for user in users if ?user.is_active];

// Special filter syntax for graph operations
node User {
    has name: str;
    has age: int;
    has active: bool;
}

walker FindActiveAdults {
    can search with entry {
        // Filter nodes with special syntax
        let adults = [-->(?age >= 18)];  // Null-safe property access
        let active_adults = [-->(?age >= 18, ?active == true)];

        // Type-specific filtering
        let user_nodes = [-->(`User)];  // Only User nodes
        let typed_adults = [-->(`User: ?age >= 18)];  // Typed + filtered
    }
}

// Assignment comprehensions - unique to Jac!
walker UpdateNodes {
    can update with entry {
        // Update all connected nodes
        [-->](=visited: true, =timestamp: now());

        // Conditional update
        [-->(?score < 50)](=needs_review: true);

        // Update specific types
        [-->(`User: ?age >= 18)](=adult: true);
    }
}
```

### Keyword Tuples - Jac's Unique Feature

One of Jac's most innovative features is keyword tuples, which combine the immutability of tuples with the clarity of named fields:

```jac
// Traditional positional tuple (like Python)
let point_2d: tuple = (3, 4);
let x: int = point_2d[0];  // Access by index

// Keyword tuple - Jac's innovation!
let point_named: tuple = (x=3, y=4);
let x_coord: int = point_named.x;  // Access by name!
let y_coord: int = point_named["y"];  // Also works

// Mixed tuples (positional followed by keyword)
let mixed: tuple = (100, 200, label="origin", visible=true);
print(mixed[0]);  // 100 (positional)
print(mixed.label);  // "origin" (keyword)

// Practical example: Database results
can fetch_user(id: int) -> tuple {
    // Simulate database fetch
    return (
        id=id,
        name="Alice Smith",
        email="alice@example.com",
        created_at="2024-01-15",
        active=true
    );
}

with entry {
    let user = fetch_user(123);
    print(f"User: {user.name} ({user.email})");
    print(f"Active: {user.active}");
}
```

### Keyword Tuples in Practice

```jac
// Function returning multiple named values
can calculate_stats(data: list[float]) -> tuple {
    let total = sum(data);
    let count = len(data);
    let avg = total / count if count > 0 else 0.0;

    return (
        mean=avg,
        sum=total,
        count=count,
        min=min(data) if data else 0.0,
        max=max(data) if data else 0.0
    );
}

// Using the results
let scores: list[float] = [85.5, 92.0, 78.5, 95.0, 88.0];
let stats = calculate_stats(scores);

print(f"Average: {stats.mean:.2f}");
print(f"Range: {stats.min} - {stats.max}");

// Keyword tuples in data structures
let employees: list[tuple] = [
    (id=1, name="Alice", dept="Engineering", salary=95000),
    (id=2, name="Bob", dept="Marketing", salary=75000),
    (id=3, name="Charlie", dept="Engineering", salary=105000)
];

// Easy filtering and processing
let engineers = [emp for emp in employees if emp.dept == "Engineering"];
let high_earners = [emp for emp in employees if emp.salary > 80000];
let total_salary = sum([emp.salary for emp in employees]);
```

#### 4.2 Pipe Operators

### Forward Pipe (`|>`) and Backward Pipe (`<|`)

Pipe operators transform nested function calls into readable pipelines:

```jac
// Traditional nested approach (hard to read)
let result = process(transform(validate(parse(data))));

// With forward pipe (left-to-right flow)
let result = data
    |> parse
    |> validate
    |> transform
    |> process;

// Backward pipe (right-to-left flow)
let result = process
    <| transform
    <| validate
    <| parse
    <| data;
```

### Real-World Pipeline Examples

```jac
// Data processing pipeline
can clean_text(text: str) -> str {
    return text.strip().lower();
}

can remove_punctuation(text: str) -> str {
    import:py string;
    return "".join([c for c in text if c not in string.punctuation]);
}

can tokenize(text: str) -> list[str] {
    return text.split();
}

can remove_stopwords(words: list[str]) -> list[str] {
    let stopwords = {"the", "a", "an", "and", "or", "but", "in", "on", "at"};
    return [w for w in words if w not in stopwords];
}

// Using the pipeline
let raw_text = "  The Quick Brown Fox Jumps Over the Lazy Dog!  ";
let processed = raw_text
    |> clean_text
    |> remove_punctuation
    |> tokenize
    |> remove_stopwords;

print(processed);  // ["quick", "brown", "fox", "jumps", "over", "lazy", "dog"]
```

### Atomic Pipes (`:>` and `<:`)

Atomic pipes have higher precedence for tighter binding:

```jac
// Standard pipe vs atomic pipe precedence
let data = [1, 2, 3, 4, 5];

// Standard pipe (lower precedence)
let result1 = data |> sum |> str;  // "15"

// Atomic pipe (higher precedence)
let result2 = data :> filter(lambda x: int -> bool : x > 2) :> sum;  // 12

// Mixing operators (atomic binds tighter)
let result3 = data
    :> filter(lambda x: int -> bool : x % 2 == 0)  // [2, 4]
    |> sum  // 6
    |> lambda x: int -> str : f"Sum: {x}";  // "Sum: 6"
```

### Replacing Nested Function Calls

```jac
// Complex nested calls (traditional)
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

// Same logic with pipes (much clearer!)
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
// Combining pipes with method chaining
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

// Using pipes with methods
let processor = DataProcessor(data=raw_data);
let results = processor
    |> .filter_by("status", "active")
    |> .sort_by("priority")
    |> .transform(lambda d: dict -> dict : {**d, "processed": true})
    |> .get_results();

// Or with method chaining directly
let results2 = processor
    .filter_by("status", "active")
    .sort_by("priority")
    .transform(lambda d: dict -> dict : {**d, "processed": true})
    .get_results();
```

### Pipes with Keyword Tuples

Keyword tuples work beautifully with pipe operators:

```jac
// Pipeline returning keyword tuple
can analyze_text(text: str) -> tuple {
    let words = text.split();
    let chars = len(text);
    let lines = text.count("\n") + 1;

    return (
        word_count=len(words),
        char_count=chars,
        line_count=lines,
        avg_word_length=chars / len(words) if words else 0
    );
}

// Function that accepts keyword tuple
can format_analysis(stats: tuple) -> str {
    return f"""
    Text Analysis:
    - Words: {stats.word_count}
    - Characters: {stats.char_count}
    - Lines: {stats.line_count}
    - Avg Word Length: {stats.avg_word_length:.1f}
    """;
}

// Using pipes to flow data
let report = read_file("document.txt")
    |> analyze_text
    |> format_analysis
    |> print;
```

### Advanced Pipeline Patterns

```jac
// Error handling in pipelines
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

// Conditional pipelines
can process_user_data(user: User) -> dict {
    let base_pipeline = user
        |> validate_user
        |> normalize_data;

    // Conditional continuation
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

// Parallel pipelines
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
// Common collection transformations
let numbers: list[int] = range(1, 101);

// Statistical pipeline
let stats = numbers
    |> filter(lambda n: int -> bool : n % 2 == 0)  // Even numbers
    |> map(lambda n: int -> float : n ** 0.5)      // Square roots
    |> sorted                                        // Sort
    |> lambda lst: list -> tuple : (                // Create stats tuple
        min=lst[0],
        max=lst[-1],
        median=lst[len(lst)//2],
        mean=sum(lst)/len(lst)
    );

// Text processing pipeline
let words: list[str] = ["hello", "WORLD", "jAc", "PYTHON"];
let processed = words
    |> map(str.lower)                               // Lowercase all
    |> filter(lambda w: str -> bool : len(w) > 3)  // Keep long words
    |> sorted                                        // Alphabetize
    |> lambda lst: list -> dict : {                 // Group by first letter
        letter: [w for w in lst if w[0] == letter]
        for letter in set(w[0] for w in lst)
    };
```

### Pipes in Object-Spatial Context

```jac
// Using pipes with graph operations
walker DataAggregator {
    has process_node: callable;
    has combine_results: callable;

    can aggregate with entry {
        let results = [-->]                          // Get connected nodes
            |> filter(lambda n: node -> bool : n.has_data())
            |> map(self.process_node)                // Process each node
            |> filter(lambda r: any -> bool : r is not None)
            |> self.combine_results;                 // Combine all results

        report results;
    }
}

// Node data extraction pipeline
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
   let numbers: list[int] = [1, 2, 3];  // Good
   // let numbers = [1, 2, 3];          // Bad - missing type
   ```

2. **Use Keyword Tuples for Multiple Returns**: Clearer than positional
   ```jac
   return (success=true, data=result, errors=[]);  // Good
   return (true, result, []);                       // Less clear
   ```

3. **Build Pipelines Incrementally**: Test each stage
   ```jac
   // Debug by breaking pipeline
   let step1 = data |> clean;
   print(f"After clean: {step1}");
   let step2 = step1 |> validate;
   print(f"After validate: {step2}");
   ```

4. **Prefer Pipes Over Nesting**: For readability
   ```jac
   // Good
   result = data |> process |> transform |> format;

   // Avoid
   result = format(transform(process(data)));
   ```

5. **Use Comprehensions for Filtering**: More efficient than loops
   ```jac
   // Good
   adults = [u for u in users if u.age >= 18];

   // Less efficient
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