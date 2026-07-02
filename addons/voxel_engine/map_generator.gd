class_name MapGenerator
## Procedurally builds the default world: rolling terrain, a lake, a river,
## a small town with roads and multi-story buildings, and scattered trees.
## Bump GEN_VERSION to regenerate everyone's world on next launch.

const GEN_VERSION := 1

const HALF := 80            # world spans [-HALF, HALF-1] on x and z
const TOWN := 34            # town half-extent — terrain is flattened inside
const TOWN_BLEND := 10      # blocks over which terrain blends back to hills
const ROAD_LINES := [-24, 0, 24]

const BUILDINGS := [
	# x0, z0, width, depth, floors, gabled roof
	{"x0": -20, "z0": -20, "w": 10, "d": 8, "floors": 2, "gable": true},
	{"x0": -9, "z0": -19, "w": 5, "d": 6, "floors": 3, "gable": false},
	{"x0": 5, "z0": -20, "w": 8, "d": 7, "floors": 2, "gable": true},
	{"x0": 15, "z0": -10, "w": 5, "d": 5, "floors": 1, "gable": true},
	{"x0": -20, "z0": 5, "w": 7, "d": 9, "floors": 2, "gable": true},
	{"x0": -11, "z0": 13, "w": 6, "d": 6, "floors": 3, "gable": false},
	{"x0": 13, "z0": 14, "w": 7, "d": 6, "floors": 2, "gable": true},
]

const PLAZA := {"x0": 4, "z0": 4, "w": 9, "d": 9}

static var _heights: PackedInt32Array
static var _tops: PackedInt32Array       # block id of each column's surface
static var _occupied: Dictionary = {}    # Vector2i -> true, no trees here

static func generate(world: Node) -> void:
	_build_height_map()
	_carve_river()
	_mark_surfaces()
	_emit_terrain(world)
	_emit_buildings(world)
	_emit_plaza(world)
	_emit_lamps(world)
	_emit_trees(world)
	world.rebuild_all()
	_heights = PackedInt32Array()
	_tops = PackedInt32Array()
	_occupied.clear()

static func _idx(x: int, z: int) -> int:
	return (z + HALF) * (HALF * 2) + (x + HALF)

static func _in_bounds(x: int, z: int) -> bool:
	return x >= -HALF and x < HALF and z >= -HALF and z < HALF

static func _get_h(x: int, z: int) -> int:
	if not _in_bounds(x, z):
		return 0
	return _heights[_idx(x, z)]

static func _build_height_map() -> void:
	var big := FastNoiseLite.new()
	big.seed = 1337
	big.frequency = 0.013
	big.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = 9021
	detail.frequency = 0.05

	var size := HALF * 2
	_heights = PackedInt32Array()
	_heights.resize(size * size)
	_tops = PackedInt32Array()
	_tops.resize(size * size)

	for z in range(-HALF, HALF):
		for x in range(-HALF, HALF):
			var h := big.get_noise_2d(x, z) * 4.0 + detail.get_noise_2d(x, z) * 1.5
			var town_d := maxf(absf(float(x)), absf(float(z)))
			if town_d < TOWN:
				h = 0.0
			elif town_d < TOWN + TOWN_BLEND:
				h = lerpf(0.0, h, (town_d - TOWN) / float(TOWN_BLEND))
			# carve a lake in the north-west hills
			var lake := 1.0 - sqrt(pow((x + 52) / 16.0, 2.0) + pow((z - 44) / 12.0, 2.0))
			if lake > 0.0:
				h = minf(h, -1.0 - 2.0 * lake)
			_heights[_idx(x, z)] = clampi(roundi(h), -3, 6)

static func _carve_river() -> void:
	var wobble := FastNoiseLite.new()
	wobble.seed = 4242
	wobble.frequency = 0.03
	for z in range(-HALF, HALF):
		var xc := roundi(50.0 + 8.0 * sin(float(z) * 0.06) + 4.0 * wobble.get_noise_2d(0.0, float(z)))
		for dx in range(-1, 2):
			var x := xc + dx
			if _in_bounds(x, z):
				_heights[_idx(x, z)] = mini(_get_h(x, z), -1)

static func _mark_surfaces() -> void:
	var grass := BlockRegistry.get_id("grass")
	var sand := BlockRegistry.get_id("sand")
	var asphalt := BlockRegistry.get_id("asphalt")
	var walkway := BlockRegistry.get_id("concrete_walkway")
	var gravel := BlockRegistry.get_id("gravel")

	for z in range(-HALF, HALF):
		for x in range(-HALF, HALF):
			var i := _idx(x, z)
			var town_d := maxi(absi(x), absi(z))
			var country_road := town_d > TOWN and (absi(x) <= 1 or absi(z) <= 1)
			if country_road and _heights[i] < 0:
				_heights[i] = 0  # causeway where a road crosses water
			var h := _heights[i]
			if h < 0:
				_tops[i] = BlockRegistry.get_id("water")
				continue
			var top := grass
			# sandy banks near water
			if h <= 1 and _near_water(x, z, 2):
				top = sand
			if country_road:
				top = gravel
			elif town_d <= TOWN:
				var on_road := false
				var on_walk := false
				for line: int in ROAD_LINES:
					if absi(x - line) <= 1 or absi(z - line) <= 1:
						on_road = true
					elif absi(x - line) == 2 or absi(z - line) == 2:
						on_walk = true
				if on_road:
					top = asphalt
				elif on_walk:
					top = walkway
			_tops[i] = top

