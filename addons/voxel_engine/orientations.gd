class_name Orientations
## The 24 orientations of a cube-grid block: 6 choices of which world
## direction the block's top faces, times 4 spins about that axis.
## Index = up_index * 4 + spin. Indices 0..3 are the plain yaw rotations
## (up = +Y), matching the legacy 2-bit rotation values in old saves.

const COUNT := 24

## Order matters: index 0 must be +Y so legacy rots 0..3 keep their meaning.
const UPS: Array[Vector3] = [
	Vector3.UP, Vector3.DOWN,
	Vector3.RIGHT, Vector3.LEFT,
	Vector3.BACK, Vector3.FORWARD,
]

const UP_NAMES: Array[String] = [
	"Up", "Down (flipped)", "East", "West", "South", "North",
]

static var _bases: Array[Basis] = []

static func basis_of(rot: int) -> Basis:
	_ensure()
	return _bases[clampi(rot, 0, COUNT - 1)]

static func up_index(rot: int) -> int:
	return clampi(rot, 0, COUNT - 1) / 4

static func spin(rot: int) -> int:
	return clampi(rot, 0, COUNT - 1) % 4

static func make(up_idx: int, spin_idx: int) -> int:
	return posmod(up_idx, UPS.size()) * 4 + posmod(spin_idx, 4)

## Transform that places a block mesh (origin at its bottom-center) into a
## cell at `pos`, rotated about the CELL CENTER so every orientation stays
## inside the cell.
static func block_transform(rot: int, pos: Vector3) -> Transform3D:
	var b := basis_of(rot)
	var center := Vector3(0.0, 0.5, 0.0)
	return Transform3D(b, pos + center - b * center)

static func _ensure() -> void:
	if not _bases.is_empty():
		return
	for u: Vector3 in UPS:
		var align := Basis()
		if u == Vector3.DOWN:
			align = Basis(Vector3.RIGHT, PI)
		elif u != Vector3.UP:
			align = Basis(Vector3.UP.cross(u).normalized(), PI * 0.5)
		for k in 4:
			_bases.append(Basis(u, float(k) * PI * 0.5) * align)
