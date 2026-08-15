extends Node3D

const TRACER_SCRIPT := preload("res://scripts/tracer.gd")
const FLASH_SCRIPT := preload("res://scripts/muzzle_flash.gd")

@export var damage := 25.0
@export var fire_rate := 8.0
@export var shoot_range := 100.0
@export var recoil_amount := 0.05
@export var spread_degrees := 0.8
@export var first_shot_reset_time := 0.25
@export var is_auto := false

# --- НАСТРОЙКИ МАЗЛА ---
@export var muzzle_offset := Vector3(0.40, -0.55, -2.3)
@export var flash_scale := 0.45
@export var flash_start_size := 0.15
@export var flash_end_size := 0.02

# --- НАСТРОЙКА ТРЕЙСЕРА ---
@export var tracer_offset := Vector3(0.40, -0.55, -2.3)

# --- ИНТЕНСИВНОСТЬ ОТДАЧИ И FOV-ШЕЙКА (настраивай под пистолет) ---
@export var camera_shake_intensity := 0.1

var can_fire := true
var _muzzle: Node3D
var _model: Node3D

var _bob_x := 0.0
var _bob_y := 0.0
var _bob_moving := false
var _yaw_input := 0.0
var _lean_cur := 0.0
var _recoil_back := 0.0
var _recoil_pitch := 0.0
var _time_since_shot := 999.0


func _ready() -> void:
	_model = get_node_or_null("glock17")
	if _model == null:
		for child in get_children():
			if child is Node3D:
				_model = child
				break

	_muzzle = find_muzzle()
	if _muzzle == null:
		print("⚠️ Muzzle не найден — создаю на (0,0,-0.5)")
		_muzzle = Node3D.new()
		_muzzle.name = "Muzzle"
		_muzzle.position = Vector3(0, 0, -0.5)
		add_child(_muzzle)


func find_muzzle() -> Node3D:
	for node in find_children("*uzzle*", "", true, false):
		if node is Node3D:
			return node
	return null


func set_bob(bob_x: float, bob_y: float, moving: bool) -> void:
	_bob_x = bob_x
	_bob_y = bob_y
	_bob_moving = moving


func set_yaw_input(yaw: float) -> void:
	_yaw_input = yaw


func _process(delta: float) -> void:
	_time_since_shot += delta

	var damp := 1.0 - exp(-9.0 * delta)
	_recoil_back = lerpf(_recoil_back, 0.0, damp)
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, damp)

	if _model == null:
		return

	if not has_meta("_bob_origin"):
		set_meta("_bob_origin", _model.position)
		set_meta("_bob_rot", _model.rotation)
	var origin: Vector3 = get_meta("_bob_origin")
	var base_rot: Vector3 = get_meta("_bob_rot")

	if not _bob_moving:
		_bob_x = lerpf(_bob_x, 0.0, 1.0 - exp(-12.0 * delta))
		_bob_y = lerpf(_bob_y, 0.0, 1.0 - exp(-12.0 * delta))

	_model.position = origin + Vector3(_bob_x * 0.1, _bob_y * 0.06, _recoil_back)

	_lean_cur = lerpf(_lean_cur, clampf(-_yaw_input * 0.15, -0.25, 0.25), 1.0 - exp(-8.0 * delta))
	_model.rotation = base_rot + Vector3(_recoil_pitch, _lean_cur, _bob_x * 0.05)
	_yaw_input = 0.0


func try_fire() -> bool:
	if not can_fire or _muzzle == null:
		return false

	can_fire = false
	get_tree().create_timer(1.0 / fire_rate).timeout.connect(func():
		can_fire = true)

	var cam := get_parent() as Camera3D
	var space := cam.get_world_3d().direct_space_state

	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z

	var is_first_shot := _time_since_shot >= first_shot_reset_time
	if not is_first_shot:
		var spread := deg_to_rad(spread_degrees)
		dir = dir.rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
		dir = dir.rotated(cam.global_transform.basis.x, randf_range(-spread, spread))
	_time_since_shot = 0.0

	var to := origin + dir * shoot_range

	var hit_pos: Vector3 = SwarmManager.get_hit_position(origin, dir, shoot_range)
	var target := to
	if hit_pos != Vector3.ZERO:
		target = hit_pos
		SwarmManager.damage_ray(origin, dir, shoot_range, int(damage))
	else:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, to))
		if hit:
			target = hit.position
			var c: Object = hit.collider
			if c != null and c.has_method("take_damage"):
				c.take_damage(damage)

	var muzzle_pos := cam.global_position + cam.global_transform.basis * muzzle_offset
	spawn_flash(muzzle_pos)

	var tracer_pos := cam.global_position + cam.global_transform.basis * tracer_offset
	spawn_tracer(tracer_pos, target)

	# --- ОТДАЧА И FOV-ШЕЙК ---
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_camera_shake"):
		player.add_camera_shake(camera_shake_intensity)

	var speed_factor := 0.0
	if player is CharacterBody3D:
		var horiz := Vector2(player.velocity.x, player.velocity.z)
		speed_factor = clampf(horiz.length() / 20.0, 0.0, 1.0)

	_recoil_back = recoil_amount * 3.0 * (1.0 + speed_factor * 0.8)
	_recoil_pitch = recoil_amount * 1.2 * (1.0 + speed_factor * 0.5)

	if speed_factor > 0.3:
		spread_degrees = 0.8 + speed_factor * 1.2
	else:
		spread_degrees = 0.8

	AudioManager.play_shot()
	return true


func spawn_flash(pos: Vector3) -> void:
	var flash: Node3D = FLASH_SCRIPT.new()
	flash.start_size = flash_start_size * flash_scale
	flash.end_size = flash_end_size * flash_scale
	var world := get_tree().current_scene
	if world == null:
		world = get_parent().get_parent().get_parent()
	world.add_child(flash)
	flash.global_position = pos


func spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer: Node3D = TRACER_SCRIPT.new()
	tracer.set("from", from)
	tracer.set("to", to)
	var world := get_tree().current_scene
	if world == null:
		world = get_parent().get_parent().get_parent()
	world.add_child(tracer)
