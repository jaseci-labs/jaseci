# Chapter 4: Functions and Decorators

Jac provides a powerful function system with mandatory type annotations, decorators, and first-class support for functional programming patterns. This chapter builds a math functions library with timing capabilities to demonstrate these features.

!!! topic "Function Philosophy"
    In Jac, functions are first-class citizens with mandatory typing that prevents runtime errors and improves code clarity.

## Function Definitions with Type Safety

### Basic Math Functions

!!! example "Basic Function Definitions"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic math functions with mandatory types
        def add(a: float, b: float) -> float {
            return a + b;
        }

        def multiply(a: float, b: float) -> float {
            return a * b;
        }

        def power(base: float, exponent: float) -> float {
            return base ** exponent;
        }

        # Function with error handling
        def safe_divide(a: float, b: float) -> float | None {
            if b == 0.0 {
                return None;
            }
            return a / b;
        }

        with entry {
            print(f"5 + 3 = {add(5.0, 3.0)}");
            print(f"4 * 6 = {multiply(4.0, 6.0)}");
            print(f"2^3 = {power(2.0, 3.0)}");
            print(f"10 / 2 = {safe_divide(10.0, 2.0)}");
            print(f"10 / 0 = {safe_divide(10.0, 0.0)}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Optional

        # Python functions with optional type hints
        def add(a: float, b: float) -> float:
            return a + b

        def multiply(a: float, b: float) -> float:
            return a * b

        def power(base: float, exponent: float) -> float:
            return base ** exponent

        # Function with error handling
        def safe_divide(a: float, b: float) -> Optional[float]:
            if b == 0.0:
                return None
            return a / b

        if __name__ == "__main__":
            print(f"5 + 3 = {add(5.0, 3.0)}")
            print(f"4 * 6 = {multiply(4.0, 6.0)}")
            print(f"2^3 = {power(2.0, 3.0)}")
            print(f"10 / 2 = {safe_divide(10.0, 2.0)}")
            print(f"10 / 0 = {safe_divide(10.0, 0.0)}")
        ```

### Advanced Math Functions

!!! topic "Complex Calculations"
    Build more sophisticated mathematical operations using Jac's type system.

!!! example "Advanced Mathematical Operations"
    === "Jac"
        <div class="code-block">
        ```jac
        # More complex math functions
        def factorial(n: int) -> int {
            if n <= 1 {
                return 1;
            }
            return n * factorial(n - 1);
        }

        def fibonacci(n: int) -> int {
            if n <= 1 {
                return n;
            }
            return fibonacci(n - 1) + fibonacci(n - 2);
        }

        def calculate_statistics(numbers: list[float]) -> dict[str, float] {
            if len(numbers) == 0 {
                return {"mean": 0.0, "sum": 0.0, "count": 0.0};
            }

            total = sum(numbers);
            count = len(numbers);
            mean = total / count;

            return {
                "sum": total,
                "count": float(count),
                "mean": mean
            };
        }

        with entry {
            print(f"5! = {factorial(5)}");
            print(f"Fibonacci(10) = {fibonacci(10)}");

            test_numbers = [1.0, 2.0, 3.0, 4.0, 5.0];
            stats = calculate_statistics(test_numbers);
            print(f"Statistics: {stats}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict

        # More complex math functions
        def factorial(n: int) -> int:
            if n <= 1:
                return 1
            return n * factorial(n - 1)

        def fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return fibonacci(n - 1) + fibonacci(n - 2)

        def calculate_statistics(numbers: List[float]) -> Dict[str, float]:
            if len(numbers) == 0:
                return {"mean": 0.0, "sum": 0.0, "count": 0.0}

            total = sum(numbers)
            count = len(numbers)
            mean = total / count

            return {
                "sum": total,
                "count": float(count),
                "mean": mean
            }

        if __name__ == "__main__":
            print(f"5! = {factorial(5)}")
            print(f"Fibonacci(10) = {fibonacci(10)}")

            test_numbers = [1.0, 2.0, 3.0, 4.0, 5.0]
            stats = calculate_statistics(test_numbers)
            print(f"Statistics: {stats}")
        ```

## Decorators for Enhanced Functionality

!!! topic "Decorators"
    Decorators provide a clean way to add functionality to functions without modifying their core logic.

### Timing Decorator

!!! example "Performance Timing Decorator"
    === "Jac"
        <div class="code-block">
        ```jac
        import time;

        # Timing decorator to measure function performance
        def timing_decorator(func: callable) -> callable {
            def wrapper(*args: any, **kwargs: any) -> any {
                start_time = time.time();
                result = func(*args, **kwargs);
                end_time = time.time();
                execution_time = end_time - start_time;
                print(f"{func.__name__} executed in {execution_time} seconds");
                return result;
            }
            return wrapper;
        }

        # Apply timing to our math functions
        @timing_decorator
        def slow_fibonacci(n: int) -> int {
            if n <= 1 {
                return n;
            }
            return slow_fibonacci(n - 1) + slow_fibonacci(n - 2);
        }

        @timing_decorator
        def slow_factorial(n: int) -> int {
            if n <= 1 {
                return 1;
            }
            return n * slow_factorial(n - 1);
        }

        with entry {
            print("=== Timing Decorator Demo ===");
            result1 = slow_fibonacci(2);
            print(f"Fibonacci(2) = {result1}");

            result2 = slow_factorial(3);
            print(f"Factorial(3) = {result2}");
        }
        ```
        </div>
    === "Python"
        ```python
        import time
        from typing import Callable, Any
        from functools import wraps

        # Timing decorator to measure function performance
        def timing_decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(*args: Any, **kwargs: Any) -> Any:
                start_time = time.time()
                result = func(*args, **kwargs)
                end_time = time.time()
                execution_time = end_time - start_time
                print(f"{func.__name__} executed in {execution_time:.4f} seconds")
                return result
            return wrapper

        # Apply timing to our math functions
        @timing_decorator
        def slow_fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return slow_fibonacci(n - 1) + slow_fibonacci(n - 2)

        @timing_decorator
        def slow_factorial(n: int) -> int:
            if n <= 1:
                return 1
            return n * slow_factorial(n - 1)

        if __name__ == "__main__":
            print("=== Timing Decorator Demo ===")
            result1 = slow_fibonacci(2)
            print(f"Fibonacci(2) = {result1}")

            result2 = slow_factorial(3)
            print(f"Factorial(3) = {result2}")
        ```

### Caching Decorator for Optimization

!!! example "Memoization Decorator"
    === "Jac"
        <div class="code-block">
        ```jac
        import time;

        # Timing decorator to measure function performance
        def timing_decorator(func: callable) -> callable {
            def wrapper(*args: any, **kwargs: any) -> any {
                start_time = time.time();
                result = func(*args, **kwargs);
                end_time = time.time();
                execution_time = end_time - start_time;
                print(f"{func.__name__} executed in {execution_time} seconds");
                return result;
            }
            return wrapper;
        }

        # Caching decorator for expensive computations
        def cache_decorator(func: callable) -> callable {
            cache: dict[str, any] = {};

            def wrapper(*args: any) -> any {
                # Create a simple cache key from arguments
                cache_key = str(args);

                if cache_key in cache {
                    print(f"Cache hit for {func.__name__}{args}");
                    return cache[cache_key];
                }

                print(f"Computing {func.__name__}{args}");
                result = func(*args);
                cache[cache_key] = result;
                return result;
            }
            return wrapper;
        }

        # Combine timing and caching decorators
        @timing_decorator
        @cache_decorator
        def optimized_fibonacci(n: int) -> int {
            if n <= 1 {
                return n;
            }
            return optimized_fibonacci(n - 1) + optimized_fibonacci(n - 2);
        }

        @timing_decorator
        @cache_decorator
        def expensive_calculation(n: int) -> int {
            # Simulate expensive computation
            result = 0;
            for i in range(n * 1000) {
                result += i;
            }
            return result;
        }

        with entry {
            print("=== Cached Functions Demo ===");

            # First call - computed and cached
            result1 = optimized_fibonacci(3);
            print(f"Fibonacci(3) = {result1}");

            # Second call - retrieved from cache
            result2 = optimized_fibonacci(3);
            print(f"Fibonacci(3) again = {result2}");

            # Expensive calculation test
            result3 = expensive_calculation(10);
            print(f"Expensive calculation result: {result3}");

            # Second call to expensive calculation
            result4 = expensive_calculation(10);
            print(f"Expensive calculation again: {result4}");
        }
        ```
        </div>
    === "Python"
        ```python
        import time
        from typing import Callable, Any, Dict
        from functools import wraps

        # Caching decorator for expensive computations
        def cache_decorator(func: Callable) -> Callable:
            cache: Dict[str, Any] = {}

            @wraps(func)
            def wrapper(*args: Any) -> Any:
                # Create a simple cache key from arguments
                cache_key = str(args)

                if cache_key in cache:
                    print(f"Cache hit for {func.__name__}{args}")
                    return cache[cache_key]

                print(f"Computing {func.__name__}{args}")
                result = func(*args)
                cache[cache_key] = result
                return result
            return wrapper

        # Combine timing and caching decorators
        @timing_decorator
        @cache_decorator
        def optimized_fibonacci(n: int) -> int:
            if n <= 1:
                return n
            return optimized_fibonacci(n - 1) + optimized_fibonacci(n - 2)

        @timing_decorator
        @cache_decorator
        def expensive_calculation(n: int) -> int:
            # Simulate expensive computation
            result = 0
            for i in range(n * 1000):
                result += i
            return result

        if __name__ == "__main__":
            print("=== Cached Functions Demo ===")

            # First call - computed and cached
            result1 = optimized_fibonacci(3)
            print(f"Fibonacci(3) = {result1}")

            # Second call - retrieved from cache
            result2 = optimized_fibonacci(3)
            print(f"Fibonacci(3) again = {result2}")

            # Expensive calculation test
            result3 = expensive_calculation(10)
            print(f"Expensive calculation result: {result3}")

            # Second call to expensive calculation
            result4 = expensive_calculation(10)
            print(f"Expensive calculation again: {result4}")
        ```

## Lambda Functions and Functional Programming

!!! topic "Functional Programming"
    Lambda functions provide a concise way to create small, focused functions for data processing.

### Lambda Functions for Data Processing

!!! example "Lambda Functions in Data Processing"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Basic lambda functions for math operations
            square = lambda x: float: x * x;
            double = lambda x: float: x * 2;
            is_even = lambda x: int: x % 2 == 0;

            # Test basic lambdas
            print(f"square(5) = {square(5.0)}");
            print(f"double(7) = {double(7.0)}");
            print(f"is_even(4) = {is_even(4)}");

            # Using lambdas with lists
            numbers = [1.0, 2.0, 3.0, 4.0, 5.0];

            # Map operations
            squared_numbers = [square(x) for x in numbers];
            doubled_numbers = [double(x) for x in numbers];

            print(f"Original: {numbers}");
            print(f"Squared: {squared_numbers}");
            print(f"Doubled: {doubled_numbers}");

            # Filter operations
            int_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            even_numbers = [x for x in int_numbers if is_even(x)];
            print(f"Even numbers: {even_numbers}");
        }
        ```
        </div>
    === "Python"
        ```python
        if __name__ == "__main__":
            # Basic lambda functions for math operations
            square = lambda x: x * x
            double = lambda x: x * 2
            is_even = lambda x: x % 2 == 0

            # Test basic lambdas
            print(f"square(5) = {square(5.0)}")
            print(f"double(7) = {double(7.0)}")
            print(f"is_even(4) = {is_even(4)}")

            # Using lambdas with lists
            numbers = [1.0, 2.0, 3.0, 4.0, 5.0]

            # Map operations
            squared_numbers = [square(x) for x in numbers]
            doubled_numbers = [double(x) for x in numbers]

            print(f"Original: {numbers}")
            print(f"Squared: {squared_numbers}")
            print(f"Doubled: {doubled_numbers}")

            # Filter operations
            int_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            even_numbers = [x for x in int_numbers if is_even(x)]
            print(f"Even numbers: {even_numbers}")
        ```

### Higher-Order Functions

!!! example "Functions that Work with Functions"
    === "Jac"
        <div class="code-block">
        ```jac
        # Higher-order function that applies operation to list
        def apply_operation(numbers: list[float], operation: callable[[float], float]) -> list[float] {
            return [operation(num) for num in numbers];
        }

        # Function that creates specialized functions
        def create_multiplier(factor: float) -> callable[[float], float] {
            return lambda x: float: x * factor;
        }

        # Function composition
        def compose(f: callable, g: callable) -> callable {
            return lambda x: any: f(g(x));
        }

        # Reduce-like function
        def reduce_list(numbers: list[float], operation: callable[[float, float], float], initial: float) -> float {
            result = initial;
            for num in numbers {
                result = operation(result, num);
            }
            return result;
        }

        with entry {
            print("=== Higher-Order Functions Demo ===");

            numbers = [1.0, 2.0, 3.0, 4.0, 5.0];

            # Create specialized multiplier functions
            triple = create_multiplier(3.0);
            quadruple = create_multiplier(4.0);

            # Apply operations
            tripled = apply_operation(numbers, triple);
            quadrupled = apply_operation(numbers, quadruple);

            print(f"Original: {numbers}");
            print(f"Tripled: {tripled}");
            print(f"Quadrupled: {quadrupled}");

            # Function composition
            add_one = lambda x: float: x + 1.0;
            square_func = lambda x: float: x * x;
            add_then_square = compose(square_func, add_one);

            result = add_then_square(4.0);  # (4 + 1)^2 = 25
            print(f"(4 + 1)^2 = {result}");

            # Reduce operations
            sum_result = reduce_list(numbers, lambda a:float, b: float: a + b, 0.0);
            product_result = reduce_list(numbers, lambda a:float, b: float: a * b, 1.0);

            print(f"Sum: {sum_result}");
            print(f"Product: {product_result}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Callable

        # Higher-order function that applies operation to list
        def apply_operation(numbers: List[float], operation: Callable[[float], float]) -> List[float]:
            return [operation(num) for num in numbers]

        # Function that creates specialized functions
        def create_multiplier(factor: float) -> Callable[[float], float]:
            return lambda x: x * factor

        # Function composition
        def compose(f: Callable, g: Callable) -> Callable:
            return lambda x: f(g(x))

        # Reduce-like function
        def reduce_list(numbers: List[float], operation: Callable[[float, float], float], initial: float) -> float:
            result = initial
            for num in numbers:
                result = operation(result, num)
            return result

        if __name__ == "__main__":
            print("=== Higher-Order Functions Demo ===")

            numbers = [1.0, 2.0, 3.0, 4.0, 5.0]

            # Create specialized multiplier functions
            triple = create_multiplier(3.0)
            quadruple = create_multiplier(4.0)

            # Apply operations
            tripled = apply_operation(numbers, triple)
            quadrupled = apply_operation(numbers, quadruple)

            print(f"Original: {numbers}")
            print(f"Tripled: {tripled}")
            print(f"Quadrupled: {quadrupled}")

            # Function composition
            add_one = lambda x: x + 1.0
            square_func = lambda x: x * x
            add_then_square = compose(square_func, add_one)

            result = add_then_square(4.0)  # (4 + 1)^2 = 25
            print(f"(4 + 1)^2 = {result}")

            # Reduce operations
            sum_result = reduce_list(numbers, lambda a, b: a + b, 0.0)
            product_result = reduce_list(numbers, lambda a, b: a * b, 1.0)

            print(f"Sum: {sum_result}")
            print(f"Product: {product_result}")
        ```

## Complete Example: Math Functions Library

!!! example "Complete Math Library with Timing"
    === "Jac"
        <div class="code-block">
        ```jac
        import time;

        # Enhanced timing decorator that works with methods
        def enhanced_timing(func: callable) -> callable {
            def wrapper(*args: any, **kwargs: any) -> any {
                start_time = time.time();
                result = func(*args, **kwargs);
                end_time = time.time();
                execution_time = end_time - start_time;

                print(f"{func.__name__} completed in {execution_time}s");
                return result;
            }
            return wrapper;
        }

        # Enhanced caching decorator
        def smart_cache(func: callable) -> callable {
            cache: dict[str, any] = {};

            def wrapper(*args: any, **kwargs: any) -> any {
                cache_key = f"{func.__name__}:{str(args)}";

                if cache_key in cache {
                    print(f"Cache hit for {cache_key}");
                    return cache[cache_key];
                }

                result = func(*args, **kwargs);
                cache[cache_key] = result;
                return result;
            }
            return wrapper;
        }

        # Math library with comprehensive functionality
        obj MathLibrary {
            has calculation_count: int = 0;

            def increment_counter() -> None;
            def get_stats() -> dict[str, any];

            @enhanced_timing
            def fibonacci(n: int) -> int;

            @enhanced_timing
            @smart_cache
            def cached_fibonacci(n: int) -> int;

            @enhanced_timing
            def factorial(n: int) -> int;

            @enhanced_timing
            def prime_check(n: int) -> bool;

            def batch_process(numbers: list[int], operation: str) -> list[any];
        }

        impl MathLibrary.increment_counter {
            self.calculation_count += 1;
        }

        impl MathLibrary.get_stats {
            return {
                "total_calculations": self.calculation_count,
                "library_version": "1.0"
            };
        }

        # Add methods to MathLibrary
        impl MathLibrary.fibonacci {
            if n <= 1 {
                return n;
            }
            return self.fibonacci(n - 1) + self.fibonacci(n - 2);
        }

        impl MathLibrary.cached_fibonacci {
            if n <= 1 {
                return n;
            }
            return self.cached_fibonacci(n - 1) + self.cached_fibonacci(n - 2);
        }

        impl MathLibrary.factorial {
            if n <= 1 {
                return 1;
            }
            return n * self.factorial(n - 1);
        }

        impl MathLibrary.prime_check {
            if n < 2 {
                return False;
            }
            for i in range(2, int(n ** 0.5) + 1) {
                if n % i == 0 {
                    return False;
                }
            }
            return True;
        }

        impl MathLibrary.batch_process {
            operations = {
                "fibonacci": self.cached_fibonacci,
                "factorial": self.factorial,
                "prime": self.prime_check
            };

            if operation not in operations {
                raise ValueError(f"Unknown operation: {operation}");
            }

            func = operations[operation];
            return [func(num) for num in numbers];
        }

        with entry {
            print("=== Math Library Demo ===");

            math_lib = MathLibrary();

            # Test individual functions
            print("Testing Fibonacci (slow):");
            result1 = math_lib.fibonacci(2);
            print(f"Fibonacci(2) = {result1}");

            print("\nTesting Cached Fibonacci (fast):");
            result2 = math_lib.cached_fibonacci(3);
            print(f"Cached Fibonacci(3) = {result2}");

            print("\nTesting Factorial:");
            result3 = math_lib.factorial(3);
            print(f"Factorial(3) = {result3}");

            print("\nTesting Prime Check:");
            test_numbers = [17, 18, 19, 20, 21];
            for num in test_numbers {
                is_prime = math_lib.prime_check(num);
                print(f"{num} is {'prime' if is_prime else 'not prime'}");
            }

            print("\nBatch Processing:");
            batch_numbers = [5, 6, 7, 8];
            fib_results = math_lib.batch_process(batch_numbers, "fibonacci");
            print(f"Fibonacci results: {fib_results}");

            # Show library statistics
            stats = math_lib.get_stats();
            print(f"\nLibrary Statistics: {stats}");
        }
        ```
        </div>
    === "Python"
        ```python
        import time
        from typing import Dict, List, Any, Callable
        from functools import wraps

        # Math library with comprehensive functionality
        class MathLibrary:
            def __init__(self):
                self.calculation_count = 0

            def increment_counter(self) -> None:
                self.calculation_count += 1

            def get_stats(self) -> Dict[str, Any]:
                return {
                    "total_calculations": self.calculation_count,
                    "library_version": "1.0"
                }

        # Enhanced timing decorator that works with methods
        def enhanced_timing(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(self, *args: Any, **kwargs: Any) -> Any:
                start_time = time.time()
                result = func(self, *args, **kwargs)
                end_time = time.time()
                execution_time = end_time - start_time

                self.increment_counter()
                print(f"{func.__name__} completed in {execution_time:.6f}s (Call #{self.calculation_count})")
                return result
            return wrapper

        # Enhanced caching decorator
        def smart_cache(func: Callable) -> Callable:
            cache: Dict[str, Any] = {}

            @wraps(func)
            def wrapper(self, *args: Any, **kwargs: Any) -> Any:
                cache_key = f"{func.__name__}:{str(args)}"

                if cache_key in cache:
                    print(f"Cache hit for {cache_key}")
                    return cache[cache_key]

                result = func(self, *args, **kwargs)
                cache[cache_key] = result
                return result
            return wrapper

        # Add methods to MathLibrary
        class MathLibrary:
            def __init__(self):
                self.calculation_count = 0

            def increment_counter(self) -> None:
                self.calculation_count += 1

            def get_stats(self) -> Dict[str, Any]:
                return {
                    "total_calculations": self.calculation_count,
                    "library_version": "1.0"
                }

            @enhanced_timing
            def fibonacci(self, n: int) -> int:
                if n <= 1:
                    return n
                return self.fibonacci(n - 1) + self.fibonacci(n - 2)

            @enhanced_timing
            @smart_cache
            def cached_fibonacci(self, n: int) -> int:
                if n <= 1:
                    return n
                return self.cached_fibonacci(n - 1) + self.cached_fibonacci(n - 2)

            @enhanced_timing
            def factorial(self, n: int) -> int:
                if n <= 1:
                    return 1
                return n * self.factorial(n - 1)

            @enhanced_timing
            def prime_check(self, n: int) -> bool:
                if n < 2:
                    return False
                for i in range(2, int(n ** 0.5) + 1):
                    if n % i == 0:
                        return False
                return True

            def batch_process(self, numbers: List[int], operation: str) -> List[Any]:
                operations = {
                    "fibonacci": self.cached_fibonacci,
                    "factorial": self.factorial,
                    "prime": self.prime_check
                }

                if operation not in operations:
                    raise ValueError(f"Unknown operation: {operation}")

                func = operations[operation]
                return [func(num) for num in numbers]

        if __name__ == "__main__":
            print("=== Math Library Demo ===")

            math_lib = MathLibrary()

            # Test individual functions
            print("Testing Fibonacci (slow):")
            result1 = math_lib.fibonacci(2)
            print(f"Fibonacci(2) = {result1}")

            print("\nTesting Cached Fibonacci (fast):")
            result2 = math_lib.cached_fibonacci(3)
            print(f"Cached Fibonacci(3) = {result2}")

            print("\nTesting Factorial:")
            result3 = math_lib.factorial(3)
            print(f"Factorial(3) = {result3}")

            print("\nTesting Prime Check:")
            test_numbers = [17, 18, 19, 20, 21]
            for num in test_numbers:
                is_prime = math_lib.prime_check(num)
                print(f"{num} is {'prime' if is_prime else 'not prime'}")

            print("\nBatch Processing:")
            batch_numbers = [5, 6, 7, 8]
            fib_results = math_lib.batch_process(batch_numbers, "fibonacci")
            print(f"Fibonacci results: {fib_results}")

            # Show library statistics
            stats = math_lib.get_stats()
            print(f"\nLibrary Statistics: {stats}")
        ```

## Key Takeaways

!!! summary "Chapter Summary"
    - **Mandatory Types**: All function parameters and return types must be explicitly declared
    - **Decorators**: Powerful tools for adding functionality like timing, caching, and validation
    - **Lambda Functions**: Concise syntax for simple operations and functional programming
    - **Higher-Order Functions**: Functions can accept and return other functions for flexible abstractions
    - **Performance**: Use decorators to add timing and caching without modifying core logic
    - **Code Organization**: Group related functions into objects or modules for better structure

!!! topic "Coming Up"
    In the next chapter, we'll explore Jac's import system and how to organize code across multiple files and modules.
