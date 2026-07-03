class_name MapGenerator
extends RefCounted
## Procedurally builds a world from a MapGenParams using the PrismCraft
## block library ("material.shape" GLBs): rolling terrain with snow caps and
## muddy banks, a lake and river, a road-grid town with varied masonry
## buildings (real gable roofs, south-facing doors), a plaza with a fountain,
## proper multi-block trees, and scattered ore boulders.
##
## Rotation semantics (Basis(UP, rot * PI/2) applied to the mesh):
##   ramps/stairs rise toward: rot 0 = +X (east), 1 = -Z (north),
##                             2 = -X (west),     3 = +Z (south)
##   gable ridge runs:         rot 0 = along Z,   1 = along X
##   opening pierces through:  rot 0 = along Z,   1 = along X
## South is +Z (screen-down at the default camera).

const GEN_VERSION := 3

const RISE_E := 0
const RISE_N := 1
const RISE_W := 2
const RISE_S := 3

## Building material families. Roofs: "gable"/"ramp" build pitched roofs,
## a null ramp forces a flat roof.
const WALL_SETS := [
	{"wall": "brick.cube", "corner": "brick.cross", "window": "brick.opening",
	 "ramp": "slate.ramp", "gable": "slate.gable", "flat_chance": 0.2},
	{"wall": "brick-yellow.cube", "corner": "brick-yellow.cross", "window": "brick-yellow.opening",
	 "ramp": "slate.ramp", "gable": "slate.gable", "flat_chance": 0.2},
	{"wall": "brick-grey.cube", "corner": "brick-grey.chamfered", "window": "brick-grey.opening",
	 "ramp": "slate.ramp", "gable": "slate.gable", "flat_chance": 0.3},
	{"wall": "stone-block.cube", "corner": "stone-block.cross", "window": "stone-block.opening",
	 "ramp": "wood.ramp", "gable": "wood.gable", "flat_chance": 0.15},
	{"wall": "concrete-block.cube", "corner": "concrete-block.chamfered", "window": "concrete-block.opening",
	 "ramp": "concrete.ramp", "gable": "wood.gable", "flat_chance": 0.7},
	{"wall": "steel-corrugated.cube", "corner": "steel.cross", "window": "steel.cube",
	 "ramp": "", "gable": "steel-corrugated.gable", "flat_chance": 1.0},
]

var p: MapGenParams
var half: int
var road_lines: Array[int] = []

var _heights: PackedInt32Array
var _tops: PackedInt32Array
var _occupied: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _detail := FastNoiseLite.new()

static func generate(world: Node, params: MapGenParams = null) -> void:
	var g := MapGenerator.new()
	g.p = params if params else MapGenParams.new()
	g._run(world)

func _run(world: Node) -> void:
	half = p.world_size / 2
	_rng.seed = p.world_seed
	_detail.seed = p.world_seed + 1
	_detail.frequency = p.detail_frequency
	_compute_road_lines()
	_build_height_map()
	_carve_river()
	_mark_surfaces()
	_emit_terrain(world)
	_emit_road_ramps(world)
	_emit_town(world)
	_emit_boulders(world)
	_emit_trees(world)
	world.rebuild_all()

func _id(block_name: String) -> int:
	return BlockRegistry.get_id(block_name)

func _compute_road_lines() -> void:
	road_lines.clear()
	if not p.town_enabled or p.road_spacing <= 0:
		return
	var n := (p.town_half_extent - 6) / p.road_spacing
	for i in range(-n, n + 1):
		road_lines.append(i * p.road_spacing)

func _idx(x: int, z: int) -> int:
	return (z + half) * (half * 2) + (x + half)

func _in_bounds(x: int, z: int) -> bool:
	return x >= -half and x < half and z >= -half and z < half

func _get_h(x: int, z: int) -> int:
	if not _in_bounds(x, z):
		return 0
	return _heights[_idx(x, z)]

