<h1 style="color: orange; font-weight: bold; text-align: center;">Tour to Jac</h1>


## Beyond OOP with Data Spatial Programming

Data Spatial Programming (DSP) inverts the traditional relationship between data and computation. Rather than moving data to computation, DSP moves computation to data through topologically aware constructs. This paradigm introduces specialized archetypes—objects, nodes, edges and walkers—that model spatial relationships directly in the language and enable optimizations around data locality and distributed execution.

```jac
node GameStage { has name: str, frame_time: float = 0.0; }

walker RenderWalk {
    has fps: int = 60;

    can process with GameStage entry {
        print(f"Processing {here.name} stage");
        here.frame_time = 1000.0 / self.fps;  # ms per frame
        visit [-->];  # Move to next stage
    }
}

with entry {
    input_stage = GameStage(name="Input");

    # Create render loop cycle
    input_stage ++> GameStage(name="Update") ++> GameStage(name="Render") ++>
        GameStage(name="Present") ++> input_stage;

    RenderWalk() spawn input_stage;
}
```
A walker cycles through game stages using edges, demonstrating Data Spatial Programming for game loops.


## Programming Abstractions for AI

Jac provides novel constructs for integrating LLMs into code. A function body can simply be replaced with a call to an LLM, removing the need for prompt engineering or extensive new libraries.

```jac
import from mtllm.llms { Gemini }
glob llm = Gemini(model_name="gemini-2.0-flash");

enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert",
    AMBIVERT = "Ambivert"
}

def get_personality(name: str) -> Personality by llm();

with entry {
    name = "Albert Einstein";
    result = get_personality(name);
    print(f"{result.value} personality detected for {name}");
}
```
??? example "Output"
    ```
    Introvert personality detected for Albert Einstein
    ```

??? info "How To Run"
    1. Install the MTLLM plugin by ```pip install mtllm[google]```
    2. Save your Gemini API as an environment variable (`export GEMINI_API_KEY="xxxxxxxx"`).
    > **Note:**
    >
    > You can use OpenAI, Anthropic or other API services as well as host your own LLM using Ollama or Huggingface.
    3. Copy this code into `example.jac` file and run with `jac run example.jac`
`by llm()` delegates execution to an LLM without any extra library code.


## Zero to Infinite Scale with no Code Changes

Jac's cloud-native abstractions make persistence and user concepts part of the language so that simple programs can run unchanged locally or in the cloud. Deployments can be scaled by increasing replicas of the `jac-cloud` service when needed.

```jac
node Post { has content: str, author: str; }

walker create_post {
    has content: str, author: str;

    can with root entry {
        new_post = Post(content=self.content, author=self.author);
        here ++> new_post;
        report {"id": new_post.id, "status": "posted"};
    }
}
```
This simple social media post system runs locally or scales infinitely in the cloud with no code changes.


## Python Superset Phylosophy: All of Python Plus More

Jac is a drop-in replacement for Python and supersets Python, much like Typescript supersets Javascript or C++ supersets C. It extends Python's semantics while maintaining full interoperability with the Python ecosystem, introducing cutting-edge abstractions designed to minimize complexity and embrace AI-forward development.

```jac
import math;
import from random { uniform }

def calc_distance(x1: float, y1: float, x2: float, y2: float) -> float {
    return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

with entry {
    # Generate random points
    (x1, y1) = (uniform(0, 10), uniform(0, 10));
    (x2, y2) = (uniform(0, 10), uniform(0, 10));

    distance = calc_distance(x1, y1, x2, y2);
    area = math.pi * (distance / 2) ** 2;

    print(f"Distance: {distance:.2f}, Circle area: {area:.2f}");
}
```
This snippet natively imports python packages `math` and `random` and runs identically to its Python counterpart. Jac targets python bytecode, so all python libraries work with Jac.

## Better Organized and Well Typed Codebases

Jac focuses on type safety and readability. Type hints are required and the built-in typing system eliminates boilerplate imports. Code structure can be split across multiple files, allowing definitions and implementations to be organized separately while still being checked by Jac's native type system.

=== "tweet.jac"

    ```jac
    obj Tweet {
        has content: str, author: str, likes: int = 0, timestamp: str;

        def like() -> None;
        def unlike() -> None;
        def get_preview(max_length: int) -> str;
        def get_like_count() -> int;
    }
    ```

=== "tweet.impl.jac"

    ```jac
    impl Tweet.like() -> None {
        self.likes += 1;
    }

    impl Tweet.unlike() -> None {
        if self.likes > 0 {
            self.likes -= 1;
        }
    }

    impl Tweet.get_preview(max_length: int) -> str {
        return self.content[:max_length] + "..." if len(self.content) > max_length else self.content;
    }

    impl Tweet.get_like_count() -> int {
        return self.likes;
    }
    ```

This shows how declarations and implementations can live in separate files for maintainable, typed codebases.

<div class="grid cards" markdown>

-   __In The Works__

    ---

    *Roadmap Items*

    [In The Roadmap](bigfeatures.md){ .md-button .md-button--primary }

-   __In The Future__

    ---

    *Research in Jac/Jaseci*


    [In Research](research.md){ .md-button }


</div>

