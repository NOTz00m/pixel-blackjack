# Pixel Blackjack

A pixelated blackjack game built with Godot 4.5.

### Standard Blackjack
- Beat the dealer by getting closer to 21 without going over
- Face cards (Jack, Queen, King) are worth 10
- Aces are worth 11 or 1 (automatically chosen)
- Dealer stands on 17 and above

### Player Actions
- **Hit**: Draw another card
- **Stand**: Keep your current hand
- **Double Down**: Double your bet, receive exactly one more card
- **Split**: If you have two cards of the same value, split into two hands
- **Insurance**: When dealer shows an Ace, bet half your original bet against dealer blackjack (pays 2:1)
- **Surrender**: Forfeit half your bet on your first decision (early surrender)

### Payouts
- **Blackjack (21 with 2 cards)**: 3:2
- **Normal Win**: 1:1
- **Insurance Win**: 2:1
- **Push (Tie)**: Bet returned

## How to Run

1. Open the project in Godot 4.5+
2. The main scene is `scenes/main.tscn`
3. Press **F5** to run

## Controls

- **Click chips** to add to your bet ($5, $10, $25, $50, $100)
- **Clear** to reset bet
- **Deal** to start the round
- **Action buttons** appear during your turn

## Save Data

Saves are stored at: `user://blackjack_save.json`

On Windows: `%APPDATA%\Godot\app_userdata\Pixel Blackjack\blackjack_save.json`

## Customization

### Changing Card Style
In `scripts/game/card.gd`, change the `card_style` variable:
```gdscript
var card_style: String = "black"  # or "white"
```

### Adjusting Card Size
In `scripts/game/card.gd`, modify:
```gdscript
@export var target_card_width: float = 60.0  # Pixels
```

### Table Configuration
Edit `TABLE_CONFIG` in `scripts/autoload/game_manager.gd` to add or modify tables.

## License

MIT License - Feel free to use and modify for your own projects.
