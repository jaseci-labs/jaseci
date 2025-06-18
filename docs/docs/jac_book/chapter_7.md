# Chapter 7: Advanced AI Operations

Building on the basic AI integration from the previous chapter, this chapter explores advanced AI capabilities in Jac. We'll learn about semantic strings, multimodal AI (vision and audio), custom models, embeddings, and performance optimization. We'll demonstrate these features by building a simple image captioning tool.

!!! topic "Advanced AI Features"
    Jac's advanced AI operations enable you to build sophisticated applications that work with text, images, audio, and custom AI models with simple, intuitive syntax.

## Semantic Strings and Prompt Engineering

!!! topic "Semantic Strings"
    Semantic strings (semstrings) let you write AI prompts directly in your code using the `by llm()` syntax. They make AI integration feel natural and readable.

### Basic Semantic String Operations

!!! example "Simple AI Prompts"
    === "Jac"
        <div class="code-block">
        ```jac
        def ask_ai(question: str) -> str {
            # Simple semantic string - AI responds to the question
            return f"Please answer this question: {question}" by llm();
        }

        def summarize_text(text: str) -> str {
            # AI summarizes the given text
            return f"Summarize this text in one sentence: {text}" by llm();
        }

        with entry {
            # Ask AI questions
            answer = ask_ai("What is the capital of France?");
            print(f"Answer: {answer}");

            # Summarize text
            long_text = "Artificial intelligence is a branch of computer science that aims to create intelligent machines. It has become an essential part of the technology industry.";
            summary = summarize_text(long_text);
            print(f"Summary: {summary}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai

        def ask_ai(question: str) -> str:
            # Python requires explicit API calls
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": f"Please answer this question: {question}"}]
            )
            return response.choices[0].message.content

        def summarize_text(text: str) -> str:
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": f"Summarize this text in one sentence: {text}"}]
            )
            return response.choices[0].message.content

        if __name__ == "__main__":
            # Ask AI questions
            answer = ask_ai("What is the capital of France?")
            print(f"Answer: {answer}")

            # Summarize text
            long_text = "Artificial intelligence is a branch of computer science that aims to create intelligent machines. It has become an essential part of the technology industry."
            summary = summarize_text(long_text)
            print(f"Summary: {summary}")
        ```

### Prompt Engineering Patterns

!!! example "Better Prompts with Structure"
    === "Jac"
        <div class="code-block">
        ```jac
        def analyze_sentiment(text: str) -> str {
            # Structured prompt with clear instructions
            prompt = f"""
            Analyze the sentiment of this text and respond with exactly one word:
            - "positive" for positive sentiment
            - "negative" for negative sentiment
            - "neutral" for neutral sentiment

            Text: {text}

            Sentiment:
            """;

            return prompt by llm();
        }

        def create_story(character: str, setting: str) -> str {
            # Creative prompt with specific requirements
            story_prompt = f"""
            Write a short 2-sentence story with these elements:
            - Character: {character}
            - Setting: {setting}
            - Make it interesting and family-friendly

            Story:
            """;

            return story_prompt by llm();
        }

        with entry {
            # Test sentiment analysis
            text1 = "I love this new feature!";
            sentiment1 = analyze_sentiment(text1);
            print(f"'{text1}' -> {sentiment1}");

            # Generate a story
            story = create_story("a curious robot", "a magical library");
            print(f"Story: {story}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai

        def analyze_sentiment(text: str) -> str:
            prompt = f"""
            Analyze the sentiment of this text and respond with exactly one word:
            - "positive" for positive sentiment
            - "negative" for negative sentiment
            - "neutral" for neutral sentiment

            Text: {text}

            Sentiment:
            """

            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}]
            )
            return response.choices[0].message.content.strip()

        def create_story(character: str, setting: str) -> str:
            story_prompt = f"""
            Write a short 2-sentence story with these elements:
            - Character: {character}
            - Setting: {setting}
            - Make it interesting and family-friendly

            Story:
            """

            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": story_prompt}]
            )
            return response.choices[0].message.content

        if __name__ == "__main__":
            # Test sentiment analysis
            text1 = "I love this new feature!"
            sentiment1 = analyze_sentiment(text1)
            print(f"'{text1}' -> {sentiment1}")

            # Generate a story
            story = create_story("a curious robot", "a magical library")
            print(f"Story: {story}")
        ```

