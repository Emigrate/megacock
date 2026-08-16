extends Node3D

const TRACER_SCRIPT := preload("res://scripts/tracer.gd")
const FLASH_SCRIPT := preload("res://scripts/muzzle_flash.gd")

@export var pellet_count := 20
@export var pellet_damage := 25.0
@export var fire_rate := 1
@export var shoot_range := 100.0
@export var spread_degrees := 12.0
@export var spread_falloff := 1.0
@export var recoil_amount := 0.3
@export var first_shot_reset_time := 0.3

# --- ПЕРЕЗАРЯДКА (ПОМПОВОЕ ДЕЙСТВИЕ) ---
@export var magazine_size := 1
@export var reload_time := 0.25

# --- НАСТРОЙКИ МАЗЛА ---
@export var muzzle_offset := Vector3(0.3, -0.30, -6.3)
@export var flash_scale := 0.6
@export var flash_start_size := 0.35
@export var flash_end_size := 0.03

# --- НАСТРОЙКА ТРЕЙСЕРА (подбери под дуло) ---
@export var tracer_offset := Vector3(0.3, -0.30, -4)   # изменено с -5.7 на -1.8

# --- НАСТРОЙКИ БОБА ---
@export var bob_position_scale := 0.6
@export var bob_rotation_scale := 0.6

# --- ИНТЕНСИВНОСТЬ ОТДАЧИ И FOV-ШЕЙКА ---
@export var camera_shake_intensity := 1

var can_fire := true
var _model: Node3D
var ammo := 6
var is_reloading := false

# --- ОТДАЧА И БОБ ---
var _bob_x := 0.0
var _bob_y := 0.0
var _bob_moving := false
var _yaw_input := 0.0
var _lean_cur := 0.0
var _recoil_back := 0.0
var _recoil_pitch := 0.0
var _time_since_shot := 999.0


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_model = child
			break
	if _model == null:
		_model = Node3D.new()
		_model.name = "Shotgun_Model"
		add_child(_model)
	ammo = magazine_size


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

	var bob_offset := Vector3(_bob_x * 0.1 * bob_position_scale,
							  _bob_y * 0.06 * bob_position_scale,
							  _recoil_back)
	_model.position = origin + bob_offset

	_lean_cur = lerpf(_lean_cur, clampf(-_yaw_input * 0.15, -0.25, 0.25), 1.0 - exp(-8.0 * delta))
	var rot_offset := Vector3(_recoil_pitch, _lean_cur, _bob_x * 0.05 * bob_rotation_scale)
	_model.rotation = base_rot + rot_offset
	_yaw_input = 0.0


func _generate_normal_angle(max_angle: float, falloff: float = 1.0) -> float:
	var r1 = randf_range(-1.0, 1.0)
	var r2 = randf_range(-1.0, 1.0)
	var r3 = randf_range(-1.0, 1.0)
	var normal = (r1 + r2 + r3) / 3.0
	var sigma = max_angle / 2.0
	var _scale = sigma / 0.577 / falloff   # переименовано
	return normal * _scale


func try_fire() -> bool:
	if not can_fire or is_reloading or ammo <= 0:
		if ammo <= 0 and not is_reloading:
			_reload()
		return false

	can_fire = false
	ammo -= 1
	if ammo <= 0:
		_reload()

	var timer = get_tree().create_timer(1.0 / fire_rate)
	timer.timeout.connect(_on_fire_cooldown)

	var cam := get_parent() as Camera3D
	var space := cam.get_world_3d().direct_space_state

	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z

	var spread_rad := deg_to_rad(spread_degrees)

	var tracer_start := cam.global_position + cam.global_transform.basis * tracer_offset

	for i in range(pellet_count):
		var angle_h = _generate_normal_angle(spread_rad, spread_falloff)
		var angle_v = _generate_normal_angle(spread_rad, spread_falloff)

		var spread_dir := dir
		spread_dir = spread_dir.rotated(cam.global_transform.basis.y, angle_h)
		spread_dir = spread_dir.rotated(cam.global_transform.basis.x, angle_v)

		var to := origin + spread_dir * shoot_range
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, to))
		if hit:
			var target: Vector3 = hit.position
			var c: Object = hit.collider
			if c != null and c.has_method("take_damage"):
				c.take_damage(pellet_damage)
			spawn_tracer(tracer_start, target)
		else:
			spawn_tracer(tracer_start, to)

	var muzzle_pos := cam.global_position + cam.global_transform.basis * muzzle_offset
	spawn_flash(muzzle_pos)

	_recoil_back = recoil_amount * 4.0
	_recoil_pitch = recoil_amount * 2.0

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_camera_shake"):
		player.add_camera_shake(camera_shake_intensity)

	AudioManager.play_shotgun_shot()
	return true


func _on_fire_cooldown() -> void:
	can_fire = true


func _reload() -> void:
	if is_reloading or ammo == magazine_size:
		return
	is_reloading = true
	var timer = get_tree().create_timer(reload_time)
	timer.timeout.connect(_on_reload_finished)


func _on_reload_finished() -> void:
	ammo = magazine_size
	is_reloading = false


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
