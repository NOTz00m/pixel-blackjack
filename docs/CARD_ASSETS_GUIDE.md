# Pixel Blackjack - Card Assets Setup Guide

This document explains the card image format used in the Pixel Blackjack game.

## Current Asset Structure

Your card images are located at:
```
res://assets/playing_cards/black/   <- Black-styled cards (currently used)
res://assets/playing_cards/white/   <- White-styled cards (alternative)
```

## Naming Convention

The game expects cards named in this format:
```
{Suit}_{Rank}_{style}.png
```

### Suits
| Game Internal | Asset Name |
|---------------|------------|
| hearts        | Hearts     |
| diamonds      | Tiles      |
| clubs         | Clovers    |
| spades        | Pikes      |

### Ranks
| Game Internal | Asset Name |
|---------------|------------|
| 2-10          | 2-10       |
| ace           | A          |
| jack          | Jack       |
| queen         | Queen      |
| king          | King       |

### Examples
- Ace of Hearts: `Hearts_A_black.png`
- 10 of Clubs: `Clovers_10_black.png`
- Queen of Spades: `Pikes_Queen_black.png`
- 7 of Diamonds: `Tiles_7_black.png`

## Card Back
The card back is: `g3771.png` in the same folder.

## Switching Card Styles

To switch between black and white card styles, edit `scripts/game/card.gd`:

```gdscript
# Find this line in _load_card_textures():
var card_style: String = "black"

# Change to:
var card_style: String = "white"
```

## Card Dimensions

Your cards are 655x930 pixels. The game automatically scales them to fit the table (target width: 60 pixels by default).

To adjust card size, modify in `scripts/game/card.gd`:
```gdscript
@export var target_card_width: float = 60.0  # Change this value
```

## Import Settings

For pixel-perfect rendering, ensure your card images use these import settings in Godot:
1. Select card images in FileSystem
2. Go to Import tab
3. Set Filter to "Nearest"
4. Click "Reimport"

The project's `.import` files should already have this configured.
