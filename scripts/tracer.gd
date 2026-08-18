class_name Tracer
extends Node3D
## Летящий трейсер-штрих.

var from := Vector3.ZERO
var to := Vector3.ZERO
var speed := 150.0
var _progress := 0.0
var _total := 1.0

func _ready() -> void:
	_total = maxf(from.distance_to(to), 0.1)
	global_position = from
	build()

func build() -> void:
	# Яркий штрих
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.8)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	mat.emission_energy_multiplier = 3.0
	box.material_override = mat
	box.mesh = bm
	add_child(box)

	# Хвост
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.04, 0.04, 0.6)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_color = Color(1.0, 0.6, 0.2, 0.3)
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.5, 0.15, 0.4)
	tail.material_override = tmat
	tail.mesh = tm
	add_child(tail)
	tail.position = Vector3(0, 0, 0.7)

	# Ориентация
	var dir := (to - from).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	if absf(dir.dot(Vector3.UP)) > 0.999:
		look_at(global_position + dir, Vector3.RIGHT)
	else:
		look_at(global_position + dir, Vector3.UP)

func _process(delta: float) -> void:
	_progress += speed * delta / _total
	var t := clampf(_progress, 0.0, 1.0)
	global_position = from.lerp(to, t)

	if _progress >= 1.0:
		global_position = to
		queue_free()
