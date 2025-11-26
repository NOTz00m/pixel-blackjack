# Pixel Blackjack - Card Assets Setup Guide

This document explains how to set up your custom card images for the Pixel Blackjack game.

## Folder Structure

Place your card images in the following location:
```
res://assets/cards/
```

## Required Files

### Card Front Images (52 total)
Use this naming convention:
```
{rank}_{suit}.png
```

Where:
- **rank**: `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `10`, `jack`, `queen`, `king`, `ace`
- **suit**: `hearts`, `diamonds`, `clubs`, `spades`

Examples:
- `2_hearts.png`
- `10_spades.png`
- `jack_diamonds.png`
- `queen_clubs.png`
- `king_hearts.png`
- `ace_spades.png`

### Card Back Image
```
card_back.png
```

## Complete File List

```
assets/cards/
├── card_back.png
├── 2_hearts.png
├── 2_diamonds.png
├── 2_clubs.png
├── 2_spades.png
├── 3_hearts.png
├── 3_diamonds.png
├── 3_clubs.png
├── 3_spades.png
├── 4_hearts.png
├── 4_diamonds.png
├── 4_clubs.png
├── 4_spades.png
├── 5_hearts.png
├── 5_diamonds.png
├── 5_clubs.png
├── 5_spades.png
├── 6_hearts.png
├── 6_diamonds.png
├── 6_clubs.png
├── 6_spades.png
├── 7_hearts.png
├── 7_diamonds.png
├── 7_clubs.png
├── 7_spades.png
├── 8_hearts.png
├── 8_diamonds.png
├── 8_clubs.png
├── 8_spades.png
├── 9_hearts.png
├── 9_diamonds.png
├── 9_clubs.png
├── 9_spades.png
├── 10_hearts.png
├── 10_diamonds.png
├── 10_clubs.png
├── 10_spades.png
├── jack_hearts.png
├── jack_diamonds.png
├── jack_clubs.png
├── jack_spades.png
├── queen_hearts.png
├── queen_diamonds.png
├── queen_clubs.png
├── queen_spades.png
├── king_hearts.png
├── king_diamonds.png
├── king_clubs.png
├── king_spades.png
├── ace_hearts.png
├── ace_diamonds.png
├── ace_clubs.png
└── ace_spades.png
```

## Image Specifications

### Recommended Resolution
For pixel art style:
- **Small**: 32x48 pixels (2:3 ratio) - Good for small screens
- **Medium**: 64x96 pixels (2:3 ratio) - **Recommended**
- **Large**: 128x192 pixels (2:3 ratio) - For high-res displays

### Format
- Use **PNG** format with transparency
- Enable **Nearest Neighbor** filtering in Godot for crisp pixels

### Import Settings in Godot
When you import your card images, configure these settings:

1. Select your image files in the FileSystem dock
2. Go to the **Import** tab
3. Set the following:
   - **Filter**: `Nearest` (for pixel art)
   - **Mipmaps**: `Off`
   - **Process > Fix Alpha Border**: `On`
4. Click **Reimport**

Alternatively, create a `.import` file template or use this `.gdignore` pattern.

## Using Existing Card Assets

If your existing card images use a different naming convention, you can:

### Option 1: Rename your files
Use a batch rename tool to match the expected format.

### Option 2: Modify the card.gd script
Edit the `_load_card_textures()` function in `scripts/game/card.gd`:

```gdscript
func _load_card_textures() -> void:
    # Modify this line to match your naming convention
    var front_path: String = "res://assets/cards/%s_%s.png" % [rank.to_lower(), suit.to_lower()]
    
    # Alternative formats you might use:
    # var front_path: String = "res://assets/cards/%s_of_%s.png" % [rank, suit]
    # var front_path: String = "res://assets/cards/card_%s%s.png" % [rank, suit[0]]
```

## Creating Placeholder Cards

If you don't have card images yet, the game will still run but cards won't display textures. You can create simple placeholder cards using any pixel art tool:

### Tools Recommended:
- **Aseprite** (paid, excellent for pixel art)
- **Piskel** (free, browser-based)
- **GIMP** (free, with grid/pixel settings)
- **GraphicsGale** (free)
- **Pyxel Edit** (paid)

### Quick Placeholder Design:
1. Create a 64x96 canvas
2. Draw a white rectangle with rounded corners
3. Add the rank number/letter in the top-left
4. Add a small suit symbol below the rank
5. Export as PNG with the correct naming

## Existing Playing Card Assets

I notice you have a `assets/playing_cards/` folder with `black/` and `white/` subfolders. To use these:

1. Check the current naming convention in those folders
2. Either:
   - Copy/rename files to `assets/cards/` with the correct naming
   - Modify `card.gd` to point to your existing location and naming

## Project Settings for Pixel Art

The `project.godot` file has been configured with these pixel-perfect settings:

```ini
[display]
window/size/viewport_width=640
window/size/viewport_height=480
window/size/window_width_override=1280
window/size/window_height_override=960
window/stretch/mode="viewport"
window/stretch/aspect="keep"

[rendering]
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
```

This ensures:
- Crisp, unblurred pixels
- Consistent scaling at any window size
- Pixel-perfect positioning of sprites
