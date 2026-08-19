extends Node
const GROUND_Y := 0.0   # <--- ОПУСТИЛИ НА 0.0

@export var max_mobs_total := 400
@export var min_spawn_distance := 30.0
@export var max_spawn_distance := 100.0
@export var spawn_interval := 0.3

var ghoul_swarm: GhoulSwarm = null
var _mobs: Array = []
var _fireballs: Array = [] 
var _player: Node3D
var _nav_map: RID = RID()
var _spawn_timer: Timer

func _ready() -> void:
	_find_player()
	_find_navigation_map()
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)
	_spawn_timer.start()

func set_ghoul_swarm(swarm: GhoulSwarm) -> void:
	ghoul_swarm = swarm

func get_total_alive() -> int:
	if ghoul_swarm:
		return ghoul_swarm.get_alive_count()
	return 0

func get_count() -> int:
	return get_total_alive()

func _on_spawn_tick() -> void:
	if get_total_alive() >= max_mobs_total or _player == null:
		return
	_spawn_ghoul()

func _spawn_ghoul() -> void:
	if ghoul_swarm == null: return
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO: return
	ghoul_swarm.spawn(pos)

func _get_spawn_position() -> Vector3:
	if _player == null: return Vector3.ZERO
	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(min_spawn_distance, max_spawn_distance)
	var candidate: Vector3 = _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	var tries := 0
	while candidate.distance_to(_player.global_position) < 10.0 and tries < 10:
		angle = randf_range(0.0, TAU)
		dist = randf_range(min_spawn_distance, max_spawn_distance)
		candidate = _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		tries += 1

	if _nav_map.is_valid():
		var nav_pos = NavigationServer3D.map_get_closest_point(_nav_map, candidate)
		if nav_pos != Vector3.ZERO:
			return Vector3(nav_pos.x, nav_pos.y + GROUND_Y, nav_pos.z)
	return Vector3(candidate.x, GROUND_Y, candidate.z)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D

func _find_navigation_map() -> void:
	var root = get_tree().current_scene
	if root == null: return
	_find_nav_recursive(root)

func _find_nav_recursive(node: Node) -> void:
	if node is NavigationRegion3D:
		_nav_map = node.get_navigation_map()
		return
	for child in node.get_children():
		_find_nav_recursive(child)
		if _nav_map.is_valid(): return

# Пустышки для совместимости
func register_fireball(fb): _fireballs.append(fb)
func unregister_fireball(fb): _fireballs.erase(fb)
func get_fireballs(): return _fireballs
func get_nearby_fireballs(origin, radius): return []

func clear_all():
	if ghoul_swarm: ghoul_swarm.clear_all()

func spawn(pos):
	if ghoul_swarm: ghoul_swarm.spawn(pos)

func damage_ray(origin, dir, max_range, damage):
	if ghoul_swarm: 
		return ghoul_swarm.damage_ray(origin, dir, max_range, damage)
	return false

func get_hit_position(origin, dir, max_range):
	if ghoul_swarm: return ghoul_swarm.get_hit_position(origin, dir, max_range)
	return Vector3.ZERO

func melee_splash(origin: Vector3, atk_range: float, damage: int) -> int:
	if ghoul_swarm:
		return ghoul_swarm.melee_splash(origin, atk_range, damage)
	return 0

func aoe_damage(center: Vector3, radius: float, damage: int) -> int:
	if ghoul_swarm:
		return ghoul_swarm.aoe_damage(center, radius, damage)
	return 0