## Multimodality Support (Vision, Audio)

!!! topic "Multimodal AI"
    Jac can work with images, audio, and text all in the same application. This enables powerful applications like image captioning, audio transcription, and content analysis.

### Vision and Image Processing

!!! example "Simple Image Analysis"
    === "Jac"
        <div class="code-block">
        ```jac
        def describe_image(image_path: str) -> str {
            # AI looks at an image and describes it
            prompt = f"""
            Look at this image and describe what you see in one sentence.

            Image: {image_path}
            """;

            return prompt by llm(model="vision-model");
        }

        def find_objects(image_path: str) -> str {
            # Find objects in the image
            prompt = f"""
            List the main objects you can see in this image.

            Image: {image_path}

            Objects:
            """;

            return prompt by llm(model="vision-model");
        }

        with entry {
            # Analyze an image (this would work with a real image file)
            image_file = "photo.jpg";

            description = describe_image(image_file);
            print(f"Image description: {description}");

            objects = find_objects(image_file);
            print(f"Objects found: {objects}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai
        import base64

        def describe_image(image_path: str) -> str:
            # Python requires more setup for vision
            with open(image_path, "rb") as image_file:
                image_data = base64.b64encode(image_file.read()).decode()

            response = openai.ChatCompletion.create(
                model="gpt-4-vision-preview",
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Look at this image and describe what you see in one sentence."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}
                    ]
                }]
            )
            return response.choices[0].message.content

        def find_objects(image_path: str) -> str:
            with open(image_path, "rb") as image_file:
                image_data = base64.b64encode(image_file.read()).decode()

            response = openai.ChatCompletion.create(
                model="gpt-4-vision-preview",
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "List the main objects you can see in this image."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}
                    ]
                }]
            )
            return response.choices[0].message.content

        if __name__ == "__main__":
            # This would work with a real image file
            image_file = "photo.jpg"

            try:
                description = describe_image(image_file)
                print(f"Image description: {description}")

                objects = find_objects(image_file)
                print(f"Objects found: {objects}")
            except FileNotFoundError:
                print("Image file not found - this is just an example")
        ```

### Audio Processing

!!! example "Audio Transcription and Analysis"
    === "Jac"
        <div class="code-block">
        ```jac
        def transcribe_audio(audio_path: str) -> str {
            # Convert speech to text
            prompt = f"""
            Transcribe the speech in this audio file.

            Audio: {audio_path}
            """;

            return prompt by llm(model="audio-model");
        }

        def analyze_audio_mood(audio_path: str) -> str {
            # Analyze the emotional tone of speech
            prompt = f"""
            Listen to this audio and describe the speaker's mood in one word.

            Audio: {audio_path}
            """;

            return prompt by llm(model="audio-model");
        }

        with entry {
            # Process an audio file (this would work with a real audio file)
            audio_file = "recording.mp3";

            transcription = transcribe_audio(audio_file);
            print(f"Transcription: {transcription}");

            mood = analyze_audio_mood(audio_file);
            print(f"Speaker mood: {mood}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai

        def transcribe_audio(audio_path: str) -> str:
            # Python requires explicit audio file handling
            with open(audio_path, "rb") as audio_file:
                transcript = openai.Audio.transcribe("whisper-1", audio_file)
            return transcript.text

        def analyze_audio_mood(audio_path: str) -> str:
            # First transcribe, then analyze mood
            transcription = transcribe_audio(audio_path)

            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{
                    "role": "user",
                    "content": f"Analyze the mood in this transcription and respond with one word: {transcription}"
                }]
            )
            return response.choices[0].message.content

        if __name__ == "__main__":
            # This would work with a real audio file
            audio_file = "recording.mp3"

            try:
                transcription = transcribe_audio(audio_file)
                print(f"Transcription: {transcription}")

                mood = analyze_audio_mood(audio_file)
                print(f"Speaker mood: {mood}")
            except FileNotFoundError:
                print("Audio file not found - this is just an example")
        ```

## Custom Model Integration

!!! topic "Custom Models"
    You can connect Jac to different AI models and services, including your own custom models, for specialized tasks.

### Model Configuration

