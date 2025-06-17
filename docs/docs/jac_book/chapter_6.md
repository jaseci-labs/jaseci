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
!!! example "Sales Data Analysis Pipeline"
    === "sales_pipeline.jac"
        <div class="code-block">
        ```jac
        # Sales data processing pipeline using pipe operations
        import:py json;
        import:py statistics;

        # Sample data and transformation functions
        can load_sales_data() -> list[dict] {
            return [
                {"id": 1, "product": "Laptop", "price": 999.99, "quantity": 2, "customer": "Alice"},
                {"id": 2, "product": "Mouse", "price": 29.99, "quantity": 5, "customer": "Bob"},
                {"id": 3, "product": "Keyboard", "price": 79.99, "quantity": 1, "customer": "Alice"},
                {"id": 4, "product": "Monitor", "price": 299.99, "quantity": 1, "customer": "Charlie"}
            ];
        }

        can calculate_totals(sales: list[dict]) -> list[dict] {
            return [{**sale, "total": sale["price"] * sale["quantity"]} for sale in sales];
        }

        can filter_high_value(sales: list[dict], threshold: float = 100.0) -> list[dict] {
            return [sale for sale in sales if sale["total"] >= threshold];
        }

        can group_by_customer(sales: list[dict]) -> dict[str, list] {
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

        can calculate_customer_stats(grouped_sales: dict) -> dict {
            stats = {};
            for customer, sales in grouped_sales.items() {
                totals = [sale["total"] for sale in sales];
                stats[customer] = {
                    "total_spent": sum(totals),
                    "avg_order": statistics.mean(totals),
                    "num_orders": len(sales)
                };
            }
            return stats;
        }

        # Traditional nested approach (hard to read)
        can analyze_traditional() -> dict {
            return calculate_customer_stats(
                group_by_customer(
                    filter_high_value(
                        calculate_totals(
                            load_sales_data()
                        ), 50.0
                    )
                )
            );
        }

        # Pipe-based approach (clear data flow)
        can analyze_with_pipes() -> dict {
            return (
                load_sales_data()
                |> calculate_totals(_)
                |> filter_high_value(_, 50.0)
                |> group_by_customer(_)
                |> calculate_customer_stats(_)
            );
        }

        with entry {
            print("=== Traditional vs Pipe Approach ===");

            traditional_result = analyze_traditional();
            pipe_result = analyze_with_pipes();

            print("Results are identical:");
            print(json.dumps(pipe_result, indent=2));
        }
        ```
        </div>

## AI Integration and Semantic Strings

Jac provides built-in AI integration through semantic strings (semstrings), making it easy to add intelligent features to your applications.

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

### Content Analysis Example

**Code Example**
!!! example "AI-Powered Content Analyzer"
    === "content_analyzer.jac"
        <div class="code-block">
        ```jac
        # AI-powered content analysis using semstrings and pipes
        import:py json;

        obj ContentAnalyzer {
            can summarize_text(text: str) -> str {
                return f"Provide a brief 2-3 sentence summary of this text: {text}" by llm();
            }

            can extract_insights(text: str) -> list[str] {
                insights_text = f"""
                Extract the 3 most important insights from this text as a JSON list:
                {text}

                Return only a JSON array of strings.
                """ by llm();

                try {
                    insights = json.loads(insights_text);
                    return insights if isinstance(insights, list) else [];
                } except Exception {
                    return [insights_text];  # Fallback
                }
            }

            can analyze_sentiment(text: str) -> dict {
                analysis = f"""
                Analyze the sentiment of this text and return a JSON object with:
                - sentiment: "positive", "negative", or "neutral"
                - confidence: a number between 0 and 1

                Text: {text}
                """ by llm();

                try {
                    return json.loads(analysis);
                } except Exception {
                    return {"sentiment": "neutral", "confidence": 0.5};
                }
            }

            can comprehensive_analysis(text: str) -> dict {
                return {
                    "summary": self.summarize_text(text),
                    "insights": self.extract_insights(text),
                    "sentiment": self.analyze_sentiment(text),
                    "word_count": len(text.split())
                };
            }
        }

        # Process multiple articles with pipes
        can analyze_articles(articles: list[str]) -> list[dict] {
            analyzer = ContentAnalyzer();

            return (
                articles
                |> [{"text": article, "analysis": analyzer.comprehensive_analysis(article)}
                   for article in _]
                |> [result for result in _ if result["analysis"] is not None]
            );
        }

        with entry {
            # Sample content
            sample_text = """
            Artificial Intelligence is transforming industries rapidly. Machine learning
            algorithms can now process vast amounts of data to identify patterns. However,
            this brings challenges like privacy concerns and the need for ethical AI development.
            """;

            analyzer = ContentAnalyzer();

            print("=== AI Content Analysis ===");
            analysis = analyzer.comprehensive_analysis(sample_text);

            print(f"Summary: {analysis['summary']}");
            print(f"Word Count: {analysis['word_count']}");
            print(f"Sentiment: {analysis['sentiment']}");
            print("Key Insights:");
            for i, insight in enumerate(analysis['insights'], 1) {
                print(f"  {i}. {insight}");
            }
        }
        ```
        </div>

