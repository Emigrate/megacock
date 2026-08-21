extends Node3D

const TRACER_SCRIPT := preload("res://scripts/tracer.gd")
const FLASH_SCRIPT := preload("res://scripts/muzzle_flash.gd")

@export var pellet_count := 12
@export var pellet_damage := 25.0
@export var fire_rate := 1
@export var shoot_range := 100.0
@export var spread_degrees := 5.0
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

# --- НАСТРОЙКА ТРЕЙСЕРА ---
@export var tracer_offset := Vector3(0.3, -0.30, -4)

# --- НАСТРОЙКИ БОБА ---
@export var bob_position_scale := 0.6
@export var bob_rotation_scale := 0.6

# --- ИНТЕНСИВНОСТЬ ОТДАЧИ И FOV-ШЕЙКА ---
@export var camera_shake_intensity := 1

# --- НАСТРОЙКИ ЦЕПИ ДЛЯ ДРОБОВИКА ---
@export var chain_limit_multiplier: float = 2.0   # во сколько раз больше отскоков
@export var max_chains_per_shot: int = 5         # сколько дробинок могут инициировать цепь за выстрел

var can_fire := true
var _model: Node3D
var ammo := 6
var is_reloading := false

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
	var _scale = sigma / 0.577 / falloff
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
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z

	var spread_rad := deg_to_rad(spread_degrees)

	var tracer_start := cam.global_position + cam.global_transform.basis * tracer_offset

	var hit_positions: Array[Vector3] = []  # собираем все попадания

	if not SwarmManager:
		push_error("Shotgun: SwarmManager не найден!")
		return false

	for i in range(pellet_count):
		var angle_h = _generate_normal_angle(spread_rad, spread_falloff)
		var angle_v = _generate_normal_angle(spread_rad, spread_falloff)

		var spread_dir := dir
		spread_dir = spread_dir.rotated(cam.global_transform.basis.y, angle_h)
		spread_dir = spread_dir.rotated(cam.global_transform.basis.x, angle_v)

		# Выстрел через мультимеш
		var result = SwarmManager.damage_ray_with_hit(origin, spread_dir, shoot_range, pellet_damage)
		var hit: bool = result[0]
		var hit_pos: Vector3 = result[1]

		if hit:
			if hit_pos == Vector3.ZERO:
				hit_pos = origin + spread_dir * shoot_range * 0.5
			spawn_tracer(tracer_start, hit_pos)
			hit_positions.append(hit_pos)
		else:
			var end_pos = origin + spread_dir * shoot_range
			spawn_tracer(tracer_start, end_pos)

	var muzzle_pos := cam.global_position + cam.global_transform.basis * muzzle_offset
	spawn_flash(muzzle_pos)

	_recoil_back = recoil_amount * 4.0
	_recoil_pitch = recoil_amount * 2.0

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_camera_shake"):
		player.add_camera_shake(camera_shake_intensity)

	AudioManager.play_shotgun_shot_2d()

	# --- ЦЕПНАЯ РЕАКЦИЯ: каждая дробинка запускает свою цепь ---
	if player and player.chain_count > 0 and not hit_positions.is_empty():
		var effective_chain_level = int(player.chain_count * chain_limit_multiplier)
		var num_chains = min(hit_positions.size(), max_chains_per_shot)
		for i in range(num_chains):
			var start_pos = hit_positions[i]
			var chain_dir = (start_pos - cam.global_position).normalized()
			_fire_chain(start_pos, chain_dir, effective_chain_level, player, cam, pellet_damage)

	return true

func _fire_chain(start_pos: Vector3, start_dir: Vector3, chain_level: int, _player: Node, cam: Camera3D, chain_damage: float) -> void:
	var max_bounces: int = chain_level
	var chance: float = 0.5 + 0.1 * (max_bounces - 1)
	var hits: int = max(1, max_bounces + 1)

	var current_pos: Vector3 = start_pos
	var current_dir: Vector3 = start_dir
	var tracer_from: Vector3 = cam.global_position + cam.global_transform.basis * tracer_offset
	var already_hit_positions: Array[Vector3] = [start_pos]

	for i in range(1, hits):  # первый выстрел уже сделан
		# Ищем следующую цель (горизонтально)
		var all_positions := SwarmManager.get_all_mob_positions()
		var nearest_dist := INF
		var nearest_pos := Vector3.ZERO
		var current_pos_xz = current_pos
		current_pos_xz.y = 0.0

		for pos in all_positions:
			var skip := false
			for old in already_hit_positions:
				if old.distance_to(pos) < 0.5:
					skip = true
					break
			if skip:
				continue
			var pos_xz = pos
			pos_xz.y = 0.0
			var d = current_pos_xz.distance_to(pos_xz)
			if d < nearest_dist:
				nearest_dist = d
				nearest_pos = pos

		if nearest_pos == Vector3.ZERO:
			break

		# Проверяем шанс на цепь
		if i > 1 and randf() >= chance:
			break

		# Перенаправляем луч (полный 3D, без обнуления Y)
		var dir_to_next = nearest_pos - current_pos
		if dir_to_next.length() < 0.001:
			break
		current_dir = dir_to_next.normalized()
		current_pos = current_pos + current_dir * 0.3

		# Выстрел в следующую цель
		var result = SwarmManager.damage_ray_with_hit(current_pos, current_dir, shoot_range, chain_damage)
		var hit: bool = result[0]
		var hit_pos: Vector3 = result[1]
		if hit:
			if hit_pos == Vector3.ZERO:
				hit_pos = current_pos + current_dir * shoot_range * 0.5
			spawn_tracer(tracer_from, hit_pos)
			already_hit_positions.append(hit_pos)
			tracer_from = hit_pos
		else:
			break

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