!!! example "Using Different AI Models"
    === "Jac"
        <div class="code-block">
        ```jac
        import:py os;

        # Configure different AI models
        model fast_model {
            model_type: "openai";
            model_name: "gpt-3.5-turbo";
            temperature: 0.5;
            api_key: os.getenv("OPENAI_API_KEY");
        }

        model creative_model {
            model_type: "anthropic";
            model_name: "claude-3-sonnet";
            temperature: 0.8;
            api_key: os.getenv("ANTHROPIC_API_KEY");
        }

        def quick_answer(question: str) -> str {
            # Use fast model for simple questions
            return f"Answer briefly: {question}" by fast_model;
        }

        def creative_response(topic: str) -> str {
            # Use creative model for storytelling
            return f"Write a creative paragraph about: {topic}" by creative_model;
        }

        with entry {
            # Test different models
            answer = quick_answer("What is 2+2?");
            print(f"Quick answer: {answer}");

            story = creative_response("a magical forest");
            print(f"Creative story: {story}");
        }
        ```
        </div>
    === "Python"
        ```python
        import os
        import openai
        import anthropic

        class ModelManager:
            def __init__(self):
                self.openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
                self.anthropic_client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

            def quick_answer(self, question: str) -> str:
                response = self.openai_client.chat.completions.create(
                    model="gpt-3.5-turbo",
                    messages=[{"role": "user", "content": f"Answer briefly: {question}"}],
                    temperature=0.5
                )
                return response.choices[0].message.content

            def creative_response(self, topic: str) -> str:
                response = self.anthropic_client.messages.create(
                    model="claude-3-sonnet-20240229",
                    messages=[{"role": "user", "content": f"Write a creative paragraph about: {topic}"}],
                    temperature=0.8,
                    max_tokens=1000
                )
                return response.content[0].text

        if __name__ == "__main__":
            manager = ModelManager()

            try:
                answer = manager.quick_answer("What is 2+2?")
                print(f"Quick answer: {answer}")

                story = manager.creative_response("a magical forest")
                print(f"Creative story: {story}")
            except Exception as e:
                print(f"Error: {e}")
        ```

## Embedding and Vector Operations

!!! topic "Embeddings"
    Embeddings turn text into numbers that capture meaning. This enables semantic search - finding text that means similar things, even if the words are different.

### Semantic Search

!!! example "Simple Semantic Search"
    === "Jac"
        <div class="code-block">
        ```jac
        obj SimpleSearchEngine {
            has documents: list[str] = [];

            def add_document(text: str) -> None {
                self.documents.append(text);
            }

            def search(query: str) -> str {
                # AI finds the most relevant document
                docs_text = "\n".join([f"{i}: {doc}" for (i, doc) in enumerate(self.documents)]);

                prompt = f"""
                Find the document that best matches this query: "{query}"

                Documents:
                {docs_text}

                Return only the number of the best matching document.
                """;

                result = prompt by llm();

                try {
                    doc_index = int(result.strip());
                    if 0 <= doc_index < len(self.documents) {
                        return self.documents[doc_index];
                    }
                } except ValueError {
                    pass;
                }

                return "No matching document found";
            }
        }

        with entry {
            # Create a simple search engine
            search_engine = SimpleSearchEngine();

            # Add some documents
            search_engine.add_document("How to bake chocolate cookies");
            search_engine.add_document("Training your dog to sit");
            search_engine.add_document("Best practices for growing tomatoes");
            search_engine.add_document("Learning to play guitar chords");

            # Search for similar content
            result = search_engine.search("cooking desserts");
            print(f"Search result: {result}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai
        from typing import List

        class SimpleSearchEngine:
            def __init__(self):
                self.documents: List[str] = []
                self.client = openai.OpenAI()

            def add_document(self, text: str) -> None:
                self.documents.append(text)

            def search(self, query: str) -> str:
                # AI finds the most relevant document
                docs_text = "\n".join([f"{i}: {doc}" for i, doc in enumerate(self.documents)])

                prompt = f"""
                Find the document that best matches this query: "{query}"

                Documents:
                {docs_text}

                Return only the number of the best matching document.
                """

                response = self.client.chat.completions.create(
                    model="gpt-3.5-turbo",
                    messages=[{"role": "user", "content": prompt}]
                )

                result = response.choices[0].message.content

                try:
                    doc_index = int(result.strip())
                    if 0 <= doc_index < len(self.documents):
                        return self.documents[doc_index]
                except ValueError:
                    pass

                return "No matching document found"

        if __name__ == "__main__":
            # Create a simple search engine
            search_engine = SimpleSearchEngine()

            # Add some documents
            search_engine.add_document("How to bake chocolate cookies")
            search_engine.add_document("Training your dog to sit")
            search_engine.add_document("Best practices for growing tomatoes")
            search_engine.add_document("Learning to play guitar chords")

            # Search for similar content
            try:
                result = search_engine.search("cooking desserts")
                print(f"Search result: {result}")
            except Exception as e:
                print(f"Error: {e}")
        ```