func _build_height_map() -> void:
	var big := FastNoiseLite.new()
	big.seed = p.world_seed
	big.frequency = p.hill_frequency
	big.fractal_octaves = 3

	var size := half * 2
	_heights = PackedInt32Array()
	_heights.resize(size * size)
	_tops = PackedInt32Array()
	_tops.resize(size * size)

	for z in range(-half, half):
		for x in range(-half, half):
			var h := big.get_noise_2d(x, z) * p.hill_amplitude \
				+ _detail.get_noise_2d(x, z) * p.detail_amplitude
			if p.town_enabled:
				var town_d := maxf(absf(float(x)), absf(float(z)))
				if town_d < p.town_half_extent:
					h = 0.0
				elif town_d < p.town_half_extent + p.town_blend:
					h = lerpf(0.0, h, (town_d - p.town_half_extent) / float(p.town_blend))
			if p.lake_enabled:
				var lx := (x - p.lake_center.x) / p.lake_radius.x
				var lz := (z - p.lake_center.y) / p.lake_radius.y
				var lake := 1.0 - sqrt(lx * lx + lz * lz)
				if lake > 0.0:
					h = minf(h, -1.0 - 2.0 * lake)
			_heights[_idx(x, z)] = clampi(roundi(h), p.min_height, p.max_height)

func _carve_river() -> void:
	if not p.river_enabled:
		return
	var wobble := FastNoiseLite.new()
	wobble.seed = p.world_seed + 2
	wobble.frequency = 0.03
	for z in range(-half, half):
		var xc := roundi(p.river_x + p.river_wander * sin(float(z) * 0.06) \
			+ 4.0 * wobble.get_noise_2d(0.0, float(z)))
		for dx in range(-p.river_half_width, p.river_half_width + 1):
			var x := xc + dx
			if _in_bounds(x, z):
				_heights[_idx(x, z)] = mini(_get_h(x, z), -1)

func _mark_surfaces() -> void:
	var grass := _id("grass.cube")
	var sand := _id("sand.cube")
	var mud := _id("mud.cube")
	var snow := _id("snow.cube")
	var asphalt := _id("asphalt.cube")
	var walkway := _id("concrete.cube")
	var gravel := _id("gravel.cube")
	var stone_block := _id("stone-block.cube")
	var water := _id("water.cube")

	for z in range(-half, half):
		for x in range(-half, half):
			var i := _idx(x, z)
			var town_d := maxi(absi(x), absi(z))
			var country_road := p.town_enabled and town_d > p.town_half_extent \
				and (absi(x) <= 1 or absi(z) <= 1)
			var causeway := false
			if country_road and _heights[i] < 0:
				_heights[i] = 0  # causeway where a road crosses water
				causeway = true
			var h := _heights[i]
			if h < 0:
				_tops[i] = water
				continue
			var top := grass
			if h >= 5:
				top = snow
			elif h <= 1 and _near_water(x, z, 2):
				top = sand
				if _near_water(x, z, 1) and _detail.get_noise_2d(x * 2.0, z * 2.0) > 0.25:
					top = mud
			if causeway:
				top = stone_block  # reads as a stone bridge deck
			elif country_road:
				top = gravel
			elif p.town_enabled and town_d <= p.town_half_extent:
				var on_road := false
				var on_walk := false
				for line: int in road_lines:
					if absi(x - line) <= 1 or absi(z - line) <= 1:
						on_road = true
					elif absi(x - line) == 2 or absi(z - line) == 2:
						on_walk = true
				if on_road:
					top = asphalt
				elif on_walk:
					top = walkway
			_tops[i] = top

func _near_water(x: int, z: int, dist: int) -> bool:
	for dz in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			if _get_h(x + dx, z + dz) < 0:
				return true
	return false

