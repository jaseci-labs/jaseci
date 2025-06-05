# <span style="color: orange">Fantasy Trading Game Tutorial

This tutorial demonstrates how to build an interactive fantasy RPG trading game using Jac and MTLLM. The game showcases AI-powered character generation, intelligent conversations, and a dynamic trading system where players can negotiate and complete transactions with NPCs.

## <span style="color: orange">Overview

The Fantasy Trading Game is an interactive text-based RPG that demonstrates several advanced MTLLM features:

- **AI Character Generation**: Both player and NPC characters are dynamically created using LLMs
- **Intelligent NPCs**: Non-player characters with unique personalities that can engage in conversations
- **Trading System**: A complete economic system with inventory management and transactions
- **ReAct Conversations**: NPCs that can reason about situations and take actions like making trades
- **Persistent Game State**: Character stats and inventories that persist throughout the game session

## <span style="color: orange">Game Architecture

### <span style="color: orange">Core Data Structures

The game is built around three main objects that represent the game world:

```jac
obj InventoryItem {
    has name: str;
    has price: float;
}

obj Person {
    has name: str;
    has age: int;
    has hobby: str;
    has description: str;
    has money: float;
    has inventory: list[InventoryItem];
}

obj Chat {
    has person: str;
    has message: str;
}
```

**InventoryItem** represents tradeable objects with names and prices. **Person** represents both player and NPC characters with attributes, money, and inventories. **Chat** stores conversation history to maintain context across dialogue turns.

### <span style="color: orange">LLM Configuration

```jac
import from mtllm.llms {OpenAI}

glob llm = OpenAI(model_name="gpt-4o");
```

The game uses OpenAI's GPT-4o model for all AI-powered features. You can easily switch to other models like Ollama for local inference.

## <span style="color: orange">Key Features

### <span style="color: orange">AI Character Generation

Characters are generated entirely by the LLM using simple function definitions:

```jac
"""
Generates the player character for a fantasy RPG game.
"""
def make_player() -> Person
    by llm();


"""
Generates a random npc person with a name, age, favourite pet and hobby.
The person should be a fantasy character, like an elf, dwarf, orc, etc.
"""
def make_random_npc() -> Person
    by llm();
```

The LLM automatically creates diverse fantasy characters with:
- Fantasy race characteristics (elves, dwarves, orcs, etc.)
- Unique names and personalities
- Age-appropriate backgrounds and hobbies
- Starting money and themed inventory items
- Rich character descriptions

### <span style="color: orange">Transaction System

The economic core of the game is handled by a comprehensive transaction function:

```jac
"""
Makes a transaction between buyer and seller for the specified item.
Returns true if successful, false otherwise. The price is optional,
if not provided, the item's price is used (if they negotiate to a different price that should be given here
otherwiwse the price is optional and None will be used as a default parameter.
"""
def make_transaction(buyer_name: str, seller_name: str, item_name: str, price: int| None = None) -> bool {
    buyer = person_record[buyer_name];
    seller = person_record[seller_name];

    # Find the item in seller's inventory
    item_to_buy = None;
    item_index = -1;

    for i in range(len(seller.inventory)) {
        if seller.inventory[i].name.lower() == item_name.lower() {
            item_to_buy = seller.inventory[i];
            item_index = i;
            break;
        }
    }

    price = price or item_to_buy.price;

    # Check if item exists and buyer has enough money
    if not item_to_buy or buyer.money < price {
        return False;
    }

    # Transfer item and money
    buyer.money -= price;
    seller.money += price;
    buyer.inventory.append(item_to_buy);
    seller.inventory.pop(item_index);

    return True;
}
```

This function handles:
- **Item Discovery**: Searches the seller's inventory for requested items
- **Price Negotiation**: Supports custom prices different from the item's default price
- **Validation**: Ensures the item exists and the buyer has sufficient funds
- **State Transfer**: Moves money and items between characters atomically

### <span style="color: orange">Intelligent Conversations with ReAct

The conversation system uses the ReAct (Reasoning and Acting) methodology:

```jac
"""
Generates the next line of dialogue from the given NPC in an ongoing
conversation with the player. If no chat history is provided, generates
the NPC's initial greeting. The NPC's response should reflect their
personality, background, and any prior context from the chat history.

Before making a transaction, the NPC confirm with the player and after
they said yes, the transaction is made. Make sure the NPC doesn't give
an item way way less than its price, but they can negotiate a bit.
"""
def chat_with_player(player: Person, npc: Person, chat_history: list[Chat]) -> Chat
    by llm(method="ReAct", tools=[make_transaction]);
```

ReAct enables NPCs to:
- **Think**: Reason about the conversation context and their goals
- **Act**: Use tools like `make_transaction` when appropriate
- **Observe**: Process the results of their actions
- **Respond**: Generate contextually appropriate dialogue

This creates NPCs that can:
- Remember previous conversations
- Evaluate trade proposals realistically
- Negotiate prices within reasonable bounds
- Make strategic decisions about when to trade
- Stay in character while being helpful

## <span style="color: orange">Game Flow

### <span style="color: orange">Initialization and Main Loop

```jac
with entry {
    # Generate AI-powered characters
    player = make_player();
    npc = make_random_npc();

    person_record[player.name] = player;
    person_record[npc.name] = npc;

    history = [];
    while True {
        chat = chat_with_player(player, npc, history);
        history.append(chat);

        # Display current game state
        for p in [player, npc] {
            print(p.name, ":  $", p.money);
            for i in p.inventory {
                print("  ", i.name, ":  $", i.price);
            }
        }

        print("\n[[npc]] >> ", chat.message);
        inp = input("\n[[Player input]] >> ");
        history.append(Chat(person=player.name, message=inp));
    }
}
```

The game follows this pattern:
1. **Character Creation**: Generate unique player and NPC using AI
2. **Registration**: Store characters in global registry for transactions
3. **Game Loop**: Alternate between NPC responses and player input
4. **State Display**: Show current money and inventory after each interaction
5. **History Tracking**: Maintain conversation context for realistic dialogue

## <span style="color: orange">Advanced MTLLM Features

### <span style="color: orange">Tool Integration

The game demonstrates how LLMs can seamlessly integrate with application logic through tools:

- NPCs can invoke `make_transaction` when trade discussions reach agreement
- The LLM automatically handles tool parameter extraction from natural language
- Tool results are incorporated into the conversation flow naturally

### <span style="color: orange">Dynamic Content Generation

Every aspect of the game world is dynamically generated:
- **Character Personalities**: Unique traits and speech patterns
- **Item Creation**: Contextually appropriate inventory items
- **Dialogue Generation**: Responses that feel natural and engaging

## <span style="color: orange">Running the Game

To play the Fantasy Trading Game:

1. **Prerequisites**: Install `jac-mtllm` and configure your OpenAI API key
2. **Launch**: Run `jac run fantasy_trading_game.jac`
3. **Play**: Engage with the AI-generated NPC through natural language
4. **Trade**: Negotiate prices and complete transactions organically

## <span style="color: orange">Example Gameplay

```
[[Npc]] >> Greetings, traveler! I am Thornwick the Wise, an ancient dwarf
with a passion for collecting rare gemstones. I've been mining these
mountains for over 200 years. I notice you carry yourself like an
adventurer - perhaps we could do some trading?

[[Player]] >> Hello! What do you have for sale?

[[Npc]] >> Ah, a direct sort - I like that! I have several treasures from
my decades of mining. I have a pristine Moonstone Amulet that glows with
inner light for 75 gold pieces, and a rare Dwarven Pickaxe forged by my
grandfather for 120 gold. What catches your interest, friend?
```
