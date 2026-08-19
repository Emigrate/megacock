extends Node3D

const TRACER_SCRIPT := preload("res://scripts/tracer.gd")
const FLASH_SCRIPT := preload("res://scripts/muzzle_flash.gd")

@export var damage := 30.0
@export var fire_rate := 8.0
@export var shoot_range := 120.0
@export var recoil_amount := 0.10         # Увеличили отдачу
@export var spread_degrees := 1.8         # Чуть больше разброса
@export var first_shot_reset_time := 0.15
@export var is_auto := true

# --- НАСТРОЙКИ МАЗЛА (ВЕРНУЛИ БОЛЬШИЕ ЗНАЧЕНИЯ) ---
@export var muzzle_offset := Vector3(0.4, -0.5, -4.2)
@export var flash_scale := 1.2
@export var flash_start_size := 0.35
@export var flash_end_size := 0.05

# --- НАСТРОЙКА ТРЕЙСЕРА ---
@export var tracer_offset := Vector3(1.2, -1.3, -4.2)

# --- НАСТРОЙКИ БОБА ---
@export var bob_position_scale := 0.25
@export var bob_rotation_scale := 0.2

# --- ИНТЕНСИВНОСТЬ ОТДАЧИ И FOV-ШЕЙКА ---
@export var camera_shake_intensity := 0.5

var can_fire := true
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
	for child in get_children():
		if child is Node3D:
			_model = child
			break
	if _model == null:
		_model = Node3D.new()
		_model.name = "AK_Model"
		add_child(_model)


func set_bob(bob_x: float, bob_y: float, moving: bool) -> void:
	_bob_x = bob_x
	_bob_y = bob_y
	_bob_moving = moving


func set_yaw_input(yaw: float) -> void:
	_yaw_input = yaw


func _process(delta: float) -> void:
	_time_since_shot += delta

	var damp := 1.0 - exp(-10.0 * delta)
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


func try_fire() -> bool:
	if not can_fire:
		return false

	can_fire = false
	get_tree().create_timer(1.0 / fire_rate).timeout.connect(func():
		can_fire = true)

	var cam := get_parent() as Camera3D
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z

	var is_first_shot := _time_since_shot >= first_shot_reset_time
	if not is_first_shot:
		var spread := deg_to_rad(spread_degrees)
		dir = dir.rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
		dir = dir.rotated(cam.global_transform.basis.x, randf_range(-spread, spread))
	_time_since_shot = 0.0

	var player = get_tree().get_first_node_in_group("player")
	var chain_level = player.chain_count if player else 0

	_fire_chain(origin, dir, chain_level, player, cam)

	var muzzle_pos := cam.global_position + cam.global_transform.basis * muzzle_offset
	spawn_flash(muzzle_pos)

	# Отдача и шейк
	var speed_factor := 0.0
	if player is CharacterBody3D:
		var horiz := Vector2(player.velocity.x, player.velocity.z)
		speed_factor = clampf(horiz.length() / 20.0, 0.0, 1.0)
	if player and player.has_method("add_camera_shake"):
		player.add_camera_shake(camera_shake_intensity)

	_recoil_back = recoil_amount * 4.0 * (1.0 + speed_factor * 0.8)
	_recoil_pitch = recoil_amount * 2.0 * (1.0 + speed_factor * 0.5)

	# Динамический разброс при беге
	if speed_factor > 0.3:
		spread_degrees = 1.8 + speed_factor * 2.0
	else:
		spread_degrees = 1.8

	AudioManager.play_ak_shot_2d()
	return true


func _fire_chain(origin: Vector3, dir: Vector3, chain_level: int, player: Node, cam: Camera3D) -> void:
	var max_bounces: int = chain_level
	var chance: float = 0.5 + 0.1 * (max_bounces - 1)
	var hits: int = max(1, max_bounces + 1)

	var current_pos: Vector3 = origin
	var current_dir: Vector3 = dir
	var tracer_from: Vector3 = cam.global_position + cam.global_transform.basis * tracer_offset

	var already_hit_positions: Array[Vector3] = []

	if not SwarmManager:
		push_error("AK: SwarmManager не найден!")
		return

	for i in range(hits):
		var hit: bool = SwarmManager.damage_ray(current_pos, current_dir, shoot_range, damage)
		var hit_pos := Vector3.ZERO
		if hit:
			hit_pos = SwarmManager.get_hit_position(current_pos, current_dir, shoot_range)
			if hit_pos == Vector3.ZERO:
				hit_pos = current_pos + current_dir * shoot_range * 0.5
			spawn_tracer(tracer_from, hit_pos)
			already_hit_positions.append(hit_pos)
		else:
			var end_pos := current_pos + current_dir * shoot_range
			spawn_tracer(tracer_from, end_pos)
			break

		if i == hits - 1:
			break
		if i >= 1 and randf() >= chance:
			break

		# Ищем ближайшего врага через SwarmManager
		var all_positions: Array[Vector3] = SwarmManager.get_all_mob_positions()
		var nearest_dist := INF
		var nearest_pos := Vector3.ZERO
		for pos in all_positions:
			var skip := false
			for old in already_hit_positions:
				if old.distance_to(pos) < 0.5:
					skip = true
					break
			if skip:
				continue
			var d := hit_pos.distance_to(pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest_pos = pos

		if nearest_pos == Vector3.ZERO:
			break

		current_dir = (nearest_pos - hit_pos).normalized()
		current_pos = hit_pos + current_dir * 0.3
		tracer_from = hit_pos


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