## Performance Considerations

!!! topic "AI Performance"
    AI operations can be slow and expensive. Here are simple ways to make them faster and cheaper.

### Simple Optimization Techniques

!!! example "Basic AI Performance Tips"
    === "Jac"
        <div class="code-block">
        ```jac
        import:py time;

        # Cache AI responses to avoid repeated calls
        glob ai_cache: dict[str, str] = {};

        def cached_ai_call(prompt: str) -> str {
            # Check if we already asked this question
            if prompt in ai_cache {
                print("Using cached response");
                return ai_cache[prompt];
            }

            # Make AI call and cache result
            response = prompt by llm();
            ai_cache[prompt] = response;
            return response;
        }

        def time_ai_call(prompt: str) -> tuple[str, float] {
            # Measure how long AI takes
            start_time = time.time();
            result = prompt by llm();
            end_time = time.time();

            duration = end_time - start_time;
            return (result, duration);
        }

        with entry {
            # Test caching
            question = "What is the largest planet?";

            # First call (slow)
            response1 = cached_ai_call(question);
            print(f"First call: {response1}");

            # Second call (fast - from cache)
            response2 = cached_ai_call(question);
            print(f"Second call: {response2}");

            # Test timing
            (result, duration) = time_ai_call("Tell me a fun fact");
            print(f"AI took {duration:.2f} seconds: {result}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai
        import time
        from typing import Dict, Tuple

        # Cache AI responses to avoid repeated calls
        ai_cache: Dict[str, str] = {}

        def cached_ai_call(prompt: str) -> str:
            # Check if we already asked this question
            if prompt in ai_cache:
                print("Using cached response")
                return ai_cache[prompt]

            # Make AI call and cache result
            client = openai.OpenAI()
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}]
            )

            result = response.choices[0].message.content
            ai_cache[prompt] = result
            return result

        def time_ai_call(prompt: str) -> Tuple[str, float]:
            # Measure how long AI takes
            start_time = time.time()

            client = openai.OpenAI()
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}]
            )

            end_time = time.time()
            result = response.choices[0].message.content
            duration = end_time - start_time

            return (result, duration)

        if __name__ == "__main__":
            try:
                # Test caching
                question = "What is the largest planet?"

                # First call (slow)
                response1 = cached_ai_call(question)
                print(f"First call: {response1}")

                # Second call (fast - from cache)
                response2 = cached_ai_call(question)
                print(f"Second call: {response2}")

                # Test timing
                result, duration = time_ai_call("Tell me a fun fact")
                print(f"AI took {duration:.2f} seconds: {result}")

            except Exception as e:
                print(f"Error: {e}")
        ```

## Complete Example: Simple Image Captioning Tool

