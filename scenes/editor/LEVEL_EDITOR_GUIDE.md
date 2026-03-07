# Level Editor Guide

## Quick Start

1. Open `scenes/editor/level_editor.tscn` in Godot
2. Select **TilesetGenerator** node, check **Generate** in Inspector to create the tileset
3. Select each TileMapLayer and assign `res://resources/editor_tileset.tres`:
   - **TilesLayer**: Set source to Source 0 (tile types)
   - **HeightsLayer**: Set source to Source 1 (heights)
   - **EntitiesLayer**: Set source to Source 2 (entities)
4. Paint tiles using Godot's TileMap painting tools
5. Configure export settings on the **LevelEditor** root node
6. Check **Do Export** to generate JSON

## Tile Types (TilesLayer - Source 0)

| Atlas X | Type | Color | Description |
|---------|------|-------|-------------|
| 0 | FLOOR | Green | Normal walkable ground |
| 1 | PIT | Dark | Instant death hole |
| 2 | BOUNCE | Yellow | Launches player upward |
| 3 | CHECKPOINT | Blue | Respawn point |
| 4 | DOOR_OPEN | Bright green | Segment transition |
| 5 | DOOR_CLOSED | Brown | Requires key to open |
| 6 | WATER | Blue | Slows movement |
| 7 | ICE | White-blue | Reduced friction |

## Height Values (HeightsLayer - Source 1)

| Atlas X | Height | Color |
|---------|--------|-------|
| 0 | 0 | Gray |
| 1 | 4 | Yellow-gray |
| 2 | 8 | Orange-gray |
| 3 | 12 | Red-gray |

Paint heights on the same cells as tiles. Cells without height default to 0.

## Entities (EntitiesLayer - Source 2)

| Atlas X | Type | Color | Description |
|---------|------|-------|-------------|
| 0 | pickup | Gold | Collectible orb |
| 1 | key | Magenta | Key for locked doors |
| 2 | goal | Green | Level exit gate |
| 3 | checkpoint | Blue | Checkpoint marker |
| 4 | enemy | Blue | Nibbler (flying) |
| 5 | ground_enemy | Yellow | Ground patrol enemy |
| 6 | enemy_hopper | Green | Frog that jumps |
| 7 | enemy_buzzfly | Yellow | Flying sine wave |
| 8 | boss | Red | Generic boss |
| 9 | boss_king_ribbit | Dark green | World 1 boss |
| 10 | player_start | Cyan | Player spawn point |

## Multi-Segment Levels

For levels with multiple segments (doors connecting areas):
1. Create one editor scene per segment
2. Export each segment individually
3. Manually combine the JSON files, adding connections between segments

Connection format in JSON:
```json
"connections": [
    {"door_pos": [14, 5], "target_segment": "main", "target_pos": [1, 5]}
]
```

## Tips

- Every level needs at least one `goal` entity and enough `pickup` entities
- Place `player_start` to set where the player spawns
- `DOOR_OPEN` tiles should match connection `door_pos` coordinates
- Boss levels can have 0 pickups — the goal activates when the boss dies
- For `DOOR_CLOSED` tiles, make sure there are enough `key` entities in the level
