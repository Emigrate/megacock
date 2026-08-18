extends Node3D

const TRACER_SCRIPT := preload("res://scripts/tracer.gd")
const FLASH_SCRIPT := preload("res://scripts/muzzle_flash.gd")

@export var damage := 30.0
@export var fire_rate := 8.0
@export var shoot_range := 120.0
@export var recoil_amount := 0.08
@export var spread_degrees := 1.5
@export var first_shot_reset_time := 0.15
@export var is_auto := true

# --- НАСТРОЙКИ МАЗЛА ---
@export var muzzle_offset := Vector3(0.3,-0.5, -4)
@export var flash_scale := 1
@export var flash_start_size := 0.20
@export var flash_end_size := 0.03

# --- НАСТРОЙКА ТРЕЙСЕРА ---
@export var tracer_offset := Vector3(1, -1.3, -4)

# --- НАСТРОЙКИ БОБА ---
@export var bob_position_scale := 0.2
@export var bob_rotation_scale := 0.15

# --- ИНТЕНСИВНОСТЬ ОТДАЧИ И FOV-ШЕЙКА ---
@export var camera_shake_intensity := 0.3

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


func try_fire() -> bool:
	if not can_fire:
		return false

	can_fire = false
	get_tree().create_timer(1.0 / fire_rate).timeout.connect(func():
		can_fire = true)

	var cam := get_parent() as Camera3D
	var space_state := cam.get_world_3d().direct_space_state

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

	_fire_chain(origin, dir, chain_level, player, space_state)

	var muzzle_pos := cam.global_position + cam.global_transform.basis * muzzle_offset
	spawn_flash(muzzle_pos)

	var speed_factor := 0.0
	if player is CharacterBody3D:
		var horiz := Vector2(player.velocity.x, player.velocity.z)
		speed_factor = clampf(horiz.length() / 20.0, 0.0, 1.0)
	if player and player.has_method("add_camera_shake"):
		player.add_camera_shake(camera_shake_intensity)

	_recoil_back = recoil_amount * 3.5 * (1.0 + speed_factor * 0.8)
	_recoil_pitch = recoil_amount * 1.5 * (1.0 + speed_factor * 0.5)

	if speed_factor > 0.3:
		spread_degrees = 1.5 + speed_factor * 1.5
	else:
		spread_degrees = 1.5

	AudioManager.play_ak_shot_2d()
	return true


func _fire_chain(origin: Vector3, dir: Vector3, chain_level: int, player: Node, space_state: PhysicsDirectSpaceState3D) -> void:
	var cam := get_parent() as Camera3D

	var current_pos: Vector3 = origin
	var current_dir: Vector3 = dir
	var current_target: Vector3 = current_pos + current_dir * shoot_range

	var tracer_from: Vector3 = cam.global_position + cam.global_transform.basis * tracer_offset

	var max_bounces: int = chain_level
	var chance: float = 0.5 + 0.1 * (max_bounces - 1)
	var hits: int = max(1, max_bounces + 1)

	var already_hit: Array = []

	for i in range(hits):
		var query := PhysicsRayQueryParameters3D.create(current_pos, current_target)
		if player:
			query.exclude = [player.get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)

		if not hit.is_empty():
			var c: Object = hit.collider
			var hit_position: Vector3 = hit.position

			spawn_tracer(tracer_from, hit_position)

			if c != null and c.has_method("take_damage"):
				c.take_damage(damage)
				already_hit.append(c)

			if i == hits - 1:
				break

			if i >= 1 and randf() >= chance:
				break

			var enemies := get_tree().get_nodes_in_group("mob")
			var closest_dist := INF
			var closest_enemy: Node3D = null

			for enemy in enemies:
				if not is_instance_valid(enemy) or enemy in already_hit:
					continue
				var d := hit_position.distance_to(enemy.global_position)
				if d < closest_dist:
					closest_dist = d
					closest_enemy = enemy

			if closest_enemy:
				current_dir = (closest_enemy.global_position - hit_position).normalized()
				current_pos = hit_position + current_dir * 0.3
				current_target = current_pos + current_dir * shoot_range
				tracer_from = hit_position
			else:
				break
		else:
			spawn_tracer(tracer_from, current_target)
			break


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
