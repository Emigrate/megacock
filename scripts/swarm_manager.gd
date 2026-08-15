extends Node

const MAX_MOBS := 400
const HYDRA_SCENE := preload("res://scenes/ghoul.tscn")
const DEMON_SCENE := preload("res://scenes/wrathdemon.tscn")
const GROUND_Y := 0.5

@export var min_spawn_distance := 30.0
@export var max_spawn_distance := 100.0
@export var demon_min_height := 8.0    # минимальная высота для демона
@export var demon_max_height := 25.0   # максимальная высота для демона

var _mobs: Array = []
var _player: Node3D
var _nav_map: RID = RID()
var _spawn_timer: Timer
var _spawn_counter: int = 0


func _ready() -> void:
	_find_player()
	_find_navigation_map()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 0.5
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)
	_spawn_timer.start()

	print("🟢 Спавн мобов запущен (гидра 1/сек, демон 1/2сек)")


func _on_spawn_tick() -> void:
	_clean_mobs()
	if _mobs.size() >= MAX_MOBS:
		return
	if _player == null:
		_find_player()
		return

	_spawn_counter += 1

	if _spawn_counter % 2 == 0:
		_spawn_hydra()

	if _spawn_counter % 4 == 0:
		_spawn_demon()


func _spawn_hydra() -> void:
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO:
		return

	var mob_root = HYDRA_SCENE.instantiate()
	var mob = _find_mob_body(mob_root)
	if mob == null:
		return
	get_tree().current_scene.add_child(mob_root)
	mob.global_position = pos
	_mobs.append(mob)


func _spawn_demon() -> void:
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO:
		return

	# --- СПАВНИМ ДЕМОНА СРАЗУ В НЕБЕ ---
	var height = randf_range(demon_min_height, demon_max_height)
	var spawn_pos = Vector3(pos.x, height, pos.z)

	var mob_root = DEMON_SCENE.instantiate()
	var mob = _find_mob_body(mob_root)
	if mob == null:
		return
	get_tree().current_scene.add_child(mob_root)
	mob.global_position = spawn_pos
	_mobs.append(mob)


func _get_spawn_position() -> Vector3:
	if _player == null:
		return Vector3.ZERO

	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(min_spawn_distance, max_spawn_distance)
	var candidate: Vector3 = _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	if _nav_map.is_valid():
		var nav_pos: Vector3 = NavigationServer3D.map_get_closest_point(_nav_map, candidate)
		if nav_pos != Vector3.ZERO:
			return Vector3(nav_pos.x, nav_pos.y + GROUND_Y, nav_pos.z)

	return Vector3(candidate.x, GROUND_Y, candidate.z)


func _clean_mobs() -> void:
	for i in range(_mobs.size() - 1, -1, -1):
		if not is_instance_valid(_mobs[i]):
			_mobs.remove_at(i)


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D
	else:
		_player = null


func _find_navigation_map() -> void:
	var root = get_tree().current_scene
	if root == null:
		return
	_find_nav_recursive(root)
	if _nav_map.is_valid():
		print("✅ Навигационная карта найдена")


func _find_nav_recursive(node: Node) -> void:
	if node is NavigationRegion3D:
		_nav_map = node.get_navigation_map()
		return
	for child in node.get_children():
		_find_nav_recursive(child)
		if _nav_map.is_valid():
			return


func _find_mob_body(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _find_mob_body(child)
		if found:
			return found
	return null


# --- API ---

func get_count() -> int:
	_clean_mobs()
	return _mobs.size()


func clear_all() -> void:
	for mob in _mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_mobs.clear()


func get_hit_position(origin: Vector3, dir: Vector3, max_range: float) -> Vector3:
	var best_dist: float = max_range
	var best_pos: Vector3 = Vector3.ZERO
	for mob in _mobs:
		if not is_instance_valid(mob):
			continue
		if mob.has_method("get_alive") and not mob.get_alive():
			continue
		var to_mob: Vector3 = mob.global_position - origin
		var proj: float = to_mob.dot(dir)
		if proj < 0 or proj > max_range:
			continue
		var closest: Vector3 = origin + dir * proj
		if closest.distance_to(mob.global_position) < 0.6 and proj < best_dist:
			best_dist = proj
			best_pos = mob.global_position
	return best_pos


func damage_ray(origin: Vector3, dir: Vector3, max_range: float, damage: int) -> bool:
	var best_dist: float = max_range
	var best_mob = null
	for mob in _mobs:
		if not is_instance_valid(mob):
			continue
		if mob.has_method("get_alive") and not mob.get_alive():
			continue
		var to_mob: Vector3 = mob.global_position - origin
		var proj: float = to_mob.dot(dir)
		if proj < 0 or proj > max_range:
			continue
		var closest: Vector3 = origin + dir * proj
		if closest.distance_to(mob.global_position) < 0.6 and proj < best_dist:
			best_dist = proj
			best_mob = mob
	if best_mob and best_mob.has_method("take_damage"):
		best_mob.take_damage(damage)
		return true
	return false


func aoe_damage(center: Vector3, radius: float, damage: int) -> int:
	var killed: int = 0
	for mob in _mobs:
		if not is_instance_valid(mob):
			continue
		if mob.has_method("get_alive") and not mob.get_alive():
			continue
		if mob.global_position.distance_to(center) < radius:
			if mob.has_method("take_damage"):
				mob.take_damage(damage)
				killed += 1
	return killed


func get_all_mob_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mob in _mobs:
		if is_instance_valid(mob):
			result.append(mob.global_position)
	return result


func melee_splash(origin: Vector3, attack_range: float, damage: int) -> int:
	var hit_count := 0
	for mob in _mobs:
		if not is_instance_valid(mob):
			continue
		if mob.has_method("get_alive") and not mob.get_alive():
			continue
		var dist: float = origin.distance_to(mob.global_position)
		if dist <= attack_range:
			if mob.has_method("take_damage"):
				mob.take_damage(damage)
				hit_count += 1
	return hit_count
