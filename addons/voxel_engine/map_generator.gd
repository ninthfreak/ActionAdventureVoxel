class_name MapGenerator
extends RefCounted
## Procedurally builds a world from a MapGenParams: rolling terrain, water
## features, a road-grid town with seeded random buildings, and trees.
## Bump GEN_VERSION to force regeneration after generator code changes;
## param changes are picked up automatically via MapGenParams.hash_value().

const GEN_VERSION := 2

var p: MapGenParams
var half: int
var road_lines: Array[int] = []

var _heights: PackedInt32Array
var _tops: PackedInt32Array
var _occupied: Dictionary = {}
var _rng := RandomNumberGenerator.new()

static func generate(world: Node, params: MapGenParams = null) -> void:
	var g := MapGenerator.new()
	g.p = params if params else MapGenParams.new()
	g._run(world)

func _run(world: Node) -> void:
	half = p.world_size / 2
	_rng.seed = p.world_seed
	_compute_road_lines()
	_build_height_map()
	_carve_river()
	_mark_surfaces()
	_emit_terrain(world)
	_emit_town(world)
	_emit_trees(world)
	world.rebuild_all()

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
	var detail := FastNoiseLite.new()
	detail.seed = p.world_seed + 1
	detail.frequency = p.detail_frequency

	var size := half * 2
	_heights = PackedInt32Array()
	_heights.resize(size * size)
	_tops = PackedInt32Array()
	_tops.resize(size * size)

	for z in range(-half, half):
		for x in range(-half, half):
			var h := big.get_noise_2d(x, z) * p.hill_amplitude \
				+ detail.get_noise_2d(x, z) * p.detail_amplitude
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
	var grass := BlockRegistry.get_id("grass")
	var sand := BlockRegistry.get_id("sand")
	var asphalt := BlockRegistry.get_id("asphalt")
	var walkway := BlockRegistry.get_id("concrete_walkway")
	var gravel := BlockRegistry.get_id("gravel")
	var water := BlockRegistry.get_id("water")

	for z in range(-half, half):
		for x in range(-half, half):
			var i := _idx(x, z)
			var town_d := maxi(absi(x), absi(z))
			var country_road := p.town_enabled and town_d > p.town_half_extent \
				and (absi(x) <= 1 or absi(z) <= 1)
			if country_road and _heights[i] < 0:
				_heights[i] = 0  # causeway where a road crosses water
			var h := _heights[i]
			if h < 0:
				_tops[i] = water
				continue
			var top := grass
			if h <= 1 and _near_water(x, z, 2):
				top = sand
			if country_road:
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
	var dirt := BlockRegistry.get_id("dirt")
	var water := BlockRegistry.get_id("water")
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
				_emit_plaza(world, px0, pz0, mini(pw, 9), mini(pd, 9))
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
			var gable := _rng.randf() < 0.7
			_place_building(world, bx, bz, w, d, floors, gable)
	if p.lamps_enabled:
		_emit_lamps(world)

func _place_building(world: Node, x0: int, z0: int, w: int, d: int, floors: int, gable: bool) -> void:
	var bricks := BlockRegistry.get_id("bricks")
	var cement := BlockRegistry.get_id("cement_blocks")
	var shingles := BlockRegistry.get_id("shingles_slate")
	var walkway := BlockRegistry.get_id("concrete_walkway")
	var wall_top := floors * 3
	var door_x := x0 + w / 2

	for gz in range(z0 - 1, z0 + d + 1):
		for gx in range(x0 - 1, x0 + w + 1):
			_occupied[Vector2i(gx, gz)] = true

	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			var on_perim := gx == x0 or gx == x0 + w - 1 or gz == z0 or gz == z0 + d - 1
			if not on_perim:
				world.set_block_no_rebuild(gx, -1, gz, walkway)  # interior floor
				continue
			var corner := (gx == x0 or gx == x0 + w - 1) and (gz == z0 or gz == z0 + d - 1)
			for y in range(0, wall_top):
				# door: 1 wide, 2 tall, centered on the south wall
				if gz == z0 and gx == door_x and y <= 1:
					continue
				var block := bricks
				if corner:
					block = cement
				elif y % 3 == 1 and (gx + gz) % 2 == 0:
					block = cement  # window band
				world.set_block_no_rebuild(gx, y, gz, block)

	if gable:
		# stepped gable roof, ridge along the longer axis
		var along_x := w >= d
		var short_len := d if along_x else w
		var steps := (short_len + 1) / 2
		for s in steps:
			for gz in range(z0, z0 + d):
				for gx in range(x0, x0 + w):
					var j := (gz - z0) if along_x else (gx - x0)
					if j >= s and j <= short_len - 1 - s:
						world.set_block_no_rebuild(gx, wall_top + s, gz, shingles)
	else:
		for gz in range(z0, z0 + d):
			for gx in range(x0, x0 + w):
				world.set_block_no_rebuild(gx, wall_top, gz, shingles)

func _emit_plaza(world: Node, x0: int, z0: int, w: int, d: int) -> void:
	var walkway := BlockRegistry.get_id("concrete_walkway")
	var grass := BlockRegistry.get_id("grass")
	var pole := BlockRegistry.get_id("metal_pole_small")
	var birch := BlockRegistry.get_id("tree_birch_small")

	for gz in range(z0, z0 + d):
		for gx in range(x0, x0 + w):
			world.set_block_no_rebuild(gx, -1, gz, walkway)
			_occupied[Vector2i(gx, gz)] = true
	for corner: Vector2i in [
		Vector2i(x0, z0), Vector2i(x0 + w - 1, z0),
		Vector2i(x0, z0 + d - 1), Vector2i(x0 + w - 1, z0 + d - 1),
	]:
		for y in 2:
			world.set_block_no_rebuild(corner.x, y, corner.y, pole)
	# one birch on a grass patch in the middle
	var cx := x0 + w / 2
	var cz := z0 + d / 2
	world.set_block_no_rebuild(cx, -1, cz, grass)
	world.set_block_no_rebuild(cx, 0, cz, birch)

func _emit_lamps(world: Node) -> void:
	var pole := BlockRegistry.get_id("metal_pole_large")
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

func _emit_trees(world: Node) -> void:
	var grass := BlockRegistry.get_id("grass")
	var big_tree := BlockRegistry.get_id("tree_generic_large")
	var birch := BlockRegistry.get_id("tree_birch_small")
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
					world.set_block_no_rebuild(x, h, z, big_tree)
			elif r < tree_r:
				world.set_block_no_rebuild(x, h, z, big_tree)
			elif r < birch_r and cluster.get_noise_2d(x, z) > 0.3:
				world.set_block_no_rebuild(x, h, z, birch)
