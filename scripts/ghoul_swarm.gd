extends Node3D
class_name GhoulSwarm

@export var max_ghouls := 400
@export var mesh_size := Vector2(5, 5)          # Твой размер
@export var move_speed := 9.0
@export var attack_range := 2.2
@export var attack_interval := 0.8
@export var attack_damage := 10.0

# --- НАСТРОЙКИ ЗДОРОВЬЯ ---
@export var initial_hp := 30.0

# --- НАСТРОЙКИ РАСТАЛКИВАНИЯ (УСИЛЕННЫЕ!) ---
@export var separation_dist := 3.0       # Увеличили с 1.5 до 3.0
@export var separation_strength := 1.0   # Увеличили с 0.4 до 1.0
@export var grid_size := 3.0

# --- ОПТИМИЗАЦИЯ ---
@export var grid_rebuild_interval := 0.1
@export var separation_update_interval := 0.1
@export var cull_distance := 60.0
@export var lod_distance := 30.0

# --- КОРРЕКЦИЯ ВЫСОТЫ (твоя!) ---
@export var ground_offset := -1.0

# ==========================================
# ГЛАВНЫЙ ФИКС ПРОСВЕТОВ: ОККЛЮЗИЯ
# ==========================================
@export var occlusion_cell_px := 14.0   # Если надо, поменяй в инспекторе

enum State { WALK, ATTACK, HIT, DEATH, DEAD }

var multimesh: MultiMesh
var positions: PackedVector3Array
var hp: PackedFloat32Array
var states: PackedInt32Array
var anim_timer: PackedFloat32Array
var attack_cd: PackedFloat32Array
var alive_flags: PackedByteArray
var scales: PackedFloat32Array
var free_list: Array[int] = []

# Сетка и таймеры
var _grid: Dictionary = {}
var _grid_timer := 0.0
var _sep_timer := 0.0
var _player: Node3D
var _foot_offset: float

# Кэш для сепарации
var _sep_cache: PackedVector3Array = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_foot_offset = mesh_size.y * 0.5
	if is_instance_valid(SwarmManager):
		SwarmManager.set_ghoul_swarm(self)
	_setup_arrays()
	_setup_multimesh()
	_sep_cache.resize(max_ghouls)

func _setup_arrays() -> void:
	positions.resize(max_ghouls)
	hp.resize(max_ghouls)
	states.resize(max_ghouls)
	anim_timer.resize(max_ghouls)
	attack_cd.resize(max_ghouls)
	alive_flags.resize(max_ghouls)
	scales.resize(max_ghouls)
	for i in range(max_ghouls):
		alive_flags[i] = 0
		free_list.append(max_ghouls - 1 - i)

func _setup_multimesh() -> void:
	var quad = QuadMesh.new()
	quad.size = mesh_size
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/mob_billboard.gdshader")
	mat.set_shader_parameter("tex_array", GhoulData.texture_array)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = max_ghouls
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.material_override = mat
	add_child(mmi)

func spawn(pos: Vector3) -> void:
	if free_list.is_empty(): return
	var i = free_list.pop_back()
	positions[i] = pos + Vector3(randf_range(-1,1), 0, randf_range(-1,1))
	hp[i] = initial_hp
	states[i] = State.WALK
	anim_timer[i] = 0.0
	attack_cd[i] = 0.0
	alive_flags[i] = 1
	scales[i] = randf_range(0.9, 1.1)

