class_name Floors
## Canonical floor banding for the pseudo-3D map structure. A floor is a
## fixed 4-block vertical band: 1 slab/surface layer + 3 blocks of headroom
## (Minecraft-standard room height for a ~1.7-block character). Floor 0
## starts at the ground surface block (y = -1), so its band is y in [-1, 3);
## floor 1 is [3, 7); floor -1 is [-5, -1). Building storeys, the God-mode
## floor slider, and the render slice plane all share this definition.

const HEIGHT := 4
const BASE_Y := -1

## Range the editor exposes (covers y = -5 up to y = 31).
const MIN_FLOOR := -1
const MAX_FLOOR := 7

static func floor_of(y: float) -> int:
	return floori((y - BASE_Y) / float(HEIGHT))

static func bottom_of(f: int) -> int:
	return BASE_Y + f * HEIGHT

## Top boundary plane of floor f's band. The top faces of the floor's highest
## block row land exactly on this plane, so slicing here shows clean tops.
static func top_of(f: int) -> int:
	return BASE_Y + (f + 1) * HEIGHT
