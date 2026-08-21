extends Node
const GROUND_Y := 0.0

@export var max_mobs_total := 1000
@export var min_spawn_distance := 30.0
@export var max_spawn_distance := 100.0
@export var spawn_interval := 0.10

var ghoul_swarm: GhoulSwarm = null
var demon_swarm: DemonSwarm = null
var skeleton_swarm: SkeletonSwarm = null
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

func set_demon_swarm(swarm: DemonSwarm) -> void:
	demon_swarm = swarm

func set_skeleton_swarm(swarm: SkeletonSwarm) -> void:
	skeleton_swarm = swarm

func get_total_alive() -> int:
	var count = 0
	if ghoul_swarm:
		count += ghoul_swarm.get_alive_count()
	if demon_swarm:
		count += demon_swarm.get_alive_count()
	if skeleton_swarm:
		count += skeleton_swarm.get_alive_count()
	return count

func get_count() -> int:
	return get_total_alive()

func _on_spawn_tick() -> void:
	if get_total_alive() >= max_mobs_total or _player == null:
		return
	
	# Спавн гулей (основная масса)
	_spawn_ghoul()
	
	# Спавн демонов (редкие)
	if randf() < 0.08:
		_spawn_demon()
	
	# Спавн скелетов (редкие)
	if randf() < 0.08:
		_spawn_skeleton()

func _spawn_ghoul() -> void:
	if ghoul_swarm == null: return
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO: return
	ghoul_swarm.spawn(pos)

func _spawn_demon() -> void:
	if demon_swarm == null: return
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO: return
	demon_swarm.spawn(pos)

func _spawn_skeleton() -> void:
	if skeleton_swarm == null: return
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO: return
	skeleton_swarm.spawn(pos)

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

# ==========================================================
# ПРОКСИ-ФУНКЦИИ ДЛЯ МУЛЬТИМЕША
# ==========================================================
func register_fireball(fb): _fireballs.append(fb)
func unregister_fireball(fb): _fireballs.erase(fb)
func get_fireballs(): return _fireballs

func get_nearby_fireballs(_origin: Vector3, _radius: float) -> Array:
	return []

func get_all_mob_positions() -> Array[Vector3]:
	var res: Array[Vector3] = []
	if ghoul_swarm:
		res.append_array(ghoul_swarm.get_all_mob_positions())
	if demon_swarm:
		res.append_array(demon_swarm.get_all_mob_positions())
	if skeleton_swarm:
		res.append_array(skeleton_swarm.get_all_mob_positions())
	# Добавляем живые фаерболы
	for fb in _fireballs:
		if is_instance_valid(fb) and not fb.is_exploded():
			res.append(fb.global_position)
	return res

func clear_all():
	if ghoul_swarm: ghoul_swarm.clear_all()
	if demon_swarm: demon_swarm.clear_all()
	if skeleton_swarm: skeleton_swarm.clear_all()

func spawn(pos):
	if ghoul_swarm: ghoul_swarm.spawn(pos)
	if demon_swarm: demon_swarm.spawn(pos)
	if skeleton_swarm: skeleton_swarm.spawn(pos)

func damage_ray(origin, dir, max_range, damage):
	if ghoul_swarm and ghoul_swarm.damage_ray(origin, dir, max_range, damage):
		return true
	if demon_swarm and demon_swarm.damage_ray(origin, dir, max_range, damage):
		return true
	if skeleton_swarm and skeleton_swarm.damage_ray(origin, dir, max_range, damage):
		return true
	return false

func get_hit_position(origin, dir, max_range):
	var best_dist = max_range
	var res = origin + dir * max_range
	if ghoul_swarm:
		var hit = ghoul_swarm.get_hit_position(origin, dir, max_range)
		if hit != Vector3.ZERO:
			res = hit
			best_dist = origin.distance_to(hit)
	if demon_swarm:
		var hit = demon_swarm.get_hit_position(origin, dir, max_range)
		if hit != Vector3.ZERO and origin.distance_to(hit) < best_dist:
			res = hit
	if skeleton_swarm:
		var hit = skeleton_swarm.get_hit_position(origin, dir, max_range)
		if hit != Vector3.ZERO and origin.distance_to(hit) < best_dist:
			res = hit
	return res

func damage_ray_with_hit(origin: Vector3, dir: Vector3, m_range: float, dmg: float) -> Array:
	# Проверяем гулей
	if ghoul_swarm:
		var result = ghoul_swarm.damage_ray_with_hit(origin, dir, m_range, dmg)
		if result[0]:
			return result
	# Проверяем демонов
	if demon_swarm:
		var result = demon_swarm.damage_ray_with_hit(origin, dir, m_range, dmg)
		if result[0]:
			return result
	# Проверяем скелетов
	if skeleton_swarm:
		var result = skeleton_swarm.damage_ray_with_hit(origin, dir, m_range, dmg)
		if result[0]:
			return result
	# Проверяем фаерболы
	var best_dist = m_range
	var best_fb = null
	var best_center = origin + dir * m_range
	for fb in _fireballs:
		if not is_instance_valid(fb):
			continue
		if fb.is_exploded():
			continue
		var center = fb.global_position
		var to_fb = center - origin
		var proj = to_fb.dot(dir)
		if proj < 0 or proj > m_range:
			continue
		var closest = origin + dir * proj
		if closest.distance_to(center) < 2.8 and proj < best_dist:
			best_dist = proj
			best_fb = fb
			best_center = center
	if best_fb != null:
		best_fb.explode()
		return [true, best_center]
	return [false, Vector3.ZERO]

func melee_splash(origin: Vector3, atk_range: float, damage: int) -> int:
	var count = 0
	if ghoul_swarm:
		count += ghoul_swarm.melee_splash(origin, atk_range, damage)
	if demon_swarm:
		count += demon_swarm.melee_splash(origin, atk_range, damage)
	if skeleton_swarm:
		count += skeleton_swarm.melee_splash(origin, atk_range, damage)
	return count

func aoe_damage(center: Vector3, radius: float, damage: int) -> int:
	var count = 0
	if ghoul_swarm:
		count += ghoul_swarm.aoe_damage(center, radius, damage)
	if demon_swarm:
		count += demon_swarm.aoe_damage(center, radius, damage)
	if skeleton_swarm:
		count += skeleton_swarm.aoe_damage(center, radius, damage)
	return count