!!! example "Image Caption Generator"
    === "Jac"
        <div class="code-block">
        ```jac
        obj ImageCaptioner {
            def generate_caption(image_path: str) -> str {
                # Generate a basic caption for an image
                prompt = f"""
                Look at this image and write a simple caption describing what you see.
                Keep it to one sentence.

                Image: {image_path}
                """;

                return prompt by llm(model="vision-model");
            }

            def generate_detailed_description(image_path: str) -> str {
                # Generate a more detailed description
                prompt = f"""
                Describe this image in detail. Include:
                - What objects or people you see
                - The setting or location
                - Any activities happening
                - The mood or atmosphere

                Image: {image_path}
                """;

                return prompt by llm(model="vision-model");
            }

            def make_accessible_text(image_path: str) -> str {
                # Generate text for screen readers
                prompt = f"""
                Create alt text for this image that would help a visually impaired person understand what's in the picture.
                Be descriptive but concise.

                Image: {image_path}
                """;

                return prompt by llm(model="vision-model");
            }
        }

        with entry {
            # Create the captioner
            captioner = ImageCaptioner();

            # Example with a hypothetical image
            image_file = "family_photo.jpg";

            print("=== Image Captioning Tool ===");

            # Generate different types of captions
            caption = captioner.generate_caption(image_file);
            print(f"Caption: {caption}");

            description = captioner.generate_detailed_description(image_file);
            print(f"Detailed: {description}");

            alt_text = captioner.make_accessible_text(image_file);
            print(f"Alt text: {alt_text}");
        }
        ```
        </div>
    === "Python"
        ```python
        import openai
        import base64
        from typing import Optional

        class ImageCaptioner:
            def __init__(self):
                self.client = openai.OpenAI()

            def _encode_image(self, image_path: str) -> str:
                """Helper to encode image for API"""
                with open(image_path, "rb") as image_file:
                    return base64.b64encode(image_file.read()).decode()

            def generate_caption(self, image_path: str) -> str:
                try:
                    image_data = self._encode_image(image_path)

                    response = self.client.chat.completions.create(
                        model="gpt-4-vision-preview",
                        messages=[{
                            "role": "user",
                            "content": [
                                {"type": "text", "text": "Look at this image and write a simple caption describing what you see. Keep it to one sentence."},
                                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}
                            ]
                        }]
                    )

                    return response.choices[0].message.content

                except FileNotFoundError:
                    return "Image file not found"
                except Exception as e:
                    return f"Error: {e}"

            def generate_detailed_description(self, image_path: str) -> str:
                try:
                    image_data = self._encode_image(image_path)

                    response = self.client.chat.completions.create(
                        model="gpt-4-vision-preview",
                        messages=[{
                            "role": "user",
                            "content": [
                                {"type": "text", "text": "Describe this image in detail. Include what objects or people you see, the setting, any activities, and the mood."},
                                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}
                            ]
                        }]
                    )

                    return response.choices[0].message.content

                except FileNotFoundError:
                    return "Image file not found"
                except Exception as e:
                    return f"Error: {e}"

            def make_accessible_text(self, image_path: str) -> str:
                try:
                    image_data = self._encode_image(image_path)

                    response = self.client.chat.completions.create(
                        model="gpt-4-vision-preview",
                        messages=[{
                            "role": "user",
                            "content": [
                                {"type": "text", "text": "Create alt text for this image that would help a visually impaired person understand what's in the picture. Be descriptive but concise."},
                                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}}
                            ]
                        }]
                    )

                    return response.choices[0].message.content

                except FileNotFoundError:
                    return "Image file not found"
                except Exception as e:
                    return f"Error: {e}"

        if __name__ == "__main__":
            # Create the captioner
            captioner = ImageCaptioner()

            # Example with a hypothetical image
            image_file = "family_photo.jpg"

            print("=== Image Captioning Tool ===")

            # Generate different types of captions
            caption = captioner.generate_caption(image_file)
            print(f"Caption: {caption}")

            description = captioner.generate_detailed_description(image_file)
            print(f"Detailed: {description}")

            alt_text = captioner.make_accessible_text(image_file)
            print(f"Alt text: {alt_text}")
        ```

## Key Takeaways

!!! summary "Chapter Summary"
    - **Semantic Strings**: Use `by llm()` to add AI to your programs naturally
    - **Multimodal AI**: Work with images, audio, and text in the same application
    - **Custom Models**: Connect to different AI services for specialized tasks
    - **Embeddings**: Enable semantic search to find meaning, not just keywords
    - **Performance**: Cache responses and time operations to optimize AI usage
    - **Simple Examples**: Start with basic AI features and build up complexity gradually

Advanced AI operations in Jac make it easy to build intelligent applications without complex setup. The natural syntax and multimodal support enable you to create sophisticated tools with just a few lines of code.

In the next chapter, we'll move into Object-Spatial Programming concepts, starting with enhanced object-oriented features that form the foundation for Jac's revolutionary approach to programming.