### Code Generation Example

**Code Example**
!!! example "AI Code Generator"
    === "code_generator.jac"
        <div class="code-block">
        ```jac
        # AI-powered code generator
        import:py json;

        obj CodeGenerator {
            can generate_function(description: str, language: str = "python") -> str {
                return f"""
                Generate a {language} function based on this description: {description}

                Include proper error handling and documentation.
                Return only the code.
                """ by llm();
            }

            can explain_code(code: str) -> str {
                return f"""
                Explain this code in simple terms:
                {code}

                Include what it does and how it works.
                """ by llm();
            }

            can optimize_code(code: str) -> dict {
                optimization = f"""
                Analyze and optimize this code. Return JSON with:
                - "optimized_code": the improved version
                - "improvements": list of improvements made

                Code: {code}
                """ by llm();

                try {
                    return json.loads(optimization);
                } except Exception {
                    return {"optimized_code": code, "improvements": []};
                }
            }
        }

        # Code pipeline using pipes
        can generate_solution(description: str, language: str) -> dict {
            generator = CodeGenerator();

            return (
                description
                |> generator.generate_function(_, language)
                |> {
                    "code": _,
                    "explanation": generator.explain_code(_),
                    "optimization": generator.optimize_code(_)
                }
            );
        }

        with entry {
            generator = CodeGenerator();

            # Generate and analyze code
            description = "A function that calculates fibonacci numbers";
            solution = generate_solution(description, "python");

            print("=== Generated Code ===");
            print(solution['code'][:200] + "...");
            print("\n=== Explanation ===");
            print(solution['explanation'][:150] + "...");
        }
        ```
        </div>

## MTLLM Configuration

Jac's MTLLM (Multi-Tool Large Language Model) framework provides flexible AI model configuration.

**Code Example**
!!! example "Model Configuration"
    === "model_config.jac"
        <div class="code-block">
        ```jac
        # MTLLM model configuration
        import:py os;

        # Configure AI models
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

        obj AIService {
            can generate_with_model(prompt: str, model_name: str) -> str {
                match model_name {
                    case "openai": {
                        return prompt by openai_gpt;
                    }
                    case "claude": {
                        return prompt by claude_anthropic;
                    }
                    case _: {
                        return prompt by llm();  # Default
                    }
                }
            }

            can compare_models(prompt: str) -> dict {
                models = ["openai", "claude"];
                results = {};

                for model in models {
                    try {
                        response = self.generate_with_model(prompt, model);
                        results[model] = {"response": response, "status": "success"};
                    } except Exception as e {
                        results[model] = {"response": "", "status": f"error: {e}"};
                    }
                }
                return results;
            }
        }

        with entry {
            service = AIService();
            prompt = "Explain quantum computing briefly";

            comparison = service.compare_models(prompt);
            for model, result in comparison.items() {
                print(f"{model}: {result['status']}");
                if result['status'] == 'success' {
                    print(f"Response: {result['response'][:100]}...");
                }
            }
        }
        ```
        </div>

## Best Practices

### Pipe Operations
- **Keep functions pure** - avoid side effects in pipeline functions
- **Use meaningful names** - make the data flow readable
- **Handle errors gracefully** - include error handling in transformations

