# Chapter 6: Pipe Operations and AI Integration

Jac introduces powerful pipe operations for elegant data flow programming and seamless AI integration through semantic strings. This chapter demonstrates building a text summarizer that showcases both features working together to create intelligent data processing pipelines.

!!! topic "Pipe Operations"
    Pipe operations transform nested function calls into readable, left-to-right data flows. Combined with AI integration, they enable powerful text processing pipelines.

## Pipe Operator Chains

### Basic Pipe Operations

!!! example "Basic Pipe Expressions"
    === "Jac"
        <div class="code-block">
        ```jac
        import re;

        # Basic pipe operations for data transformation
        def clean_text(text: str) -> str {
            return text.strip().lower();
        }

        def remove_extra_spaces(text: str) -> str {
            return re.sub(r'\s+', ' ', text);
        }

        def capitalize_first(text: str) -> str {
            return text.capitalize();
        }

        with entry {
            raw_text = "  HELLO    WORLD  FROM   JAC  ";

            # Traditional nested approach (hard to read)
            result1 = capitalize_first(remove_extra_spaces(clean_text(raw_text)));
            print(f"Nested: {result1}");

            # Pipe approach (clear data flow)
            result2 = raw_text
                |> clean_text
                |> remove_extra_spaces
                |> capitalize_first;
            print(f"Piped: {result2}");
        }
        ```
        </div>
    === "Python"
        ```python
        import re

        def clean_text(text: str) -> str:
            return text.strip().lower()

        def remove_extra_spaces(text: str) -> str:
            return re.sub(r'\s+', ' ', text)

        def capitalize_first(text: str) -> str:
            return text.capitalize()

        if __name__ == "__main__":
            raw_text = "  HELLO    WORLD  FROM   PYTHON  "

            # Traditional nested approach (hard to read)
            result1 = capitalize_first(remove_extra_spaces(clean_text(raw_text)))
            print(f"Nested: {result1}")

            # Python doesn't have pipe operators, but can use function chaining
            def pipe(data, *functions):
                result = data
                for func in functions:
                    result = func(result)
                return result

            result2 = pipe(raw_text, clean_text, remove_extra_spaces, capitalize_first)
            print(f"Simulated pipe: {result2}")
        ```

### Advanced Pipe Patterns

!!! example "Complex Data Processing Pipeline"
    === "Jac"
        <div class="code-block">
        ```jac
        # Advanced pipe operations with data filtering and transformation
        def extract_words(text: str) -> list[str] {
            return text.split();
        }

        def filter_long_words(words: list[str], min_length: int = 3) -> list[str] {
            return [word for word in words if len(word) >= min_length];
        }

        def count_words(words: list[str]) -> dict[str, int] {
            counts = {};
            for word in words {
                counts[word] = counts.get(word, 0) + 1;
            }
            return counts;
        }

        def get_top_words(word_counts: dict[str, int], limit: int = 5) -> list[tuple[str, int]] {
            sorted_words = sorted(word_counts.items(), key=lambda x:int: x[1], reverse=True);
            return sorted_words[:limit];
        }

        with entry {
            sample_text = "The quick brown fox jumps over the lazy dog. The dog was very lazy.";

            # Processing pipeline with pipes
            top_words = sample_text
                |> extract_words
                |> (lambda words:list: filter_long_words(words, 3))
                |> count_words
                |> (lambda counts:list: get_top_words(counts, 3));

            print("Top words:");
            for (word, count) in top_words {
                print(f"  {word}: {count}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict, Tuple

        def extract_words(text: str) -> List[str]:
            return text.split()

        def filter_long_words(words: List[str], min_length: int = 3) -> List[str]:
            return [word for word in words if len(word) >= min_length]

        def count_words(words: List[str]) -> Dict[str, int]:
            counts = {}
            for word in words:
                counts[word] = counts.get(word, 0) + 1
            return counts

        def get_top_words(word_counts: Dict[str, int], limit: int = 5) -> List[Tuple[str, int]]:
            sorted_words = sorted(word_counts.items(), key=lambda x: x[1], reverse=True)
            return sorted_words[:limit]

        if __name__ == "__main__":
            sample_text = "The quick brown fox jumps over the lazy dog. The dog was very lazy."

            # Processing pipeline without pipes (traditional Python)
            words = extract_words(sample_text)
            long_words = filter_long_words(words, 3)
            word_counts = count_words(long_words)
            top_words = get_top_words(word_counts, 3)

            print("Top words:")
            for word, count in top_words:
                print(f"  {word}: {count}")
        ```

