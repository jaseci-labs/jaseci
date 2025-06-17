# Chapter 6: Enhanced Features: Pipe Operations and AI Integration

This chapter explores two of Jac's most powerful modern features: pipe operations for elegant data flow programming and built-in AI integration for intelligent applications. These features represent Jac's commitment to making complex programming patterns simple and accessible.

## Pipe Operations and Data Flow

Jac's pipe operator (`|>`) enables functional programming patterns that make data transformations readable and composable. Unlike traditional nested function calls, pipes create clear data flow pipelines.

### Basic Pipe Operations

**Code Example**
!!! example "Pipe Expressions"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "jac/examples/reference/pipe_expressions.jac"
        ```
        </div>
    === "Python"
        ```python
        --8<-- "jac/examples/reference/pipe_expressions.py"
        ```

**Description**

--8<-- "jac/examples/reference/pipe_expressions.md"

### Pipe Back Operations

**Code Example**
!!! example "Pipe Back Expressions"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "jac/examples/reference/pipe_back_expressions.jac"
        ```
        </div>
    === "Python"
        ```python
        --8<-- "jac/examples/reference/pipe_back_expressions.py"
        ```

**Description**

--8<-- "jac/examples/reference/pipe_back_expressions.md"

### Data Processing Pipeline Example

**Code Example**
!!! example "Log Analysis Pipeline"
    === "log_analyzer.jac"
        <div class="code-block">
        ```jac
        # Log analysis pipeline using pipe operations
        import:py re;
        import:py json;
        from datetime import datetime;

        # Utility functions for the pipeline
        can parse_log_line(line: str) -> dict {
            """Parse a single log line into structured data."""
            pattern = r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)';
            match = re.match(pattern, line.strip());

            if match {
                return {
                    "timestamp": match.group(1),
                    "level": match.group(2),
                    "message": match.group(3)
                };
            }
            return None;
        }

        can filter_by_level(logs: list[dict], level: str) -> list[dict] {
            """Filter logs by severity level."""
            return [log for log in logs if log and log.get("level") == level];
        }

        can extract_errors(logs: list[dict]) -> list[dict] {
            """Extract error information from log messages."""
            error_logs = [];
            for log in logs {
                if "error" in log.get("message", "").lower() {
                    log["error_type"] = "runtime_error";
                    error_logs.append(log);
                } elif "exception" in log.get("message", "").lower() {
                    log["error_type"] = "exception";
                    error_logs.append(log);
                }
            }
            return error_logs;
        }

        can group_by_hour(logs: list[dict]) -> dict[str, list] {
            """Group logs by hour."""
            groups = {};
            for log in logs {
                timestamp = log.get("timestamp", "");
                hour = timestamp[:13] if len(timestamp) >= 13 else "unknown";
                if hour not in groups {
                    groups[hour] = [];
                }
                groups[hour].append(log);
            }
            return groups;
        }

        can count_by_level(logs: list[dict]) -> dict[str, int] {
            """Count logs by level."""
            counts = {};
            for log in logs {
                level = log.get("level", "unknown");
                counts[level] = counts.get(level, 0) + 1;
            }
            return counts;
        }

        can format_summary(data: dict) -> str {
            """Format the analysis summary."""
            summary = "=== Log Analysis Summary ===\n";
            for level, count in data.items() {
                summary += f"{level}: {count} entries\n";
            }
            return summary;
        }

        # Traditional nested approach (hard to read)
        can analyze_logs_traditional(log_lines: list[str]) -> str {
            return format_summary(
                count_by_level(
                    extract_errors(
                        filter_by_level(
                            [parse_log_line(line) for line in log_lines],
                            "ERROR"
                        )
                    )
                )
            );
        }

        # Pipe-based approach (clear data flow)
        can analyze_logs_with_pipes(log_lines: list[str]) -> str {
            return (
                log_lines
                |> [parse_log_line(line) for line in _]
                |> [log for log in _ if log is not None]
                |> filter_by_level(_, "ERROR")
                |> extract_errors(_)
                |> count_by_level(_)
                |> format_summary(_)
            );
        }

        # Advanced pipeline with multiple branches
        can comprehensive_analysis(log_lines: list[str]) -> dict {
            # Parse all logs once
            parsed_logs = (
                log_lines
                |> [parse_log_line(line) for line in _]
                |> [log for log in _ if log is not None]
            );

            # Create multiple analysis branches
            error_analysis = (
                parsed_logs
                |> filter_by_level(_, "ERROR")
                |> extract_errors(_)
                |> group_by_hour(_)
            );

            warning_analysis = (
                parsed_logs
                |> filter_by_level(_, "WARN")
                |> count_by_level(_)
            );

            time_distribution = (
                parsed_logs
                |> group_by_hour(_)
                |> {hour: len(logs) for hour, logs in _.items()}
            );

            return {
                "errors": error_analysis,
                "warnings": warning_analysis,
                "time_distribution": time_distribution,
                "total_logs": len(parsed_logs)
            };
        }

        with entry {
            # Sample log data
            sample_logs = [
                "2024-01-15 10:30:15 [INFO] Application started",
                "2024-01-15 10:30:16 [DEBUG] Loading configuration",
                "2024-01-15 10:31:22 [WARN] Deprecated API usage detected",
                "2024-01-15 10:32:45 [ERROR] Database connection failed",
                "2024-01-15 10:33:12 [ERROR] Exception in user handler: NullPointerException",
                "2024-01-15 11:15:33 [INFO] Request processed successfully",
                "2024-01-15 11:20:45 [ERROR] Runtime error in payment processing",
                "2024-01-15 11:25:10 [WARN] High memory usage detected"
            ];

            # Traditional analysis
            print("=== Traditional Approach ===");
            traditional_result = analyze_logs_traditional(sample_logs);
            print(traditional_result);

            # Pipe-based analysis
            print("=== Pipe-based Approach ===");
            pipe_result = analyze_logs_with_pipes(sample_logs);
            print(pipe_result);

            # Comprehensive analysis
            print("=== Comprehensive Analysis ===");
            comprehensive_result = comprehensive_analysis(sample_logs);
            print(json.dumps(comprehensive_result, indent=2));
        }
        ```
        </div>

