class_name MapGenParams
extends Resource
## Tunable knobs for MapGenerator. Edit these on the VoxelWorld node in the
## Inspector — the world regenerates on the next run whenever they change.

@export_group("World")
@export var world_seed: int = 1337
@export_range(64, 512, 2) var world_size: int = 160

@export_group("Terrain")
## Vertical scale of the large rolling hills, in blocks.
@export_range(0.0, 12.0, 0.1) var hill_amplitude: float = 4.0
## Lower = wider, gentler hills.
@export_range(0.001, 0.1, 0.001) var hill_frequency: float = 0.013
## Vertical scale of the small bumpy detail, in blocks.
@export_range(0.0, 4.0, 0.1) var detail_amplitude: float = 1.5
@export_range(0.001, 0.2, 0.001) var detail_frequency: float = 0.05
@export_range(0, 12) var max_height: int = 6
## How deep water basins can go (negative = below ground level).
@export_range(-8, 0) var min_height: int = -3

@export_group("Water")
@export var lake_enabled: bool = true
@export var lake_center: Vector2i = Vector2i(-52, 44)
@export var lake_radius: Vector2 = Vector2(16, 12)
@export var river_enabled: bool = true
## Center x of the river's winding path.
@export var river_x: float = 50.0
## How far the river meanders side to side, in blocks.
@export_range(0.0, 24.0, 0.5) var river_wander: float = 8.0
@export_range(1, 4) var river_half_width: int = 1

@export_group("Town")
@export var town_enabled: bool = true
## Half-extent of the flattened town area, in blocks.
@export_range(10, 80) var town_half_extent: int = 34
## Blocks over which the terrain blends from flat town back to hills.
@export_range(0, 30) var town_blend: int = 10
@export_range(10, 60) var road_spacing: int = 24
## Chance that each plot between roads gets a building.
@export_range(0.0, 1.0, 0.05) var building_density: float = 0.75
@export_range(1, 4) var min_floors: int = 1
@export_range(1, 4) var max_floors: int = 3
@export var plaza_enabled: bool = true
@export var lamps_enabled: bool = true

@export_group("Vegetation")
## Fraction of open grass columns that seed a full oak tree.
@export_range(0.0, 0.1, 0.001) var tree_density: float = 0.007
## Birches only appear inside noise-defined groves.
@export_range(0.0, 0.1, 0.001) var birch_density: float = 0.012
@export_range(0.0, 0.05, 0.001) var town_tree_density: float = 0.004

## Stable hash of every exported value — stored in the save file so a
## params change triggers regeneration.
func hash_value() -> int:
	var acc := []
	for prop in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (prop.usage & PROPERTY_USAGE_STORAGE):
			acc.append([prop.name, get(prop.name)])
	return str(acc).hash()