## Built-in AI Function Calls

!!! topic "Semantic Strings"
    Jac's semantic strings (semstrings) allow direct AI integration using the `by llm()` syntax, making AI-powered text processing natural and intuitive.

### Basic AI Integration

!!! example "Semantic String Operations"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic AI integration with semantic strings
        def ai_summarize(text: str) -> str {
            return f"Summarize this text in 2-3 sentences: {text}" by llm();
        }

        def ai_extract_keywords(text: str) -> str {
            return f"Extract 5 key words from this text as a comma-separated list: {text}" by llm();
        }

        def ai_analyze_sentiment(text: str) -> str {
            return f"Analyze the sentiment of this text (positive/negative/neutral): {text}" by llm();
        }

        with entry {
            sample_text = """
            Artificial intelligence is revolutionizing many industries. From healthcare
            to finance, AI systems are helping humans make better decisions and automate
            complex tasks. However, this technology also raises important questions about
            privacy and the future of work.
            """;

            # AI processing pipeline
            summary = ai_summarize(sample_text);
            keywords = ai_extract_keywords(sample_text);
            sentiment = ai_analyze_sentiment(sample_text);

            print(f"Summary: {summary}");
            print(f"Keywords: {keywords}");
            print(f"Sentiment: {sentiment}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python equivalent using OpenAI API (requires openai package)
        import openai
        import os

        # Note: Requires API key and openai package
        # openai.api_key = os.getenv("OPENAI_API_KEY")

        def ai_summarize(text: str) -> str:
            # Simulated AI response since we can't assume API access
            return "AI technology is transforming industries by helping humans make better decisions and automate tasks, though it raises concerns about privacy and employment."

        def ai_extract_keywords(text: str) -> str:
            # Simulated AI response
            return "artificial intelligence, healthcare, finance, automation, privacy"

        def ai_analyze_sentiment(text: str) -> str:
            # Simulated AI response
            return "neutral"

        if __name__ == "__main__":
            sample_text = """
            Artificial intelligence is revolutionizing many industries. From healthcare
            to finance, AI systems are helping humans make better decisions and automate
            complex tasks. However, this technology also raises important questions about
            privacy and the future of work.
            """

            summary = ai_summarize(sample_text)
            keywords = ai_extract_keywords(sample_text)
            sentiment = ai_analyze_sentiment(sample_text)

            print(f"Summary: {summary}")
            print(f"Keywords: {keywords}")
            print(f"Sentiment: {sentiment}")
        ```

## Complete Example: Text Summarizer with Pipe Operations

!!! topic "Integrated Pipeline"
    This example demonstrates how pipe operations and AI integration work together to create a powerful text processing system.

### Text Processing Pipeline

!!! example "Complete Text Summarizer"
    === "Jac"
        <div class="code-block">
        ```jac
        # Complete text summarizer using pipes and AI
        import:py re;
        import:py json;

        obj TextSummarizer {
            has processed_count: int = 0;

            def preprocess_text(text: str) -> str;
            def split_into_sentences(text: str) -> list[str];
            def ai_summarize_content(text: str, max_sentences: int = 3) -> str;
            def extract_key_points(text: str) -> list[str];
            def calculate_readability(text: str) -> dict[str, any];
        }

        impl TextSummarizer.preprocess_text(text: str) -> str {
            # Clean and normalize text
            text = re.sub(r'\s+', ' ', text);  # Multiple spaces to single
            text = re.sub(r'\n+', ' ', text);  # Newlines to spaces
            text = text.strip();
            return text;
        }

        impl TextSummarizer.split_into_sentences(text: str) -> list[str] {
            # Simple sentence splitting
            sentences = re.split(r'[.!?]+', text);
            return [s.strip() for s in sentences if s.strip()];
        }

        impl TextSummarizer.ai_summarize_content(text: str, max_sentences: int = 3) -> str {
            prompt = f"""
            Summarize the following text in exactly {max_sentences} clear, concise sentences:

            {text}

            Focus on the main ideas and key information.
            """;
            return prompt by llm();
        }

        impl TextSummarizer.extract_key_points(text: str) -> list[str] {
            prompt = f"""
            Extract the 5 most important key points from this text.
            Return them as a JSON array of strings.

            Text: {text}
            """;

            try {
                response = prompt by llm();
                key_points = json.loads(response);
                return key_points if isinstance(key_points, list) else [];
            } except Exception {
                # Fallback: extract first sentence of each paragraph
                sentences = self.split_into_sentences(text);
                return sentences[:5];
            }
        }

        impl TextSummarizer.calculate_readability(text: str) -> dict[str, any] {
            words = text.split();
            sentences = self.split_into_sentences(text);

            return {
                "word_count": len(words),
                "sentence_count": len(sentences),
                "avg_words_per_sentence": len(words) / len(sentences) if sentences else 0,
                "character_count": len(text)
            };
        }

        # Processing pipeline functions
        def create_summary_report(text: str, summary: str, key_points: list[str], stats: dict) -> dict {
            return {
                "original_length": stats["word_count"],
                "summary": summary,
                "key_points": key_points,
                "compression_ratio": round(len(summary.split()) / stats["word_count"], 2),
                "readability": stats
            };
        }

        def format_output(report: dict) -> str {
            output = [];
            output.append("=== TEXT SUMMARY REPORT ===");
            output.append(f"Original length: {report['original_length']} words");
            output.append(f"Compression ratio: {report['compression_ratio']}:1");
            output.append("");
            output.append("SUMMARY:");
            output.append(report['summary']);
            output.append("");
            output.append("KEY POINTS:");
            for i, point in enumerate(report['key_points'], 1) {
                output.append(f"{i}. {point}");
            }
            return "\n".join(output);
        }

        # Main processing pipeline
        def process_text_pipeline(raw_text: str) -> str {
            summarizer = TextSummarizer();

            return (
                raw_text
                |> summarizer.preprocess_text
                |> (lambda text: {
                    "clean_text": text,
                    "summary": summarizer.ai_summarize_content(text),
                    "key_points": summarizer.extract_key_points(text),
                    "stats": summarizer.calculate_readability(text)
                })
                |> (lambda data: create_summary_report(
                    data["clean_text"],
                    data["summary"],
                    data["key_points"],
                    data["stats"]
                ))
                |> format_output
            );
        }

        # Batch processing with pipes
        def process_multiple_texts(texts: list[str]) -> list[dict] {
            summarizer = TextSummarizer();

            return (
                texts
                |> [summarizer.preprocess_text(text) for text in _]
                |> [{
                    "original": text,
                    "summary": summarizer.ai_summarize_content(text, 2),
                    "key_points": summarizer.extract_key_points(text)[:3],
                    "stats": summarizer.calculate_readability(text)
                } for text in _]
                |> [result for result in _ if result["summary"]]
            );
        }

        with entry {
            # Sample text for processing
            sample_article = """
            Machine learning has become one of the most transformative technologies of the 21st century.
            It enables computers to learn patterns from data without being explicitly programmed for each task.
            This technology powers everything from recommendation systems on streaming platforms to autonomous
            vehicles navigating complex traffic scenarios.

            The applications of machine learning span across industries. In healthcare, ML algorithms can
            analyze medical images to detect diseases earlier than human doctors. In finance, they help
            detect fraudulent transactions in real-time. Social media platforms use machine learning to
            curate personalized content feeds for billions of users.

            However, machine learning also presents challenges. Issues like algorithmic bias, data privacy,
            and the need for large amounts of training data must be carefully addressed. As this technology
            continues to evolve, society must work to ensure its benefits are distributed fairly while
            minimizing potential risks.
            """;

            print("=== Single Text Processing ===");
            result = process_text_pipeline(sample_article);
            print(result);

            print("\n=== Batch Processing ===");
            texts = [
                "Renewable energy sources like solar and wind are becoming increasingly cost-effective.",
                "Climate change poses significant challenges that require global cooperation to address.",
                "Sustainable development balances economic growth with environmental protection."
            ];

            batch_results = process_multiple_texts(texts);
            for i, result in enumerate(batch_results, 1) {
                print(f"\nText {i} Summary: {result['summary']}");
                print(f"Key Points: {', '.join(result['key_points'])}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        import re
        import json
        from typing import List, Dict, Any

        class TextSummarizer:
            def __init__(self):
                self.processed_count = 0

            def preprocess_text(self, text: str) -> str:
                # Clean and normalize text
                text = re.sub(r'\s+', ' ', text)  # Multiple spaces to single
                text = re.sub(r'\n+', ' ', text)  # Newlines to spaces
                text = text.strip()
                return text

            def split_into_sentences(self, text: str) -> List[str]:
                # Simple sentence splitting
                sentences = re.split(r'[.!?]+', text)
                return [s.strip() for s in sentences if s.strip()]

            def ai_summarize_content(self, text: str, max_sentences: int = 3) -> str:
                # Simulated AI summarization (would use actual AI API)
                sentences = self.split_into_sentences(text)
                # Simple extractive summary: take first few sentences
                return ". ".join(sentences[:max_sentences]) + "."

            def extract_key_points(self, text: str) -> List[str]:
                # Simulated key point extraction
                sentences = self.split_into_sentences(text)
                # Return first sentence of logical sections
                return sentences[:5] if len(sentences) >= 5 else sentences

            def calculate_readability(self, text: str) -> Dict[str, Any]:
                words = text.split()
                sentences = self.split_into_sentences(text)

                return {
                    "word_count": len(words),
                    "sentence_count": len(sentences),
                    "avg_words_per_sentence": len(words) / len(sentences) if sentences else 0,
                    "character_count": len(text)
                }

        def create_summary_report(text: str, summary: str, key_points: List[str], stats: Dict) -> Dict:
            return {
                "original_length": stats["word_count"],
                "summary": summary,
                "key_points": key_points,
                "compression_ratio": round(len(summary.split()) / stats["word_count"], 2),
                "readability": stats
            }

        def format_output(report: Dict) -> str:
            output = []
            output.append("=== TEXT SUMMARY REPORT ===")
            output.append(f"Original length: {report['original_length']} words")
            output.append(f"Compression ratio: {report['compression_ratio']}:1")
            output.append("")
            output.append("SUMMARY:")
            output.append(report['summary'])
            output.append("")
            output.append("KEY POINTS:")
            for i, point in enumerate(report['key_points'], 1):
                output.append(f"{i}. {point}")
            return "\n".join(output)

        def process_text_pipeline(raw_text: str) -> str:
            summarizer = TextSummarizer()

            # Without pipes, we process step by step
            clean_text = summarizer.preprocess_text(raw_text)
            summary = summarizer.ai_summarize_content(clean_text)
            key_points = summarizer.extract_key_points(clean_text)
            stats = summarizer.calculate_readability(clean_text)

            report = create_summary_report(clean_text, summary, key_points, stats)
            return format_output(report)

        def process_multiple_texts(texts: List[str]) -> List[Dict]:
            summarizer = TextSummarizer()
            results = []

            for text in texts:
                clean_text = summarizer.preprocess_text(text)
                result = {
                    "original": text,
                    "summary": summarizer.ai_summarize_content(clean_text, 2),
                    "key_points": summarizer.extract_key_points(clean_text)[:3],
                    "stats": summarizer.calculate_readability(clean_text)
                }
                results.append(result)

            return results

        if __name__ == "__main__":
            # Sample text for processing
            sample_article = """
            Machine learning has become one of the most transformative technologies of the 21st century.
            It enables computers to learn patterns from data without being explicitly programmed for each task.
            This technology powers everything from recommendation systems on streaming platforms to autonomous
            vehicles navigating complex traffic scenarios.

            The applications of machine learning span across industries. In healthcare, ML algorithms can
            analyze medical images to detect diseases earlier than human doctors. In finance, they help
            detect fraudulent transactions in real-time. Social media platforms use machine learning to
            curate personalized content feeds for billions of users.

            However, machine learning also presents challenges. Issues like algorithmic bias, data privacy,
            and the need for large amounts of training data must be carefully addressed. As this technology
            continues to evolve, society must work to ensure its benefits are distributed fairly while
            minimizing potential risks.
            """

            print("=== Single Text Processing ===")
            result = process_text_pipeline(sample_article)
            print(result)

            print("\n=== Batch Processing ===")
            texts = [
                "Renewable energy sources like solar and wind are becoming increasingly cost-effective.",
                "Climate change poses significant challenges that require global cooperation to address.",
                "Sustainable development balances economic growth with environmental protection."
            ]

            batch_results = process_multiple_texts(texts)
            for i, result in enumerate(batch_results, 1):
                print(f"\nText {i} Summary: {result['summary']}")
                print(f"Key Points: {', '.join(result['key_points'])}")
        ```

## Model Declaration and Configuration

!!! topic "MTLLM Configuration"
    Jac's MTLLM (Multi-Tool Large Language Model) framework provides flexible AI model configuration for different use cases.

### Basic Model Configuration

!!! example "AI Model Setup"
    === "Jac"
        <div class="code-block">
        ```jac
        # Model configuration for different AI providers
        import:py os;

        # Configure OpenAI model
        model openai_summarizer {
            model_type: "openai";
            model_name: "gpt-3.5-turbo";
            temperature: 0.3;  # Lower temperature for consistent summaries
            max_tokens: 500;
            api_key: os.getenv("OPENAI_API_KEY");
        }

        # Configure local model
        model local_llama {
            model_type: "ollama";
            model_name: "llama2";
            temperature: 0.5;
            host: "localhost:11434";
        }

        obj SmartSummarizer {
            has model_name: str = "openai";

            def summarize_with_model(text: str, model: str) -> str;
            def choose_best_model(text_length: int) -> str;
        }

        impl SmartSummarizer.summarize_with_model(text: str, model: str) -> str {
            prompt = f"Provide a concise summary of this text:\n\n{text}";

            match model {
                case "openai": {
                    return prompt by openai_summarizer;
                }
                case "local": {
                    return prompt by local_llama;
                }
                case _: {
                    return prompt by llm();  # Default model
                }
            }
        }

        impl SmartSummarizer.choose_best_model(text_length: int) -> str {
            # Choose model based on text length and requirements
            if text_length > 2000 {
                return "openai";  # Better for long texts
            } else {
                return "local";   # Sufficient for short texts
            }
        }

        # Smart processing pipeline with model selection
        def smart_summarize_pipeline(text: str) -> dict {
            summarizer = SmartSummarizer();

            return (
                text
                |> (lambda t: {
                    "text": t,
                    "length": len(t.split()),
                    "selected_model": summarizer.choose_best_model(len(t))
                })
                |> (lambda data: {
                    **data,
                    "summary": summarizer.summarize_with_model(
                        data["text"],
                        data["selected_model"]
                    )
                })
            );
        }

        with entry {
            test_texts = [
                "Short text about AI.",
                """This is a longer text about artificial intelligence and machine learning.
                It contains multiple sentences and covers various aspects of AI technology,
                including its applications, challenges, and future prospects. This length
                of text would benefit from more sophisticated processing."""
            ];

            for text in test_texts {
                result = smart_summarize_pipeline(text);
                print(f"Length: {result['length']} words");
                print(f"Model: {result['selected_model']}");
                print(f"Summary: {result['summary']}");
                print("---");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        import os
        from typing import Dict, Any

        class SmartSummarizer:
            def __init__(self, model_name: str = "openai"):
                self.model_name = model_name

            def summarize_with_model(self, text: str, model: str) -> str:
                # Simulated AI summarization for different models
                sentences = text.split('.')

                if model == "openai":
                    # Simulate more sophisticated summarization
                    return f"AI Summary: {sentences[0]}."
                elif model == "local":
                    # Simulate simpler local model
                    return f"Local Summary: {sentences[0][:100]}..."
                else:
                    # Default processing
                    return f"Summary: {text[:50]}..."

            def choose_best_model(self, text_length: int) -> str:
                # Choose model based on text length and requirements
                if text_length > 50:  # Using word count threshold
                    return "openai"  # Better for long texts
                else:
                    return "local"   # Sufficient for short texts

        def smart_summarize_pipeline(text: str) -> Dict[str, Any]:
            summarizer = SmartSummarizer()

            # Process step by step (simulating pipeline)
            text_length = len(text.split())
            selected_model = summarizer.choose_best_model(text_length)
            summary = summarizer.summarize_with_model(text, selected_model)

            return {
                "text": text,
                "length": text_length,
                "selected_model": selected_model,
                "summary": summary
            }

        if __name__ == "__main__":
            test_texts = [
                "Short text about AI.",
                """This is a longer text about artificial intelligence and machine learning.
                It contains multiple sentences and covers various aspects of AI technology,
                including its applications, challenges, and future prospects. This length
                of text would benefit from more sophisticated processing."""
            ]

            for text in test_texts:
                result = smart_summarize_pipeline(text)
                print(f"Length: {result['length']} words")
                print(f"Model: {result['selected_model']}")
                print(f"Summary: {result['summary']}")
                print("---")
        ```

## MTLLM Variations and Basic Usage

!!! example "Multiple Model Integration"
    === "Jac"
        <div class="code-block">
        ```jac
        # Multiple model variations for different tasks
        model creative_writer {
            model_type: "openai";
            model_name: "gpt-4";
            temperature: 0.8;  # Higher creativity
            max_tokens: 800;
        }

        model analytical_processor {
            model_type: "anthropic";
            model_name: "claude-3-sonnet";
            temperature: 0.2;  # More focused analysis
            max_tokens: 1000;
        }

        obj MultiModelProcessor {
            def creative_summary(text: str) -> str;
            def analytical_summary(text: str) -> str;
            def compare_approaches(text: str) -> dict;
        }

        impl MultiModelProcessor.creative_summary(text: str) -> str {
            prompt = f"""
            Create an engaging, creative summary of this text that captures
            the essence while being interesting to read:

            {text}
            """;
            return prompt by creative_writer;
        }

        impl MultiModelProcessor.analytical_summary(text: str) -> str {
            prompt = f"""
            Provide a structured, analytical summary focusing on key facts,
            data points, and logical conclusions:

            {text}
            """;
            return prompt by analytical_processor;
        }

        impl MultiModelProcessor.compare_approaches(text: str) -> dict {
            return {
                "creative": self.creative_summary(text),
                "analytical": self.analytical_summary(text),
                "word_count": len(text.split())
            };
        }

        # Processing pipeline with multiple models
        def multi_model_pipeline(texts: list[str]) -> list[dict] {
            processor = MultiModelProcessor();

            return (
                texts
                |> [processor.compare_approaches(text) for text in _]
                |> [{
                    "input_length": result["word_count"],
                    "creative_length": len(result["creative"].split()),
                    "analytical_length": len(result["analytical"].split()),
                    "summaries": {
                        "creative": result["creative"],
                        "analytical": result["analytical"]
                    }
                } for result in _]
            );
        }

        with entry {
            sample_texts = [
                """
                The sunset painted the sky in brilliant oranges and purples as the
                day came to an end. Scientists have studied how atmospheric particles
                scatter light to create these beautiful displays, with shorter blue
                wavelengths scattered away during sunset hours.
                """,
                """
                Market analysis shows a 15% increase in renewable energy investments
                this quarter. Solar panel efficiency has improved by 8% while costs
                decreased by 12%, making clean energy more accessible to consumers.
                """
            ];

            results = multi_model_pipeline(sample_texts);

            for i, result in enumerate(results, 1) {
                print(f"\n=== Text {i} Analysis ===");
                print(f"Input: {result['input_length']} words");
                print(f"\nCreative Summary ({result['creative_length']} words):");
                print(result['summaries']['creative']);
                print(f"\nAnalytical Summary ({result['analytical_length']} words):");
                print(result['summaries']['analytical']);
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict, Any

        class MultiModelProcessor:
            def creative_summary(self, text: str) -> str:
                # Simulate creative model response
                return f"Creative take: {text.split('.')[0]}... [Engaging narrative style]"

            def analytical_summary(self, text: str) -> str:
                # Simulate analytical model response
                sentences = text.split('.')
                return f"Analysis: Key point - {sentences[0]}. Secondary observations follow."

            def compare_approaches(self, text: str) -> Dict[str, Any]:
                return {
                    "creative": self.creative_summary(text),
                    "analytical": self.analytical_summary(text),
                    "word_count": len(text.split())
                }

        def multi_model_pipeline(texts: List[str]) -> List[Dict[str, Any]]:
            processor = MultiModelProcessor()
            results = []

            for text in texts:
                comparison = processor.compare_approaches(text)
                result = {
                    "input_length": comparison["word_count"],
                    "creative_length": len(comparison["creative"].split()),
                    "analytical_length": len(comparison["analytical"].split()),
                    "summaries": {
                        "creative": comparison["creative"],
                        "analytical": comparison["analytical"]
                    }
                }
                results.append(result)

            return results

        if __name__ == "__main__":
            sample_texts = [
                """
                The sunset painted the sky in brilliant oranges and purples as the
                day came to an end. Scientists have studied how atmospheric particles
                scatter light to create these beautiful displays, with shorter blue
                wavelengths scattered away during sunset hours.
                """,
                """
                Market analysis shows a 15% increase in renewable energy investments
                this quarter. Solar panel efficiency has improved by 8% while costs
                decreased by 12%, making clean energy more accessible to consumers.
                """
            ]

            results = multi_model_pipeline(sample_texts)

            for i, result in enumerate(results, 1):
                print(f"\n=== Text {i} Analysis ===")
                print(f"Input: {result['input_length']} words")
                print(f"\nCreative Summary ({result['creative_length']} words):")
                print(result['summaries']['creative'])
                print(f"\nAnalytical Summary ({result['analytical_length']} words):")
                print(result['summaries']['analytical'])
        ```

## Best Practices

### Pipe Operations Best Practices

!!! summary "Pipe Operation Guidelines"
    - **Keep functions pure** - avoid side effects in pipeline functions
    - **Use meaningful names** - make the data flow readable
    - **Handle errors gracefully** - include error handling in transformations
    - **Break down complex operations** - create smaller, composable functions

### AI Integration Best Practices

!!! summary "AI Integration Guidelines"
    - **Validate responses** - always handle AI errors and unexpected outputs
    - **Use structured prompts** - be specific about expected output format
    - **Implement fallbacks** - have backup strategies when AI fails
    - **Choose appropriate models** - match model capabilities to task requirements

## Key Takeaways

!!! summary "Chapter Summary"
    - **Pipe Operations** transform nested function calls into readable, left-to-right data flows
    - **Semantic Strings** provide seamless AI integration with the `by llm()` syntax
    - **MTLLM Configuration** enables flexible model selection for different tasks
    - **Combined Power** - pipes and AI together create intelligent data processing pipelines
    - **Error Handling** - robust error handling is essential for production AI applications

In the next chapter, we'll explore advanced AI operations including multimodality support, custom model integration, and sophisticated prompt engineering techniques.
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