func _emit_terrain(world: Node) -> void:
	var dirt := _id("dirt.cube")
	var water := _id("water.cube")
	for z in range(-half, half):
		for x in range(-half, half):
			var h := _get_h(x, z)
			if h < 0:
				# water column: dirt bed, water filled up to one below ground level
				world.set_block_no_rebuild(x, h - 2, z, dirt)
				for y in range(h - 1, -1):
					world.set_block_no_rebuild(x, y, z, water)
				continue
			# solid column: fill deep enough that hillsides show no holes
			var min_nb := h
			min_nb = mini(min_nb, _get_h(x - 1, z))
			min_nb = mini(min_nb, _get_h(x + 1, z))
			min_nb = mini(min_nb, _get_h(x, z - 1))
			min_nb = mini(min_nb, _get_h(x, z + 1))
			for y in range(min_nb - 2, h - 1):
				world.set_block_no_rebuild(x, y, z, dirt)
			world.set_block_no_rebuild(x, h - 1, z, _tops[_idx(x, z)])

## Where a country road steps up a hill, add a stone ramp so it stays walkable.
func _emit_road_ramps(world: Node) -> void:
	if not p.town_enabled:
		return
	var ramp := _id("stone.ramp")
	var gravel := _id("gravel.cube")
	for z in range(-half, half):
		for x in range(-half, half):
			if _tops[_idx(x, z)] != gravel:
				continue
			var h := _get_h(x, z)
			var on_x_road := absi(x) <= 1
			var rise := -1
			if on_x_road:
				if _get_h(x, z + 1) == h + 1:
					rise = RISE_S
				elif _get_h(x, z - 1) == h + 1:
					rise = RISE_N
			else:
				if _get_h(x + 1, z) == h + 1:
					rise = RISE_E
				elif _get_h(x - 1, z) == h + 1:
					rise = RISE_W
			if rise >= 0:
				world.set_block_no_rebuild(x, h, z, ramp, rise)
				_occupied[Vector2i(x, z)] = true

func _emit_town(world: Node) -> void:
	if not p.town_enabled or road_lines.size() < 2:
		return
	var plaza_done := not p.plaza_enabled
	for xi in road_lines.size() - 1:
		for zi in road_lines.size() - 1:
			# plot between two adjacent roads, inside the sidewalks
			var px0 := road_lines[xi] + 3
			var px1 := road_lines[xi + 1] - 3
			var pz0 := road_lines[zi] + 3
			var pz1 := road_lines[zi + 1] - 3
			var pw := px1 - px0 + 1
			var pd := pz1 - pz0 + 1
			if pw < 5 or pd < 5:
				continue
			if not plaza_done and px0 > 0 and pz0 > 0:
				_emit_plaza(world, px0, pz0, mini(pw, 11), mini(pd, 11))
				plaza_done = true
				continue
			if _rng.randf() > p.building_density:
				continue
			var w := _rng.randi_range(5, mini(pw, 12))
			var d := _rng.randi_range(5, mini(pd, 12))
			var bx := px0 + _rng.randi_range(0, pw - w)
			var bz := pz0 + _rng.randi_range(0, pd - d)
			var lo := mini(p.min_floors, p.max_floors)
			var hi := maxi(p.min_floors, p.max_floors)
			var floors := _rng.randi_range(lo, hi)
			var wall_set: Dictionary = WALL_SETS[_rng.randi_range(0, WALL_SETS.size() - 1)]
			_place_building(world, bx, bz, w, d, floors, wall_set)
	if p.lamps_enabled:
		_emit_lamps(world)

func _place_building(world: Node, x0: int, z0: int, w: int, d: int, floors: int, ws: Dictionary) -> void:
	var wall := _id(ws["wall"])
	var corner := _id(ws["corner"])
	var window := _id(ws["window"])
	var floor_block := _id("oak-plank.cube")
	var wall_top := floors * 3
	var door_x := x0 + w / 2
	var south_z := z0 + d - 1

	for gz in range(z0 - 1, z0 + d + 1):
		for gx in range(x0 - 1, x0 + w + 1):
			_occupied[Vector2i(gx, gz)] = true

	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			var on_perim := gx == x0 or gx == x0 + w - 1 or gz == z0 or gz == south_z
			if not on_perim:
				world.set_block_no_rebuild(gx, -1, gz, floor_block)  # wood interior floor
				continue
			var is_corner := (gx == x0 or gx == x0 + w - 1) and (gz == z0 or gz == south_z)
			# window openings pierce along the wall's thin axis
			var window_rot := 0 if (gz == z0 or gz == south_z) else 1
			for y in range(0, wall_top):
				# door: 1 wide, 2 tall, centered on the SOUTH wall
				if gz == south_z and gx == door_x and y <= 1:
					continue
				var block := wall
				var rot := 0
				if is_corner:
					block = corner
				elif y % 3 == 1 and (gx + gz) % 2 == 0:
					block = window
					rot = window_rot
				world.set_block_no_rebuild(gx, y, gz, block, rot)

	var ramp_name: String = ws["ramp"]
	var flat: bool = ramp_name.is_empty() or _rng.randf() < float(ws["flat_chance"])
	if flat:
		_flat_roof(world, x0, z0, w, d, wall_top, ws)
	else:
		_gable_roof(world, x0, z0, w, d, wall_top, ws)