### Data Transformation Chains

**Code Example**
!!! example "E-commerce Data Processing"
    === "data_processing.jac"
        <div class="code-block">
        ```jac
        # E-commerce data processing with pipes
        import:py statistics;
        from decimal import Decimal;

        # Sample data transformation functions
        can load_sales_data(filename: str) -> list[dict] {
            """Simulate loading sales data."""
            return [
                {"id": 1, "product": "Laptop", "price": 999.99, "quantity": 2, "customer": "Alice"},
                {"id": 2, "product": "Mouse", "price": 29.99, "quantity": 5, "customer": "Bob"},
                {"id": 3, "product": "Keyboard", "price": 79.99, "quantity": 1, "customer": "Alice"},
                {"id": 4, "product": "Monitor", "price": 299.99, "quantity": 1, "customer": "Charlie"},
                {"id": 5, "product": "Laptop", "price": 999.99, "quantity": 1, "customer": "Diana"},
                {"id": 6, "product": "Mouse", "price": 29.99, "quantity": 10, "customer": "Eve"}
            ];
        }

        can calculate_total(sale: dict) -> dict {
            """Add total value to each sale record."""
            sale["total"] = sale["price"] * sale["quantity"];
            return sale;
        }

        can filter_high_value(sales: list[dict], threshold: float = 100.0) -> list[dict] {
            """Filter sales above threshold."""
            return [sale for sale in sales if sale["total"] >= threshold];
        }

        can group_by_customer(sales: list[dict]) -> dict[str, list] {
            """Group sales by customer."""
            groups = {};
            for sale in sales {
                customer = sale["customer"];
                if customer not in groups {
                    groups[customer] = [];
                }
                groups[customer].append(sale);
            }
            return groups;
        }

        can calculate_customer_stats(grouped_sales: dict) -> dict[str, dict] {
            """Calculate statistics for each customer."""
            stats = {};
            for customer, sales in grouped_sales.items() {
                totals = [sale["total"] for sale in sales];
                stats[customer] = {
                    "total_spent": sum(totals),
                    "avg_order": statistics.mean(totals),
                    "num_orders": len(sales),
                    "products": list(set(sale["product"] for sale in sales))
                };
            }
            return stats;
        }

        can format_report(customer_stats: dict) -> str {
            """Format customer analysis report."""
            report = "=== Customer Analysis Report ===\n\n";

            # Sort customers by total spent
            sorted_customers = sorted(
                customer_stats.items(),
                key=lambda x: x[1]["total_spent"],
                reverse=True
            );

            for customer, stats in sorted_customers {
                report += f"Customer: {customer}\n";
                report += f"  Total Spent: ${stats['total_spent']:.2f}\n";
                report += f"  Average Order: ${stats['avg_order']:.2f}\n";
                report += f"  Number of Orders: {stats['num_orders']}\n";
                report += f"  Products: {', '.join(stats['products'])}\n\n";
            }

            return report;
        }

        # Complete analysis pipeline
        can analyze_sales_data(filename: str) -> str {
            return (
                filename
                |> load_sales_data(_)
                |> [calculate_total(sale) for sale in _]
                |> filter_high_value(_, 50.0)
                |> group_by_customer(_)
                |> calculate_customer_stats(_)
                |> format_report(_)
            );
        }

        # Parallel processing with pipes
        can parallel_analysis(sales_data: list[dict]) -> dict {
            # Product analysis branch
            product_stats = (
                sales_data
                |> group_by_product(_)
                |> calculate_product_performance(_)
            );

            # Time analysis branch
            time_stats = (
                sales_data
                |> group_by_time_period(_)
                |> calculate_time_trends(_)
            );

            # Customer analysis branch
            customer_stats = (
                sales_data
                |> group_by_customer(_)
                |> calculate_customer_lifetime_value(_)
            );

            return {
                "products": product_stats,
                "time_trends": time_stats,
                "customers": customer_stats
            };
        }

        can group_by_product(sales: list[dict]) -> dict[str, list] {
            """Group sales by product."""
            groups = {};
            for sale in sales {
                product = sale["product"];
                if product not in groups {
                    groups[product] = [];
                }
                groups[product].append(sale);
            }
            return groups;
        }

        can calculate_product_performance(grouped_sales: dict) -> dict {
            """Calculate product performance metrics."""
            performance = {};
            for product, sales in grouped_sales.items() {
                total_revenue = sum(sale["total"] for sale in sales);
                total_quantity = sum(sale["quantity"] for sale in sales);
                performance[product] = {
                    "revenue": total_revenue,
                    "units_sold": total_quantity,
                    "avg_price": total_revenue / total_quantity if total_quantity > 0 else 0
                };
            }
            return performance;
        }

        # Placeholder functions for comprehensive example
        can group_by_time_period(sales: list[dict]) -> dict {
            return {"daily": sales};  # Simplified
        }

        can calculate_time_trends(grouped_sales: dict) -> dict {
            return {"trend": "increasing"};  # Simplified
        }

        can calculate_customer_lifetime_value(grouped_sales: dict) -> dict {
            return {customer: {"ltv": sum(sale["total"] for sale in sales)}
                   for customer, sales in grouped_sales.items()};
        }

        with entry {
            # Run the analysis
            report = analyze_sales_data("sales.csv");
            print(report);

            # Load data for parallel analysis
            sales_data = (
                load_sales_data("sales.csv")
                |> [calculate_total(sale) for sale in _]
            );

            # Run parallel analysis
            comprehensive_stats = parallel_analysis(sales_data);
            print("\n=== Comprehensive Analysis ===");

            for category, stats in comprehensive_stats.items() {
                print(f"\n{category.title()}:");
                print(f"  {stats}");
            }
        }
        ```
        </div>