```jac
# Good - clear pipeline
result = (
    raw_data
    |> clean_data(_)
    |> transform_data(_)
    |> validate_data(_)
);
```

### AI Integration
- **Validate responses** - always handle AI errors
- **Use structured prompts** - be specific about expected output
- **Implement fallbacks** - have backup strategies

```jac
can safe_ai_call(prompt: str) -> str {
    try {
        result = prompt by llm();
        return result if result else "No response";
    } except Exception as e {
        return f"AI Error: {e}";
    }
}
```

## Summary

This chapter introduced Jac's enhanced features:

**Pipe Operations** enable:
- Clean, readable data transformation pipelines
- Functional programming patterns
- Easy composition of operations

**AI Integration** provides:
- Seamless AI capabilities through semstrings
- Flexible model configuration with MTLLM
- Built-in prompt engineering

These features combine elegant data flow with intelligent processing, making complex applications both powerful and maintainable.
                Generate a {language} function based on this description: {description}

                Requirements:
                - Include proper error handling
                - Add documentation/comments
                - Use best practices for {language}
                - Include type hints where applicable

                Return only the code, no additional explanation.
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
        }

        # Code generation pipeline using pipes
        can generate_complete_solution(requirements: dict) -> dict {
            """Generate a complete code solution with documentation."""
            generator = CodeGenerator();

            language = requirements.get("language", "python");
            description = requirements.get("description", "");

            return (
                description
                |> generator.generate_function(_, language)
                |> {
                    "code": _,
                    "explanation": generator.explain_code(_),
                    "optimization": generator.optimize_code(_, language),
                    "language": language
                }
            );
        }

        with entry {
            generator = CodeGenerator();

            # Generate and optimize code
            print("=== Code Generation and Optimization ===");

            sample_code = """
def find_max(numbers):
    max_val = numbers[0]
    for i in range(1, len(numbers)):
        if numbers[i] > max_val:
            max_val = numbers[i]
    return max_val
            """;

            # Code explanation
            explanation = generator.explain_code(sample_code);
            print("Code Explanation:");
            print(explanation);

            # Code optimization
            optimization = generator.optimize_code(sample_code, "python");
            print("\nOptimized Code:");
            print(optimization.get("optimized_code", ""));
            print("\nImprovements:");
            for improvement in optimization.get("improvements", []) {
                print(f"  - {improvement}");
            }

            # Complete solution generation
            print("\n=== Complete Solution Generation ===");
            requirements = {
                "description": "A function that calculates fibonacci numbers efficiently",
                "language": "python"
            };

            solution = generate_complete_solution(requirements);
            print(f"Generated {solution['language']} solution:");
            print("Code:")
            print(solution['code'][:300] + "...");
            print("\nExplanation:")
            print(solution['explanation'][:200] + "...");
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

            can semantic_search(query: str, max_results: int = 3) -> list[dict] {
                """Perform semantic search using AI understanding."""
                search_prompt = f"""
                Given this search query: "{query}"

                And these documents:
                {json.dumps([{"id": d["id"], "title": d["title"], "content": d["content"][:200]} for d in self.documents], indent=2)}

                Return the {max_results} most relevant documents as a JSON array with:
                - id: document id
                - relevance_score: 0-1 score
                - relevance_reason: why this document matches

                Consider semantic meaning, not just keywords.
                """ by llm();

                try {
                    results = json.loads(search_prompt);
                    self.log_search(query, results);
                    return results if isinstance(results, list) else [];
                } except Exception as e {
                    print(f"Semantic search failed: {e}");
                    return self.keyword_search(query, max_results);
                }
            }

            can keyword_search(query: str, max_results: int) -> list[dict] {
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
                            "relevance_reason": f"Keyword matches: {matches}"
                        });
                    }
                }

                results.sort(key=lambda x: x["relevance_score"], reverse=True);
                return results[:max_results];
            }

            can summarize_results(query: str, results: list[dict]) -> str {
                """Generate a summary of search results."""
                if not results {
                    return f"No results found for '{query}'.";
                }

                top_docs = [
                    next(d for d in self.documents if d["id"] == r["id"])
                    for r in results[:2]
                ];

                docs_text = json.dumps([{
                    "title": doc["title"],
                    "content": doc["content"][:300]
                } for doc in top_docs]);

                return f"""
                Summarize the search results for "{query}":
                {docs_text}

                Provide a brief overview of what information is available.
                """ by llm();
            }

            can log_search(query: str, results: list[dict]) {
                """Log search for analytics."""
                self.search_history.append({
                    "query": query,
                    "timestamp": datetime.now().isoformat(),
                    "result_count": len(results)
                });
            }

            can smart_search_pipeline(query: str) -> dict {
                """Complete smart search pipeline."""
                return (
                    query
                    |> {
                        "query": _,
                        "results": self.semantic_search(_, 3),
                        "summary": ""
                    }
                    |> {
                        **_,
                        "summary": self.summarize_results(_["query"], _["results"])
                    }
                );
            }
        }

        with entry {
            # Create search engine and add documents
            search_engine = SmartSearchEngine();

            search_engine.add_document(
                "Machine Learning Basics",
                "Machine learning enables computers to learn from data without explicit programming. It uses algorithms to identify patterns and make predictions.",
                {"category": "technology", "difficulty": "beginner"}
            );

            search_engine.add_document(
                "Healthy Diet Tips",
                "A balanced diet includes fruits, vegetables, lean proteins, and whole grains. Proper nutrition supports overall health and energy levels.",
                {"category": "health", "difficulty": "beginner"}
            );

            search_engine.add_document(
                "Climate Solutions",
                "Renewable energy technologies like solar and wind power offer sustainable alternatives to fossil fuels and help combat climate change.",
                {"category": "environment", "difficulty": "intermediate"}
            );

            # Perform smart searches
            queries = ["AI learning algorithms", "nutrition advice", "green energy"];

            for query in queries {
                print(f"\n=== Search: '{query}' ===");
                result = search_engine.smart_search_pipeline(query);

                print("Top Results:");
                for i, res in enumerate(result['results'], 1) {
                    doc = next(d for d in search_engine.documents if d["id"] == res["id"]);
                    print(f"  {i}. {doc['title']} (Score: {res['relevance_score']:.2f})");
                }

                print(f"\nSummary: {result['summary'][:150]}...");
            }
        }
        ```
        </div>

## MTLLM Configuration and Usage

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

        # Model-specific implementations
        obj AIService {
            can generate_with_model(prompt: str, model_name: str) -> str {
                """Generate response using specific model."""
                match model_name {
                    case "openai": {
                        return prompt by openai_gpt;
                    }
                    case "claude": {
                        return prompt by claude_anthropic;
                    }
                    case _: {
                        return prompt by llm();  # Default model
                    }
                }
            }

            can compare_models(prompt: str) -> dict {
                """Compare responses from different models."""
                models = ["openai", "claude"];
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
        }

        with entry {
            service = AIService();
            test_prompt = "Explain quantum computing in simple terms";

            print("=== Model Comparison ===");
            comparison = service.compare_models(test_prompt);

            for model, result in comparison.items() {
                print(f"\n{model.upper()} Response:");
                print(f"Status: {result['status']}");
                if result['status'] == 'success' {
                    print(f"Response: {result['response'][:150]}...");
                }
            }
        }
        ```
        </div>

## Best Practices

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
   ```

2. **Use Meaningful Function Names**: Make the pipeline readable
   ```jac
   # Good - clear pipeline
   report = (
       raw_data
       |> parse_entries(_)
       |> filter_valid(_)
       |> generate_report(_)
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
           return keyword_categorize(text);  # Fallback
       }
   }
   ```

## Summary

This chapter introduced Jac's enhanced features that combine functional programming elegance with AI intelligence:

**Pipe Operations** enable:
- Clean, readable data transformation pipelines
- Functional programming patterns
- Easy composition of complex operations
- Clear separation of concerns

**AI Integration** provides:
- Seamless AI capabilities through semstrings
- Flexible model configuration with MTLLM
- Built-in prompt engineering
- Support for multiple AI providers

These features work together to create applications that are both powerful and maintainable, combining elegant data flow with intelligent processing capabilities.
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
