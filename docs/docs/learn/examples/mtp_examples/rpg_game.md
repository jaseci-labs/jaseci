# <span style="color: orange">Code Walkthrough: AI-Powered Game Level Generation

Welcome to the fascinating world of AI-driven game development! In this walkthrough, we'll explore how Large Language Models (LLMs) can be seamlessly integrated into code to generate dynamic game levels. We'll dive deep into the `by llm` syntax, examine how structured datatypes provide crucial context to AI models, and see how it all comes together in a complete level generation system. The full implementation of the game is available in the [github repo](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/rpg_game).

<div align="center">
  <video width="480" height="300" autoplay loop muted playsinline>
    <source src="/learn/examples/mtp_examples/assets/rpg_demo.mp4" type="video/mp4">
    Your browser does not support the video tag.
  </video>
</div>

## <span style="color: orange">The Power of `by llm` - Delegating Logic to AI

At the heart of this magic are two crucial `by llm` method definitions that delegate complex game logic entirely to the AI:

```jac
def create_next_level (last_levels: list[Level], difficulty: int, level_width: int, level_height: int)
-> Level by llm();

def create_next_map(level: Level) -> Map by llm();
```

Let's break these down to understand what's happening under the hood.

### <span style="color: orange">The Level Creation Method

```jac
def create_next_level (last_levels: list[Level], difficulty: int, level_width: int, level_height: int)
-> Level by llm();
```

This method is absolutely brilliant in its simplicity. Notice what we're NOT doing here - there's no complex procedural generation algorithm, no rule-based systems, no hardcoded patterns. Instead, we're giving the LLM:

- **Historical Context**: `last_levels: list[Level]` - The AI can see what levels were previously generated, allowing it to create variety and progression
- **Difficulty Guidance**: `difficulty: int` - A simple integer that the AI interprets to scale challenge appropriately
- **Spatial Constraints**: `level_width: int, level_height: int` - Boundaries that the AI must respect
- **Expected Output**: `-> Level` - The AI knows exactly what structure it needs to return

The LLM processes this information and generates a completely new `Level` object with appropriate attributes for the given difficulty and dimensions.

### <span style="color: orange">The Map Generation Method

```jac
def create_next_map(level: Level) -> Map by llm();
```

This is where the real magic happens. The AI takes a high-level `Level` configuration and transforms it into a detailed `Map` with specific positions for walls, enemies, and the player. The LLM understands:

- The level's constraints (width, height, difficulty)
- How many walls and enemies should be placed
- Where to position elements for balanced gameplay
- How to create a playable and challenging layout

## <span style="color: orange">How Datatypes Become AI Context

The structured datatypes aren't just code organization - they're the secret sauce that makes the AI understand our domain. Let's examine how each datatype provides crucial context:

### <span style="color: orange">Foundation: Position and Spatial Understanding

```jac
obj Position {
    has x: int, y: int;
}
```

This simple structure teaches the AI about 2D coordinate systems. When the LLM sees `Position`, it immediately understands spatial relationships, boundaries, and movement constraints.

### <span style="color: orange">Building Blocks: Walls and Obstacles

```jac
obj Wall {
    has start_pos: Position, end_pos: Position;
}
```

By defining walls with start and end positions, we're teaching the AI about:
- Linear structures in game spaces
- How walls can form corridors, rooms, and barriers
- Spatial constraints for player movement

### <span style="color: orange">Game Configuration: The Level Object

```jac
obj Level {
    has name: str, difficulty: int;
    has width: int, height: int, num_wall: int, num_enemies: int;
    has time_countdown: int, n_retries_allowed: int;
}
```

This is where the AI learns about game design principles:
- **Difficulty Scaling**: Higher difficulty should mean more enemies, complex layouts
- **Spatial Design**: Width and height define the playground
- **Game Balance**: Number of walls vs. open space, enemy density
- **Player Experience**: Time pressure and retry mechanics

### <span style="color: orange">The Complete Picture: Map Object

```jac
obj Map {
    has level: Level, walls: list[Wall], small_obstacles: list[Position];
    has enemies: list[Position];
    has player_pos: Position;
}
```

