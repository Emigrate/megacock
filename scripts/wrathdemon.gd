extends Node

const MAX_MOBS := 400
const MOB_SCENE := preload("res://scenes/hydra.tscn")
const DEMON_SCENE := preload("res://scenes/wrathdemon.tscn")
const GROUND_Y := 0.5

@export var min_spawn_distance := 30.0
@export var max_spawn_distance := 100.0
@export var speed := 4.0

var _mobs: Array = []
var _player: Node3D
var _spawn_accumulator: float = 0.0
var _spawn_rate: float = 1.0
var _nav_map: RID = RID()


func _ready() -> void:
	_find_player()
	_find_navigation_map()
	print("🟢 Автоспавн: 1 моб/сек (гидры + демоны 50/50)")
	_spawn_accumulator = 1.0


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D
		print("✅ Игрок найден: ", _player.name)
	else:
		_player = null
		print("⚠️ Игрок пока не найден...")


func _find_navigation_map() -> void:
	var root = get_tree().current_scene
	if root == null:
		return
	_find_nav_recursive(root)
	if _nav_map.is_valid():
		print("✅ Найдена навигационная карта для спавна!")
	else:
		print("⚠️ Навигационная карта не найдена, спавн будет по высоте игрока.")


func _find_nav_recursive(node: Node) -> void:
	if node is NavigationRegion3D:
		_nav_map = node.get_navigation_map()
		return
	for child in node.get_children():
		_find_nav_recursive(child)
		if _nav_map.is_valid():
			return


func _process(delta: float) -> void:
	if _player == null:
		_find_player()
		return

	if _mobs.size() < MAX_MOBS:
		_spawn_accumulator += delta * _spawn_rate
		while _spawn_accumulator >= 1.0:
			_spawn_mob_auto()
			_spawn_accumulator -= 1.0


func _spawn_mob_auto() -> void:
	if _player == null:
		return

	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(min_spawn_distance, max_spawn_distance)
	var candidate: Vector3 = _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	var spawn_pos: Vector3
	if _nav_map.is_valid():
		var nav_pos: Vector3 = NavigationServer3D.map_get_closest_point(_nav_map, candidate)
		if nav_pos != Vector3.ZERO:
			spawn_pos = nav_pos
			spawn_pos.y += GROUND_Y
		else:
			spawn_pos = candidate
			spawn_pos.y = GROUND_Y
	else:
		spawn_pos = candidate
		spawn_pos.y = GROUND_Y

	# --- 50/50 шанс на гидру или демона ---
	if randf() < 0.5:
		spawn(spawn_pos)  # гидра (на земле)
	else:
		# Демон спавнится в воздухе (рандомная высота 2–5 метров)
		var demon_pos := spawn_pos
		demon_pos.y += randf_range(2.0, 5.0)
		spawn_demon(demon_pos)


# --- API ---

func add_extra_spawn(amount: float) -> void:
	_spawn_rate += amount
	print("🟢 Скорость спавна: ", _spawn_rate, " моб/сек")


func spawn(pos: Vector3) -> void:
	if _mobs.size() >= MAX_MOBS:
		return
	var mob_root = MOB_SCENE.instantiate()
	var mob: CharacterBody3D = _find_mob_body(mob_root)
	if mob == null:
		print("⚠️ CharacterBody3D не найден в сцене гидры!")
		return
	get_tree().current_scene.add_child(mob_root)
	mob.global_position = pos
	_mobs.append(mob)


func spawn_demon(pos: Vector3) -> void:
	if _mobs.size() >= MAX_MOBS:
		return
	var demon_root = DEMON_SCENE.instantiate()
	var demon: CharacterBody3D = _find_mob_body(demon_root)
	if demon == null:
		print("⚠️ CharacterBody3D не найден в сцене демона!")
		return
	get_tree().current_scene.add_child(demon_root)
	demon.global_position = pos
	_mobs.append(demon)
	print("👹 Демон заспавнен!")


func _find_mob_body(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var found = _find_mob_body(child)
		if found:
			return found
	return null


func spawn_random() -> void:
	if _player == null:
		return
	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(3.0, max_spawn_distance)
	var pos: Vector3 = _player.global_position + Vector3(cos(angle) * dist, GROUND_Y, sin(angle) * dist)
	spawn(pos)


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


func get_count() -> int:
	return _mobs.size()


func clear_all() -> void:
	for mob in _mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_mobs.clear()


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
	if hit_count > 0:
		print("💥 Мультиудар! Задето мобов: ", hit_count)
	return hit_count