# ---------- БОЕВЫЕ ФУНКЦИИ ----------
func damage_ray(origin: Vector3, dir: Vector3, m_range: float, dmg: float) -> bool:
	var best_dist = m_range
	var best_i = -1
	for i in range(max_ghouls):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		var center = positions[i] + Vector3(0, _foot_offset, 0)
		var to_mob = center - origin
		var proj = to_mob.dot(dir)
		if proj < 0 or proj > m_range: continue
		var closest = origin + dir * proj
		if closest.distance_to(center) < 1.6 and proj < best_dist:
			best_dist = proj
			best_i = i
	if best_i != -1:
		hp[best_i] -= dmg
		if hp[best_i] <= 0:
			states[best_i] = State.DEATH
			anim_timer[best_i] = 0.0
			AudioManager.play_ghoul_death_3d(positions[best_i])
		else:
			states[best_i] = State.HIT
			anim_timer[best_i] = 0.0
			AudioManager.play_ghoul_hit_3d(positions[best_i])
		DamageNumberPool.spawn(int(dmg), positions[best_i] + Vector3(0, _foot_offset, 0), false, best_i)
		return true
	return false

func get_hit_position(origin: Vector3, dir: Vector3, m_range: float) -> Vector3:
	var best_dist = m_range
	var res = origin + dir * m_range
	for i in range(max_ghouls):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		var center = positions[i] + Vector3(0, _foot_offset, 0)
		var proj = (center - origin).dot(dir)
		if proj < 0 or proj > m_range: continue
		var closest = origin + dir * proj
		if closest.distance_to(center) < 1.6 and proj < best_dist:
			best_dist = proj
			res = closest
	return res

func get_all_mob_positions() -> Array[Vector3]:
	var res: Array[Vector3] = []
	for i in range(max_ghouls):
		if alive_flags[i] == 1 and states[i] < State.DEATH:
			res.append(positions[i] + Vector3(0, _foot_offset, 0))
	return res

func get_alive_count() -> int:
	var count = 0
	for i in range(max_ghouls):
		if alive_flags[i] == 1: count += 1
	return count

# ---------- ОПТИМИЗИРОВАННАЯ СЕПАРАЦИЯ ----------
func _rebuild_grid():
	_grid.clear()
	for i in range(max_ghouls):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		var cell = Vector2i(
			floori(positions[i].x / grid_size),
			floori(positions[i].z / grid_size)
		)
		if not _grid.has(cell): _grid[cell] = []
		_grid[cell].append(i)

func _update_separation_cache():
	for i in range(max_ghouls):
		_sep_cache[i] = Vector3.ZERO
	
	for i in range(max_ghouls):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		# Убрали условие по дистанции, чтобы сепарация работала даже для дальних мобов
		# (иначе они будут слипаться на подходе)
		
		var pos = positions[i]
		var cell = Vector2i(floori(pos.x / grid_size), floori(pos.z / grid_size))
		var push = Vector3.ZERO
		if _grid.has(cell):
			for other_idx in _grid[cell]:
				if other_idx == i: continue
				var diff = pos - positions[other_idx]
				var dist = diff.length()
				if dist < separation_dist and dist > 0.01:
					push += (diff / dist) * (separation_dist - dist)
		_sep_cache[i] = push

func _get_separation_vector(idx: int) -> Vector3:
	return _sep_cache[idx]