func _flat_roof(world: Node, x0: int, z0: int, w: int, d: int, wall_top: int, ws: Dictionary) -> void:
	var deck := _id("concrete.slab-half")
	if ws["wall"] == "steel-corrugated.cube":
		deck = _id("steel-corrugated.panel")
	var parapet := _id(ws["wall"])
	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			var on_perim := gx == x0 or gx == x0 + w - 1 or gz == z0 or gz == z0 + d - 1
			world.set_block_no_rebuild(gx, wall_top, gz, parapet if on_perim else deck)

## Pitched roof from ramp pieces meeting at a gable ridge along the long axis.
func _gable_roof(world: Node, x0: int, z0: int, w: int, d: int, wall_top: int, ws: Dictionary) -> void:
	var ramp := _id(ws["ramp"])
	var gable := _id(ws["gable"])
	var fill := _id(ws["wall"])
	var ridge_along_x := w >= d
	var short_len := d if ridge_along_x else w

	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			var j := (gz - z0) if ridge_along_x else (gx - x0)
			var dist := mini(j, short_len - 1 - j)
			var is_ridge := (short_len % 2 == 1) and (j == short_len / 2)
			# gable-end walls fill the triangle under the slope
			for y in range(wall_top, wall_top + dist):
				world.set_block_no_rebuild(gx, y, gz, fill)
			if is_ridge:
				world.set_block_no_rebuild(gx, wall_top + dist, gz, gable, 1 if ridge_along_x else 0)
			else:
				var rise: int
				if ridge_along_x:
					rise = RISE_S if j < short_len / 2 else RISE_N
				else:
					rise = RISE_E if j < short_len / 2 else RISE_W
				world.set_block_no_rebuild(gx, wall_top + dist, gz, ramp, rise)

func _emit_plaza(world: Node, x0: int, z0: int, w: int, d: int) -> void:
	var paving := _id("stone-block.cube")
	var rim := _id("stone-block.cube")
	var water := _id("water.cube")
	var pole := _id("steel.octagon-half")
	var bench := _id("wood.slab-quarter")

	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			world.set_block_no_rebuild(gx, -1, gz, paving)
			_occupied[Vector2i(gx, gz)] = true

	# fountain: stone rim around a water basin
	var cx := x0 + w / 2
	var cz := z0 + d / 2
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				world.set_block_no_rebuild(cx, 0, cz, water)
			else:
				world.set_block_no_rebuild(cx + dx, 0, cz + dz, rim)

	# benches facing the fountain
	for offset: Vector2i in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3)]:
		world.set_block_no_rebuild(cx + offset.x, 0, cz + offset.y, bench)

	for pole_corner: Vector2i in [
		Vector2i(x0, z0), Vector2i(x0 + w - 1, z0),
		Vector2i(x0, z0 + d - 1), Vector2i(x0 + w - 1, z0 + d - 1),
	]:
		for y in 2:
			world.set_block_no_rebuild(pole_corner.x, y, pole_corner.y, pole)