This structure gives the AI a complete mental model of a game level:
- **Hierarchical Understanding**: A map belongs to a level
- **Element Relationships**: How walls, obstacles, enemies, and player interact
- **Spatial Distribution**: Lists of positions create patterns and layouts
- **Game Flow**: Player positioning relative to challenges

## <span style="color: orange">The Level Manager: Orchestrating AI-Driven Generation

Now let's see how the `LevelManager` brings everything together:

```jac
obj LevelManager {
    has current_level: int = 0, current_difficulty: int = 1,
        prev_levels: list[Level] = [], prev_level_maps: list[Map] = [];

    // ...by llm methods defined above...

    def get_next_level -> tuple(Level, Map) {
        self.current_level += 1;
        # Keeping Only the Last 3 Levels
        if len(self.prev_levels) > 3 {
            self.prev_levels.pop(0);
            self.prev_level_maps.pop(0);
        }
        # Generating the New Level
        new_level = self.create_next_level(
            self.prev_levels,
            self.current_difficulty,
            20, 20
        );

        self.prev_levels.append(new_level);
        # Generating the Map of the New Level
        new_level_map = self.create_next_map(new_level);
        self.prev_level_maps.append(new_level_map);
        # Increasing the Difficulty for end of every 2 Levels
        if self.current_level % 2 == 0 {
            self.current_difficulty += 1;
        }
        return (new_level, new_level_map);
    }
}
```

### <span style="color: orange">The Intelligence Behind the Scenes

The `LevelManager` implements several clever design patterns:

1. **Memory Management**: Only keeps the last 3 levels to provide recent context without overwhelming the AI
2. **Progressive Difficulty**: Automatically scales challenge every 2 levels
3. **Two-Phase Generation**: First creates the level concept, then generates the detailed map
4. **Context Preservation**: Maintains history for the AI to create varied, non-repetitive content

### <span style="color: orange">Converting AI Output to Game Format

Finally, the `get_map` function transforms the AI-generated `Map` object into actual game tiles:

```jac
def get_map(map: Map) -> str {
    map_tiles = [['.' for _ in range(map.level.width)] for _ in range(map.level.height)];

    # Place walls
    for wall in map.walls {
        for x in range(wall.start_pos.x, wall.end_pos.x + 1) {
            for y in range(wall.start_pos.y, wall.end_pos.y + 1) {
                map_tiles[y-1][x-1] = 'B';
            }
        }
    }

    # Place obstacles, enemies, and player
    for obs in map.small_obstacles {
        map_tiles[obs.y-1][obs.x-1] = 'B';
    }
    for enemy in map.enemies {
        map_tiles[enemy.y-1][enemy.x-1] = 'E';
    }
    map_tiles[map.player_pos.y-1][map.player_pos.x-1] = 'P';

    # Add border walls
    map_tiles = [['B'] + row + ['B'] for row in map_tiles];
    map_tiles = [['B' for _ in range(map.level.width + 2)]] + map_tiles + [['B' for _ in range(map.level.width + 2)]];
    return [''.join(row) for row in map_tiles];
}
```

This function demonstrates how structured AI output gets converted into the visual representation that players actually see and interact with.

## <span style="color: orange">The Complete Integration

The beauty of this system lies in how the LLM understands the entire domain through these datatypes. When `create_next_level` is called, the AI doesn't just generate random numbers - it considers:

- Game progression (from previous levels)
- Player challenge curve (difficulty scaling)
- Spatial constraints (dimensions)
- Balanced gameplay (enemy count, wall placement)

When `create_next_map` is called, the AI takes that high-level design and creates:

- Strategic wall placement for interesting navigation
- Enemy positioning that creates meaningful challenges
- Player spawn points that feel fair but not trivial
- Spatial flow that encourages exploration

## <span style="color: orange">Wrapping Up

This walkthrough demonstrates the incredible power of combining structured datatypes with AI delegation. The `by llm` syntax isn't just about avoiding implementation - it's about leveraging AI's pattern recognition and creative capabilities to solve complex design problems. The datatypes become the vocabulary through which we communicate game design concepts to the AI, resulting in dynamic, engaging, and well-balanced game content.

The next time you're building complex systems, consider: what if instead of hardcoding the logic, you defined the structure and let AI fill in the creativity?