# ---------- ЛОГИКА ДВИЖЕНИЯ И ОТРИСОВКА ----------
func _physics_process(delta: float) -> void:
	if not _player: return
	var p_pos = _player.global_position
	
	_grid_timer -= delta
	if _grid_timer <= 0.0:
		_grid_timer = grid_rebuild_interval
		_rebuild_grid()
	
	_sep_timer -= delta
	if _sep_timer <= 0.0:
		_sep_timer = separation_update_interval
		_update_separation_cache()
	
	for i in range(max_ghouls):
		if alive_flags[i] == 0: continue
		
		anim_timer[i] += delta
		
		# СМЕРТЬ С АНИМАЦИЕЙ
		if states[i] == State.DEATH:
			if anim_timer[i] >= GhoulData.anim_duration("death"):
				alive_flags[i] = 0
				free_list.append(i)
				multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0,-500,0)))
			else:
				var frame = GhoulData.frame_for("death", anim_timer[i])
				var s = scales[i]
				var draw_pos = positions[i] + Vector3(0, (_foot_offset + ground_offset) * s, 0)
				var basis = Basis().scaled(Vector3.ONE * s)
				multimesh.set_instance_transform(i, Transform3D(basis, draw_pos))
				multimesh.set_instance_color(i, Color(float(frame) / 15.0, 0, 0, 1))
			continue
		
		# ХИТ / АТАКА (завершение анимации)
		if states[i] == State.HIT:
			if anim_timer[i] >= GhoulData.anim_duration("hit"):
				states[i] = State.WALK
				anim_timer[i] = 0.0
		elif states[i] == State.ATTACK:
			if anim_timer[i] >= GhoulData.anim_duration("attack"):
				states[i] = State.WALK
				anim_timer[i] = 0.0
		
		attack_cd[i] = max(0.0, attack_cd[i] - delta)
		
		var to_p = p_pos - positions[i]
		to_p.y = 0
		var dist_to_player = to_p.length()
		
		# ДВИЖЕНИЕ
		if states[i] == State.WALK:
			var velocity = Vector3.ZERO
			if dist_to_player > attack_range:
				velocity += to_p.normalized()
			
			# Сепарация применяется всегда (без ограничения по дистанции)
			velocity += _get_separation_vector(i) * separation_strength
			
			var move = velocity.normalized() * move_speed * delta
			positions[i] += move
		
		# АТАКА
		if dist_to_player <= attack_range and attack_cd[i] <= 0.0 and states[i] == State.WALK:
			states[i] = State.ATTACK
			attack_cd[i] = attack_interval
			anim_timer[i] = 0.0
			AudioManager.play_ghoul_swing_3d(positions[i])
			if _player.has_method("take_damage"):
				_player.take_damage(attack_damage)

	# ==========================================
	# ФИНАЛЬНАЯ ОТРИСОВКА С ЭКРАННОЙ ОККЛЮЗИЕЙ
	# ==========================================
	_draw_with_occlusion_culling(p_pos)

func _draw_with_occlusion_culling(player_pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		for i in range(max_ghouls):
			if alive_flags[i] == 0: continue
			_write_instance(i)
		return
	
	var cam_pos := cam.global_position
	
	var draw_list: Array = []
	for i in range(max_ghouls):
		if alive_flags[i] == 0 or states[i] == State.DEAD: continue
		var center := positions[i] + Vector3(0, (_foot_offset + ground_offset) * scales[i], 0)
		var dist_sq := cam_pos.distance_squared_to(center)
		draw_list.append([i, dist_sq])
	draw_list.sort_custom(func(a, b): return a[1] < b[1])

	var occupied_cells := {}

	for pair in draw_list:
		var i = pair[0]
		var force_visible := states[i] == State.DEATH
		var center := positions[i] + Vector3(0, (_foot_offset + ground_offset) * scales[i], 0)

		if not force_visible and cam.is_position_behind(center):
			_hide_instance(i)
			continue

		var screen_pos := cam.unproject_position(center)
		var cell := Vector2i(int(screen_pos.x / occlusion_cell_px), int(screen_pos.y / occlusion_cell_px))

		var blocked := false
		if not force_visible:
			if occupied_cells.has(cell):
				blocked = true

		if blocked:
			_hide_instance(i)
			continue

		occupied_cells[cell] = true
		_write_instance(i)

func _hide_instance(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0,-500,0)))

func _write_instance(i: int) -> void:
	var s = scales[i]
	var draw_pos = positions[i] + Vector3(0, (_foot_offset + ground_offset) * s, 0)
	var basis = Basis().scaled(Vector3.ONE * s)
	multimesh.set_instance_transform(i, Transform3D(basis, draw_pos))
	
	var frame = GhoulData.frame_for(_current_anim_name(i), anim_timer[i])
	multimesh.set_instance_color(i, Color(float(frame) / 15.0, 0, 0, 1))

func _current_anim_name(i: int) -> String:
	match states[i]:
		State.DEATH: return "death"
		State.HIT: return "hit"
		State.ATTACK: return "attack"
		_: return "walk"