## AI Integration and MTLLM

Jac provides built-in AI integration through semantic strings (semstrings) and the MTLLM (Multi-Tool Large Language Model) framework, making it easy to add intelligent features to your applications.

### Semantic Strings (Semstrings)

**Code Example**
!!! example "Semstrings - AI-Powered String Processing"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "jac/examples/reference/semstrings.jac"
        ```
        </div>
    === "Python"
        ```python
        --8<-- "jac/examples/reference/semstrings.py"
        ```

**Description**

--8<-- "jac/examples/reference/semstrings.md"

### Content Summarizer Example

**Code Example**
!!! example "AI-Powered Content Summarizer"
    === "summarizer.jac"
        <div class="code-block">
        ```jac
        # AI-powered content summarizer using semstrings
        import:py requests;
        import:py json;

        obj ContentSummarizer {
            has api_key: str;
            has model: str = "gpt-3.5-turbo";
            has max_tokens: int = 150;

            can summarize_text(text: str, summary_type: str = "brief") -> str {
                """Summarize text using AI with different summary types."""
                if summary_type == "brief" {
                    return f"Provide a brief 2-3 sentence summary of this text: {text}" by llm();
                } elif summary_type == "detailed" {
                    return f"Provide a detailed summary with key points for: {text}" by llm();
                } elif summary_type == "bullet_points" {
                    return f"Create bullet points summarizing the main ideas in: {text}" by llm();
                } else {
                    return f"Summarize this text: {text}" by llm();
                }
            }

            can extract_key_insights(text: str) -> list[str] {
                """Extract key insights from content."""
                insights_text = f"""
                Extract the 5 most important insights from this text as a JSON list:
                {text}

                Return only a JSON array of strings, no additional text.
                """ by llm();

                try {
                    insights = json.loads(insights_text);
                    return insights if isinstance(insights, list) else [insights_text];
                } except Exception {
                    # Fallback: split by lines and clean up
                    return [
                        line.strip().lstrip("- ").lstrip("• ")
                        for line in insights_text.split("\n")
                        if line.strip() and not line.strip().startswith("[")
                    ][:5];
                }
            }

            can generate_title(text: str) -> str {
                """Generate an appropriate title for the content."""
                return f"Generate a concise, engaging title for this content: {text[:500]}..." by llm();
            }

            can analyze_sentiment(text: str) -> dict {
                """Analyze the sentiment of the text."""
                analysis = f"""
                Analyze the sentiment of this text and return a JSON object with:
                - sentiment: "positive", "negative", or "neutral"
                - confidence: a number between 0 and 1
                - key_emotions: list of emotions detected

                Text: {text}
                """ by llm();

                try {
                    return json.loads(analysis);
                } except Exception {
                    return {
                        "sentiment": "neutral",
                        "confidence": 0.5,
                        "key_emotions": ["uncertain"]
                    };
                }
            }

            can categorize_content(text: str, categories: list[str]) -> str {
                """Categorize content into predefined categories."""
                category_list = ", ".join(categories);
                return f"""
                Categorize this text into one of these categories: {category_list}

                Text: {text}

                Return only the category name.
                """ by llm();
            }

            can comprehensive_analysis(text: str) -> dict {
                """Perform comprehensive content analysis."""
                return {
                    "title": self.generate_title(text),
                    "brief_summary": self.summarize_text(text, "brief"),
                    "detailed_summary": self.summarize_text(text, "detailed"),
                    "key_insights": self.extract_key_insights(text),
                    "sentiment": self.analyze_sentiment(text),
                    "category": self.categorize_content(text, [
                        "Technology", "Business", "Health", "Entertainment",
                        "Politics", "Science", "Sports", "Education"
                    ]),
                    "word_count": len(text.split()),
                    "reading_time": f"{len(text.split()) // 200 + 1} minutes"
                };
            }
        }

        # Batch processing with pipes
        can process_multiple_articles(articles: list[str]) -> list[dict] {
            summarizer = ContentSummarizer();

            return (
                articles
                |> [{"original": article, "analysis": summarizer.comprehensive_analysis(article)}
                   for article in _]
                |> [result for result in _ if result["analysis"] is not None]
            );
        }

        with entry {
            # Sample content for demonstration
            sample_article = """
            Artificial Intelligence has been transforming industries at an unprecedented pace.
            From healthcare diagnostics to financial fraud detection, AI systems are becoming
            increasingly sophisticated and reliable. Machine learning algorithms can now
            process vast amounts of data to identify patterns that humans might miss.

            However, this rapid advancement also brings challenges. Privacy concerns, job
            displacement, and the need for ethical AI development are critical issues that
            society must address. Companies are investing heavily in AI research while
            governments are working to establish regulatory frameworks.

            The future of AI looks promising, with potential applications in climate change
            mitigation, personalized education, and space exploration. As we move forward,
            the key will be ensuring that AI development remains aligned with human values
            and benefits all of society.
            """;

            # Create summarizer
            summarizer = ContentSummarizer();

            # Perform comprehensive analysis
            print("=== AI Content Analysis ===");
            analysis = summarizer.comprehensive_analysis(sample_article);

            print(f"Title: {analysis['title']}");
            print(f"Category: {analysis['category']}");
            print(f"Reading Time: {analysis['reading_time']}");
            print(f"Word Count: {analysis['word_count']}");

            print(f"\nBrief Summary:\n{analysis['brief_summary']}");

            print(f"\nKey Insights:");
            for i, insight in enumerate(analysis['key_insights'], 1) {
                print(f"  {i}. {insight}");

            print(f"\nSentiment Analysis:");
            sentiment = analysis['sentiment'];
            print(f"  Sentiment: {sentiment.get('sentiment', 'unknown')}");
            print(f"  Confidence: {sentiment.get('confidence', 0):.2f}");
            print(f"  Emotions: {', '.join(sentiment.get('key_emotions', []))}");

            # Batch processing example
            print("\n=== Batch Processing ===");
            articles = [
                "Technology stocks surged today as investors showed confidence in AI startups...",
                "New medical research shows promising results for AI-assisted cancer detection...",
                "Climate scientists are using machine learning to improve weather predictions..."
            ];

            batch_results = process_multiple_articles(articles);
            for i, result in enumerate(batch_results, 1) {
                analysis = result["analysis"];
                print(f"\nArticle {i}: {analysis['title']}");
                print(f"Category: {analysis['category']}");
                print(f"Summary: {analysis['brief_summary'][:100]}...");
            }
        }
        ```
        </div>

### Code Generator Example

**Code Example**
!!! example "AI-Powered Code Generator"
    === "code_generator.jac"
        <div class="code-block">
        ```jac
        # AI-powered code generator for multiple languages
        import:py json;
        import:py re;

        obj CodeGenerator {
            has supported_languages: list[str] = [
                "python", "javascript", "java", "jac", "sql", "html", "css"
            ];

            can generate_function(description: str, language: str = "python") -> str {
                """Generate a function based on description."""
                if language not in self.supported_languages {
                    language = "python";
                }

                return f"""
                Generate a {language} function based on this description: {description}

                Requirements:
                - Include proper error handling
                - Add documentation/comments
                - Use best practices for {language}
                - Include type hints where applicable

                Return only the code, no additional explanation.
                """ by llm();
            }

            can generate_class(description: str, language: str = "python") -> str {
                """Generate a class with methods."""
                return f"""
                Create a {language} class based on this description: {description}

                Include:
                - Constructor with appropriate parameters
                - At least 3 relevant methods
                - Proper documentation
                - Error handling where needed

                Return only the code.
                """ by llm();
            }

            can generate_algorithm(problem: str, language: str = "python") -> str {
                """Generate an algorithm to solve a specific problem."""
                return f"""
                Implement an efficient algorithm in {language} to solve this problem:
                {problem}

                Requirements:
                - Optimize for time complexity
                - Include comments explaining the approach
                - Add example usage
                - Handle edge cases

                Return only the code.
                """ by llm();
            }

            can generate_api_endpoint(description: str, framework: str = "flask") -> str {
                """Generate API endpoint code."""
                return f"""
                Create a {framework} API endpoint based on this description: {description}

                Include:
                - Proper HTTP methods
                - Request validation
                - Error responses
                - Documentation

                Return only the code.
                """ by llm();
            }

            can explain_code(code: str) -> str {
                """Explain what a piece of code does."""
                return f"""
                Explain this code in simple terms:

                {code}

                Include:
                - What the code does
                - How it works
                - Any notable patterns or techniques used
                """ by llm();
            }

            can optimize_code(code: str, language: str) -> dict {
                """Suggest optimizations for code."""
                optimization = f"""
                Analyze this {language} code and suggest optimizations:

                {code}

                Return a JSON object with:
                - "optimized_code": the improved version
                - "improvements": list of improvements made
                - "performance_notes": explanation of performance gains
                """ by llm();

                try {
                    return json.loads(optimization);
                } except Exception {
                    return {
                        "optimized_code": code,
                        "improvements": ["Unable to parse optimization"],
                        "performance_notes": "Manual review recommended"
                    };
                }
            }

            can generate_test_cases(code: str, language: str) -> str {
                """Generate test cases for given code."""
                return f"""
                Generate comprehensive test cases for this {language} code:

                {code}

                Include:
                - Unit tests for normal cases
                - Edge case tests
                - Error condition tests
                - Use appropriate testing framework for {language}

                Return only the test code.
                """ by llm();
            }

            can convert_language(code: str, from_lang: str, to_lang: str) -> str {
                """Convert code from one language to another."""
                return f"""
                Convert this {from_lang} code to {to_lang}:

                {code}

                Maintain the same functionality while following {to_lang} best practices.
                Return only the converted code.
                """ by llm();
            }
        }

        # Code generation pipeline
        can generate_complete_module(requirements: dict) -> dict {
            """Generate a complete code module with tests and documentation."""
            generator = CodeGenerator();

            language = requirements.get("language", "python");
            description = requirements.get("description", "");

            # Generate main code
            main_code = (
                description
                |> generator.generate_class(_, language)
            );

            # Generate tests
            test_code = (
                main_code
                |> generator.generate_test_cases(_, language)
            );

            # Generate documentation
    documentation = f"""
                Create documentation for this {language} code:

                {main_code}

                Include:
                - Overview of what the code does
                - Usage examples
                - API reference
                - Installation/setup instructions
                """ by llm();

            return {
                "main_code": main_code,
                "test_code": test_code,
                "documentation": documentation,
                "language": language
            };
        }

        with entry {
            generator = CodeGenerator();

            # Generate a function
            print("=== Function Generation ===");
            function_desc = "A function that calculates the Fibonacci sequence up to n terms";
            python_func = generator.generate_function(function_desc, "python");
            print("Python Function:");
            print(python_func);

            # Generate the same function in JavaScript
            js_func = generator.generate_function(function_desc, "javascript");
            print("\nJavaScript Function:");
            print(js_func);

            # Generate a class
            print("\n=== Class Generation ===");
            class_desc = "A bank account class with deposit, withdraw, and balance inquiry methods";
            bank_class = generator.generate_class(class_desc, "python");
            print("Bank Account Class:");
            print(bank_class);

            # Generate algorithm
            print("\n=== Algorithm Generation ===");
            problem = "Find the shortest path between two nodes in a weighted graph";
            algorithm = generator.generate_algorithm(problem, "python");
            print("Shortest Path Algorithm:");
            print(algorithm);

            # Code optimization
            print("\n=== Code Optimization ===");
            sample_code = """
def find_max(numbers):
    max_val = numbers[0]
    for i in range(1, len(numbers)):
        if numbers[i] > max_val:
            max_val = numbers[i]
    return max_val
            """;

            optimization = generator.optimize_code(sample_code, "python");
            print("Original Code:");
            print(sample_code);
            print("\nOptimized Code:");
            print(optimization.get("optimized_code", ""));
            print("\nImprovements:");
            for improvement in optimization.get("improvements", []) {
                print(f"  - {improvement}");
            }

            # Complete module generation
            print("\n=== Complete Module Generation ===");
            requirements = {
                "description": "A URL shortener service with analytics",
                "language": "python"
            };

            module = generate_complete_module(requirements);
            print(f"Generated {module['language']} module:");
            print("\nMain Code (first 300 chars):");
            print(module['main_code'][:300] + "...");
            print("\nDocumentation (first 200 chars):");
            print(module['documentation'][:200] + "...");
        }
        ```
        </div>

### Smart Search Example

**Code Example**
!!! example "AI-Powered Smart Search System"
    === "smart_search.jac"
        <div class="code-block">
        ```jac
        # AI-powered smart search with semantic understanding
        import:py json;
        import:py re;
        from datetime import datetime;

        obj SmartSearchEngine {
            has documents: list[dict] = [];
            has search_history: list[dict] = [];

            can add_document(title: str, content: str, metadata: dict = {}) {
                """Add a document to the search index."""
                doc = {
                    "id": len(self.documents) + 1,
                    "title": title,
                    "content": content,
                    "metadata": metadata,
                    "added_at": datetime.now().isoformat()
                };
                self.documents.append(doc);
            }

            can semantic_search(query: str, max_results: int = 5) -> list[dict] {
                """Perform semantic search using AI understanding."""
                search_prompt = f"""
                Given this search query: "{query}"

                And these documents (JSON format):
                {json.dumps(self.documents, indent=2)}

                Return the {max_results} most relevant documents as a JSON array of objects with:
                - id: document id
                - relevance_score: 0-1 score
                - relevance_reason: why this document matches the query
                - key_excerpts: list of relevant text snippets

                Consider semantic meaning, not just keyword matching.
                """ by llm();

                try {
                    results = json.loads(search_prompt);
                    self.log_search(query, results);
                    return results if isinstance(results, list) else [];
                } except Exception as e {
                    print(f"Error in semantic search: {e}");
                    return self.fallback_search(query, max_results);
                }
            }

            can fallback_search(query: str, max_results: int) -> list[dict] {
                """Fallback keyword-based search."""
                query_lower = query.lower();
                results = [];

                for doc in self.documents {
                    content_lower = (doc["title"] + " " + doc["content"]).lower();
                    matches = sum(1 for word in query_lower.split() if word in content_lower);

                    if matches > 0 {
                        score = matches / len(query_lower.split());
                        results.append({
                            "id": doc["id"],
                            "relevance_score": score,
                            "relevance_reason": f"Keyword matches: {matches}",
                            "key_excerpts": [doc["content"][:100] + "..."]
                        });
                    }
                }

                results.sort(key=lambda x: x["relevance_score"], reverse=True);
                return results[:max_results];
            }

            can intelligent_query_expansion(query: str) -> list[str] {
                """Expand query with related terms using AI."""
                expansion = f"""
                Expand this search query with related terms and synonyms: "{query}"

                Return a JSON list of 5-10 related search terms that would help find relevant content.
                Include variations, synonyms, and related concepts.
                """ by llm();

                try {
                    expanded_terms = json.loads(expansion);
                    return expanded_terms if isinstance(expanded_terms, list) else [query];
                } except Exception {
                    return [query];
                }
            }

            can summarize_search_results(query: str, results: list[dict]) -> str {
                """Generate a summary of search results."""
                if not results {
                    return f"No results found for '{query}'.";
                }

                # Get document contents for top results
                top_docs = [];
                for result in results[:3] {
                    doc = next((d for d in self.documents if d["id"] == result["id"]), None);
                    if doc {
                        top_docs.append(doc);
                    }
                }

                docs_text = json.dumps([{
                    "title": doc["title"],
                    "content": doc["content"][:500]
                } for doc in top_docs]);

                summary = f"""
                Summarize the search results for the query "{query}":

                Top matching documents:
                {docs_text}

                Provide a brief summary of what information is available and how it relates to the query.
                """ by llm();

                return summary;
            }

            can suggest_related_queries(query: str) -> list[str] {
                """Suggest related queries based on search history and content."""
                recent_searches = [s["query"] for s in self.search_history[-10:]];

                suggestion = f"""
                Based on this search query: "{query}"
                Recent searches: {recent_searches}

                Suggest 5 related queries that the user might be interested in.
                Return as a JSON list of strings.
                """ by llm();

                try {
                    suggestions = json.loads(suggestion);
                    return suggestions if isinstance(suggestions, list) else [];
                } except Exception {
                    return [];
                }
            }

            can log_search(query: str, results: list[dict]) {
                """Log search for analytics and improvement."""
                self.search_history.append({
                    "query": query,
                    "timestamp": datetime.now().isoformat(),
                    "result_count": len(results),
                    "top_score": results[0]["relevance_score"] if results else 0
                });
            }

            can analyze_search_patterns() -> dict {
                """Analyze search patterns for insights."""
                if not self.search_history {
                    return {"message": "No search history available"};
                }

                analysis_data = json.dumps(self.search_history);

                analysis = f"""
                Analyze these search patterns and provide insights:
                {analysis_data}

                Return a JSON object with:
                - most_common_topics: list of frequent search topics
                - search_trends: patterns in search behavior
                - suggestions: recommendations for content or features
                """ by llm();

                try {
                    return json.loads(analysis);
                } except Exception {
                    return {
                        "total_searches": len(self.search_history),
                        "avg_results": sum(s["result_count"] for s in self.search_history) / len(self.search_history)
                    };
                }
            }

            can smart_search_pipeline(query: str) -> dict {
                """Complete smart search pipeline with all features."""
                return (
                    query
                    |> {
                        "original_query": _,
                        "expanded_terms": self.intelligent_query_expansion(_),
                        "results": self.semantic_search(_, 5),
                        "summary": "",
                        "related_queries": []
                    }
                    |> {
                        **_,
                        "summary": self.summarize_search_results(_["original_query"], _["results"]),
                        "related_queries": self.suggest_related_queries(_["original_query"])
                    }
                );
            }
        }

        with entry {
            # Create search engine and add sample documents
            search_engine = SmartSearchEngine();

            # Add sample documents
            search_engine.add_document(
                "Introduction to Machine Learning",
                "Machine learning is a subset of artificial intelligence that enables computers to learn and make decisions from data without being explicitly programmed. It involves algorithms that can identify patterns, make predictions, and improve performance over time.",
                {"category": "technology", "difficulty": "beginner"}
            );

            search_engine.add_document(
                "Deep Learning Neural Networks",
                "Deep learning uses artificial neural networks with multiple layers to model and understand complex patterns in data. These networks can process images, text, and audio to achieve human-like performance in many tasks.",
                {"category": "technology", "difficulty": "advanced"}
            );

            search_engine.add_document(
                "Healthy Cooking Tips",
                "Eating healthy doesn't have to be complicated. Focus on whole foods, lean proteins, and plenty of vegetables. Meal planning and preparation can help you maintain a nutritious diet even with a busy schedule.",
                {"category": "health", "difficulty": "beginner"}
            );

            search_engine.add_document(
                "Climate Change and Renewable Energy",
                "Climate change poses significant challenges, but renewable energy technologies offer promising solutions. Solar, wind, and hydroelectric power can reduce carbon emissions and create a more sustainable future.",
                {"category": "environment", "difficulty": "intermediate"}
            );

            search_engine.add_document(
                "Python Programming Best Practices",
                "Writing clean, maintainable Python code requires following established conventions. Use meaningful variable names, write comprehensive tests, and leverage Python's built-in functions and libraries for efficient solutions.",
                {"category": "programming", "difficulty": "intermediate"}
            );

            # Perform smart searches
            queries = [
                "artificial intelligence learning",
                "healthy meal ideas",
                "sustainable energy solutions",
                "python coding tips"
            ];

            for query in queries {
                print(f"\n{'='*50}");
                print(f"Search Query: '{query}'");
                print('='*50);

                # Run complete search pipeline
                search_result = search_engine.smart_search_pipeline(query);

                print(f"\nExpanded Terms: {', '.join(search_result['expanded_terms'])}");

                print(f"\nTop Results:");
                for i, result in enumerate(search_result['results'][:3], 1) {
                    doc = next((d for d in search_engine.documents if d["id"] == result["id"]), None);
                    if doc {
                        print(f"  {i}. {doc['title']} (Score: {result['relevance_score']:.2f})");
                        print(f"     Reason: {result['relevance_reason']}");
                        if result.get('key_excerpts') {
                            print(f"     Excerpt: {result['key_excerpts'][0][:100]}...");
                        }
                    }

                print(f"\nSummary: {search_result['summary'][:200]}...");

                print(f"\nRelated Queries:");
                for related in search_result['related_queries'][:3] {
                    print(f"  - {related}");
                }
            }

            # Analyze search patterns
            print(f"\n{'='*50}");
            print("Search Pattern Analysis");
            print('='*50);

            analysis = search_engine.analyze_search_patterns();
            print(json.dumps(analysis, indent=2));
        }
        ```
        </div>

## MTLLM Configuration and Usage

Jac's MTLLM (Multi-Tool Large Language Model) framework provides flexible AI model configuration and management.

### Model Declaration and Configuration

**Code Example**
!!! example "MTLLM Model Configuration"
    === "model_config.jac"
        <div class="code-block">
        ```jac
        # MTLLM model configuration and usage
        import:py os;

        # Configure different AI models
        model openai_gpt {
            model_type: "openai";
            model_name: "gpt-3.5-turbo";
            temperature: 0.7;
            max_tokens: 1000;
            api_key: os.getenv("OPENAI_API_KEY");
        }

        model claude_anthropic {
            model_type: "anthropic";
            model_name: "claude-3-sonnet";
            temperature: 0.5;
            max_tokens: 2000;
            api_key: os.getenv("ANTHROPIC_API_KEY");
        }

        model local_llama {
            model_type: "ollama";
            model_name: "llama2";
            temperature: 0.8;
            host: "localhost:11434";
        }

        # Model-specific implementations
        obj AIService {
            has default_model: str = "openai_gpt";

            can generate_with_model(prompt: str, model_name: str) -> str {
                """Generate response using specific model."""
                match model_name {
                    case "openai": {
                        return prompt by openai_gpt;
                    }
                    case "claude": {
                        return prompt by claude_anthropic;
                    }
                    case "local": {
                        return prompt by local_llama;
                    }
                    case _: {
                        return prompt by llm();  # Default model
                    }
                }
            }

            can compare_models(prompt: str) -> dict {
                """Compare responses from different models."""
                models = ["openai", "claude", "local"];
                results = {};

                for model in models {
                    try {
                        response = self.generate_with_model(prompt, model);
                        results[model] = {
                            "response": response,
                            "length": len(response),
                            "status": "success"
                        };
                    } except Exception as e {
                        results[model] = {
                            "response": "",
                            "length": 0,
                            "status": f"error: {e}"
                        };
                    }
                }

                return results;
            }

            can intelligent_model_selection(task_type: str, complexity: str) -> str {
                """Select best model based on task requirements."""
                selection_logic = f"""
                Given this task type: {task_type}
                And complexity level: {complexity}

                Which model would be best?
                - openai_gpt: Good general purpose, fast, cost-effective
                - claude_anthropic: Excellent for analysis, reasoning, longer contexts
                - local_llama: Good for privacy, local processing, no API costs

                Return only the model name: openai_gpt, claude_anthropic, or local_llama
                """ by llm();

                return selection_logic.strip();
            }
        }

        # Pipeline with model routing
        can smart_content_pipeline(content: str, task: str) -> dict {
            """Process content with automatically selected models."""
            service = AIService();

            # Select appropriate model
            selected_model = service.intelligent_model_selection(task, "medium");

            # Process with selected model
            result = (
                content
                |> service.generate_with_model(_, selected_model.replace("_", ""))
            );

            return {
                "task": task,
                "selected_model": selected_model,
                "input_length": len(content),
                "output": result,
                "output_length": len(result)
            };
        }

        with entry {
            service = AIService();

            # Test prompt
            test_prompt = "Explain quantum computing in simple terms";

            print("=== Model Comparison ===");
            comparison = service.compare_models(test_prompt);

            for model, result in comparison.items() {
                print(f"\n{model.upper()} Response:");
                print(f"Status: {result['status']}");
                if result['status'] == 'success' {
                    print(f"Length: {result['length']} characters");
                    print(f"Response: {result['response'][:200]}...");
                }
            }

            # Smart model selection
            print("\n=== Smart Model Selection ===");
            tasks = [
                ("code_generation", "high"),
                ("text_summarization", "low"),
                ("creative_writing", "medium"),
                ("data_analysis", "high")
            ];

            for task_type, complexity in tasks {
                selected = service.intelligent_model_selection(task_type, complexity);
                print(f"Task: {task_type} ({complexity}) -> Model: {selected}");
            }

            # Content pipeline
            print("\n=== Smart Content Pipeline ===");
            sample_content = "Machine learning revolutionizes data analysis...";

            pipeline_result = smart_content_pipeline(sample_content, "summarization");
            print(f"Task: {pipeline_result['task']}");
            print(f"Selected Model: {pipeline_result['selected_model']}");
            print(f"Input Length: {pipeline_result['input_length']}");
            print(f"Output Length: {pipeline_result['output_length']}");
            print(f"Result: {pipeline_result['output'][:150]}...");
        }
        ```
        </div>

## Best Practices for Pipe Operations and AI Integration

### Pipe Operations Best Practices

1. **Keep Functions Pure**: Functions in pipes should avoid side effects
   ```jac
   # Good - pure functions
   result = (
       data
       |> clean_data(_)
       |> transform_data(_)
       |> validate_data(_)
   );

   # Avoid - functions with side effects in pipes
   result = (
       data
       |> log_and_clean(_)  # Side effect: logging
       |> save_and_transform(_)  # Side effect: saving
   );
   ```

2. **Use Meaningful Function Names**: Make the pipeline readable
   ```jac
   # Good - clear pipeline
   report = (
       raw_logs
       |> parse_log_entries(_)
       |> filter_error_logs(_)
       |> group_by_timestamp(_)
       |> generate_summary_report(_)
   );
   ```

3. **Handle Errors Gracefully**: Include error handling in pipeline functions
   ```jac
   can safe_transform(data: list) -> list {
       try {
           return [process_item(item) for item in data];
       } except Exception as e {
           print(f"Transform error: {e}");
           return [];
       }
   }
   ```

### AI Integration Best Practices

1. **Validate AI Responses**: Always validate and handle potential errors
   ```jac
   can safe_ai_call(prompt: str) -> str {
       try {
           result = prompt by llm();
           return result if result else "No response generated";
       } except Exception as e {
           return f"AI Error: {e}";
       }
   }
   ```

2. **Use Structured Prompts**: Be specific about expected output format
   ```jac
   # Good - structured prompt
   analysis = f"""
   Analyze this data and return JSON with:
   - summary: brief overview
   - insights: list of key findings
   - recommendations: list of actions

   Data: {data}
   """ by llm();
   ```

3. **Implement Fallbacks**: Have backup strategies when AI fails
   ```jac
   can intelligent_categorize(text: str) -> str {
       try {
           category = f"Categorize this text: {text}" by llm();
           return category.strip();
       } except Exception {
           # Fallback to keyword-based categorization
           return keyword_categorize(text);
       }
   }
   ```

## Summary

This chapter has introduced Jac's enhanced features that make modern programming patterns accessible and powerful:

**Pipe Operations** enable:
- Clean, readable data transformation pipelines
- Functional programming patterns
- Easy composition of complex operations
- Clear separation of concerns

**AI Integration** provides:
- Seamless incorporation of AI capabilities
- Flexible model configuration with MTLLM
- Built-in prompt engineering through semstrings
- Support for multiple AI providers

These features work together to create applications that are both powerful and maintainable, combining the elegance of functional programming with the intelligence of modern AI systems. Whether you're building data processing pipelines or AI-powered applications, Jac's enhanced features provide the tools you need to create sophisticated solutions with clean, readable code.