static func _near_water(x: int, z: int, dist: int) -> bool:
	for dz in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			if _get_h(x + dx, z + dz) < 0:
				return true
	return false

static func _emit_terrain(world: Node) -> void:
	var dirt := BlockRegistry.get_id("dirt")
	var water := BlockRegistry.get_id("water")
	for z in range(-HALF, HALF):
		for x in range(-HALF, HALF):
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

static func _emit_buildings(world: Node) -> void:
	var bricks := BlockRegistry.get_id("bricks")
	var cement := BlockRegistry.get_id("cement_blocks")
	var shingles := BlockRegistry.get_id("shingles_slate")
	var walkway := BlockRegistry.get_id("concrete_walkway")

	for b: Dictionary in BUILDINGS:
		var x0: int = b["x0"]
		var z0: int = b["z0"]
		var w: int = b["w"]
		var d: int = b["d"]
		var floors: int = b["floors"]
		var wall_top: int = floors * 3
		var door_x := x0 + w / 2

		for gz in range(z0 - 1, z0 + d + 1):
			for gx in range(x0 - 1, x0 + w + 1):
				_occupied[Vector2i(gx, gz)] = true

		for gz in range(z0, z0 + d):
			for gx in range(x0, x0 + w):
				var on_perim := gx == x0 or gx == x0 + w - 1 or gz == z0 or gz == z0 + d - 1
				if not on_perim:
					# interior floor
					world.set_block_no_rebuild(gx, -1, gz, walkway)
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

		if b["gable"]:
			# stepped gable roof, ridge along the longer axis
			var along_x: bool = w >= d
			var short_len: int = d if along_x else w
			var steps: int = (short_len + 1) / 2
			for s in steps:
				for gz in range(z0, z0 + d):
					for gx in range(x0, x0 + w):
						var j: int = (gz - z0) if along_x else (gx - x0)
						if j >= s and j <= short_len - 1 - s:
							world.set_block_no_rebuild(gx, wall_top + s, gz, shingles)
		else:
			for gz in range(z0, z0 + d):
				for gx in range(x0, x0 + w):
					world.set_block_no_rebuild(gx, wall_top, gz, shingles)

static func _emit_plaza(world: Node) -> void:
	var walkway := BlockRegistry.get_id("concrete_walkway")
	var grass := BlockRegistry.get_id("grass")
	var pole := BlockRegistry.get_id("metal_pole_small")
	var birch := BlockRegistry.get_id("tree_birch_small")

	var x0: int = PLAZA["x0"]
	var z0: int = PLAZA["z0"]
	var w: int = PLAZA["w"]
	var d: int = PLAZA["d"]
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

static func _emit_lamps(world: Node) -> void:
	var pole := BlockRegistry.get_id("metal_pole_large")
	for lx: int in ROAD_LINES:
		for lz: int in ROAD_LINES:
			for corner: Vector2i in [
				Vector2i(lx + 2, lz + 2), Vector2i(lx - 2, lz + 2),
				Vector2i(lx + 2, lz - 2), Vector2i(lx - 2, lz - 2),
			]:
				if _occupied.has(corner):
					continue
				_occupied[corner] = true
				for y in 3:
					world.set_block_no_rebuild(corner.x, y, corner.y, pole)

static func _emit_trees(world: Node) -> void:
	var grass := BlockRegistry.get_id("grass")
	var big_tree := BlockRegistry.get_id("tree_generic_large")
	var birch := BlockRegistry.get_id("tree_birch_small")
	var cluster := FastNoiseLite.new()
	cluster.seed = 777
	cluster.frequency = 0.04

	for z in range(-HALF, HALF):
		for x in range(-HALF, HALF):
			var h := _get_h(x, z)
			if h < 0 or _tops[_idx(x, z)] != grass:
				continue
			if _occupied.has(Vector2i(x, z)):
				continue
			var r := absi((x * 92837111) ^ (z * 689287499)) % 1000
			var in_town := maxi(absi(x), absi(z)) <= TOWN
			if in_town:
				if r < 5:
					world.set_block_no_rebuild(x, h, z, big_tree)
			elif r < 12:
				world.set_block_no_rebuild(x, h, z, big_tree)
			elif r < 26 and cluster.get_noise_2d(x, z) > 0.3:
				world.set_block_no_rebuild(x, h, z, birch)