func _emit_lamps(world: Node) -> void:
	var pole := _id("steel.octagon-half")
	for lx: int in road_lines:
		for lz: int in road_lines:
			for corner: Vector2i in [
				Vector2i(lx + 2, lz + 2), Vector2i(lx - 2, lz + 2),
				Vector2i(lx + 2, lz - 2), Vector2i(lx - 2, lz - 2),
			]:
				if _occupied.has(corner):
					continue
				_occupied[corner] = true
				for y in 3:
					world.set_block_no_rebuild(corner.x, y, corner.y, pole)

## Rare mineral-flecked boulders on the open hills.
func _emit_boulders(world: Node) -> void:
	var grass := _id("grass.cube")
	var ores: Array[int] = [
		_id("stone-flecked-coal.cube"), _id("stone-flecked-iron.cube"),
		_id("stone-flecked-copper.cube"), _id("stone-flecked-gold.cube"),
	]
	for z in range(-half, half):
		for x in range(-half, half):
			var h := _get_h(x, z)
			if h < 2 or _tops[_idx(x, z)] != grass:
				continue
			if _occupied.has(Vector2i(x, z)):
				continue
			var r := absi((x * 40503) ^ (z * 570925063) ^ p.world_seed) % 1000
			if r < 2:
				world.set_block_no_rebuild(x, h, z, ores[absi(x * 31 + z * 7) % ores.size()])
				_occupied[Vector2i(x, z)] = true

func _emit_trees(world: Node) -> void:
	var grass := _id("grass.cube")
	var cluster := FastNoiseLite.new()
	cluster.seed = p.world_seed + 3
	cluster.frequency = 0.04

	var tree_r := int(p.tree_density * 1000.0)
	var birch_r := tree_r + int(p.birch_density * 1000.0)
	var town_r := int(p.town_tree_density * 1000.0)

	for z in range(-half, half):
		for x in range(-half, half):
			var h := _get_h(x, z)
			if h < 0 or _tops[_idx(x, z)] != grass:
				continue
			if _occupied.has(Vector2i(x, z)):
				continue
			var r := absi((x * 92837111) ^ (z * 689287499) ^ (p.world_seed * 2654435761)) % 1000
			var in_town := p.town_enabled and maxi(absi(x), absi(z)) <= p.town_half_extent
			if in_town:
				if r < town_r:
					_place_oak(world, x, z, h)
			elif r < tree_r:
				_place_oak(world, x, z, h)
			elif r < birch_r and cluster.get_noise_2d(x, z) > 0.3:
				_place_birch(world, x, z, h)

## Oak: octagon trunk, 3x3x2 leaf crown plus a cross on top.
func _place_oak(world: Node, x: int, z: int, h: int) -> void:
	var trunk := _id("oak.octagon")
	var leaves := _id("leaves.cube")
	var trunk_h := 3 + absi(x * 13 + z * 29) % 2
	for y in range(h, h + trunk_h):
		world.set_block_no_rebuild(x, y, z, trunk)
	var top := h + trunk_h
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for y in [top - 1, top]:
				if dx == 0 and dz == 0 and y < top:
					continue  # trunk occupies this cell
				_leaf(world, x + dx, y, z + dz, leaves)
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_leaf(world, x + offset.x, top + 1, z + offset.y, leaves)
	_mark_area(x, z, 2)

## Birch: slim half-octagon trunk with a small crown.
func _place_birch(world: Node, x: int, z: int, h: int) -> void:
	var trunk := _id("birch.octagon-half")
	var leaves := _id("leaves.cube")
	var trunk_h := 3
	for y in range(h, h + trunk_h):
		world.set_block_no_rebuild(x, y, z, trunk)
	var top := h + trunk_h
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_leaf(world, x + offset.x, top, z + offset.y, leaves)
	_leaf(world, x, top + 1, z, leaves)
	_mark_area(x, z, 1)

func _leaf(world: Node, x: int, y: int, z: int, leaves: int) -> void:
	if world.get_block(x, y, z) == BlockRegistry.AIR:
		world.set_block_no_rebuild(x, y, z, leaves)

func _mark_area(x: int, z: int, radius: int) -> void:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			_occupied[Vector2i(x + dx, z + dz)] = true
