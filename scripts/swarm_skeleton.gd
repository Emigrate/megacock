extends Node3D
class_name SkeletonSwarm

# ===== СТАТИЧЕСКИЕ ДАННЫЕ ТЕКСТУР И АНИМАЦИЙ =====
const FRAME_PATHS := [
	"res://assets/textures/skeleton/sceleton_attack1.png",
	"res://assets/textures/skeleton/sceleton_attack2.png",
	"res://assets/textures/skeleton/sceleton_attack3.png",
	"res://assets/textures/skeleton/sceleton_attack4.png",
	"res://assets/textures/skeleton/sceleton_attack5.png",
	"res://assets/textures/skeleton/sceleton_attack6.png",
	"res://assets/textures/skeleton/sceleton_death1.png",
	"res://assets/textures/skeleton/sceleton_death2.png",
	"res://assets/textures/skeleton/sceleton_hit1.png",
	"res://assets/textures/skeleton/sceleton_hit2.png",
	"res://assets/textures/skeleton/sceleton_walk1.png",
	"res://assets/textures/skeleton/sceleton_walk2.png",
	"res://assets/textures/skeleton/sceleton_walk3.png",
	"res://assets/textures/skeleton/sceleton_walk4.png",
]

const ANIM_BASE := {
	"attack": {"start": 0,  "count": 6, "fps": 8.0,  "loop": false},
	"death":  {"start": 6,  "count": 2, "fps": 6.0,  "loop": false},
	"hit":    {"start": 8,  "count": 2, "fps": 10.0, "loop": false},
	"walk":   {"start": 10, "count": 4, "fps": 6.0,  "loop": true},
}

static var _cached_texture: Texture2DArray = null

static var texture_array: Texture2DArray:
	get:
		if _cached_texture == null:
			_cached_texture = _build_texture_array()
		return _cached_texture

static func _build_texture_array() -> Texture2DArray:
	var images: Array[Image] = []
	var max_w := 0
	var max_h := 0
	for path in FRAME_PATHS:
		var tex = load(path) as Texture2D
		if not tex: continue
		var img = tex.get_image()
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
		max_w = max(max_w, img.get_width())
		max_h = max(max_h, img.get_height())
	var normalized_images: Array[Image] = []
	for img in images:
		var canvas = Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
		var offset_x = int((max_w - img.get_width()) / 2.0)
		var offset_y = max_h - img.get_height()
		canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(offset_x, offset_y))
		normalized_images.append(canvas)
	var tex_array = Texture2DArray.new()
	tex_array.create_from_images(normalized_images)
	return tex_array

# ===== КОНЕЦ СТАТИЧЕСКИХ ДАННЫХ =====

@export var max_skeletons := 100
@export var mesh_size := Vector2(4, 5)
@export var move_speed := 10.0
@export var attack_range := 2.1
@export var attack_interval := 0.8
@export var attack_damage := 10.0

# --- НАСТРОЙКИ ЗДОРОВЬЯ ---
@export var initial_hp := 40.0

# --- НАСТРОЙКИ РАСТАЛКИВАНИЯ ---
@export var separation_dist := 1.5
@export var separation_strength := 0.5
@export var grid_size := 3.0
@export var grid_rebuild_interval := 0.1
@export var separation_update_interval := 0.15   # <-- добавили

# --- ОПТИМИЗАЦИЯ ---
@export var cull_distance := 1000.0
@export var lod_distance := 50.0

# --- КОРРЕКЦИЯ ВЫСОТЫ ---
@export var ground_offset := -1.0

# --- НАСТРОЙКИ ДРОПА ЭКСПЫ ---
@export var exp_orb_scene: PackedScene
@export var exp_drop_min: int = 15
@export var exp_drop_max: int = 15

# ===== КРУТИЛКИ СКОРОСТИ АНИМАЦИЙ =====
@export var walk_anim_speed: float = 3
@export var attack_anim_speed: float = 3
@export var hit_anim_speed: float = 4
@export var death_anim_speed: float = 1

# --- BULK-BUFFER MULTIMESH ---
const FLOATS_PER_INSTANCE := 16

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

var _grid: Dictionary = {}
var _grid_timer := 0.0
var _sep_timer := 0.0        # <-- добавили
var _player: Node3D
var _foot_offset: float
var _sep_cache: PackedVector3Array = []
var _mm_buffer: PackedFloat32Array = []
var _prev_visible: PackedByteArray = []

# Данные анимаций (с множителями)
var _anim_data: Dictionary = {}

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_foot_offset = mesh_size.y * 0.5
	if is_instance_valid(SwarmManager):
		SwarmManager.set_skeleton_swarm(self)
	_setup_arrays()
	_setup_multimesh()
	_sep_cache.resize(max_skeletons)
	_init_anim_data()

func _init_anim_data() -> void:
	_anim_data = {}
	for anim in ANIM_BASE:
		var base = ANIM_BASE[anim]
		var speed = 1.0
		match anim:
			"walk": speed = walk_anim_speed
			"attack": speed = attack_anim_speed
			"hit": speed = hit_anim_speed
			"death": speed = death_anim_speed
		_anim_data[anim] = {
			"start": base.start,
			"count": base.count,
			"fps": base.fps * speed,
			"loop": base.loop
		}

func _setup_arrays() -> void:
	positions.resize(max_skeletons)
	hp.resize(max_skeletons)
	states.resize(max_skeletons)
	anim_timer.resize(max_skeletons)
	attack_cd.resize(max_skeletons)
	alive_flags.resize(max_skeletons)
	scales.resize(max_skeletons)
	for i in range(max_skeletons):
		alive_flags[i] = 0
		free_list.append(max_skeletons - 1 - i)

func _setup_multimesh() -> void:
	var quad = QuadMesh.new()
	quad.size = mesh_size
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/mob_billboard.gdshader")
	mat.set_shader_parameter("tex_array", texture_array)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = max_skeletons
	multimesh.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.material_override = mat
	add_child(mmi)

	_mm_buffer.resize(max_skeletons * FLOATS_PER_INSTANCE)
	_mm_buffer.fill(0.0)
	multimesh.buffer = _mm_buffer
	_prev_visible.resize(max_skeletons)
	_prev_visible.fill(0)

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
func damage_ray_with_hit(origin: Vector3, dir: Vector3, m_range: float, dmg: float, apply: bool = true) -> Array:
	var best_dist = m_range
	var best_i = -1
	var best_center = origin + dir * m_range
	for i in range(max_skeletons):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		var center = positions[i] + Vector3(0, _foot_offset, 0)
		var to_mob = center - origin
		var proj = to_mob.dot(dir)
		if proj < 0 or proj > m_range: continue
		var closest = origin + dir * proj
		if closest.distance_to(center) < 2.8 and proj < best_dist:
			best_dist = proj
			best_i = i
			best_center = closest
	if best_i != -1 and apply:
		hp[best_i] -= dmg
		if hp[best_i] <= 0:
			states[best_i] = State.DEATH
			anim_timer[best_i] = 0.0
			AudioManager.play_sceleton_death_3d(positions[best_i])
			_spawn_exp_orb(best_i)
		else:
			states[best_i] = State.HIT
			anim_timer[best_i] = 0.0
			AudioManager.play_sceleton_hit_3d(positions[best_i])
		DamageNumberPool.spawn(int(dmg), positions[best_i] + Vector3(0, _foot_offset, 0), false, best_i)
		AudioManager.play_hitmarker()
		_show_hitmarker()
	if best_i != -1:
		return [apply, best_center]
	return [false, Vector3.ZERO]

func damage_ray(origin: Vector3, dir: Vector3, m_range: float, dmg: float) -> bool:
	var result = damage_ray_with_hit(origin, dir, m_range, dmg, true)
	return result[0]

func get_hit_position(origin: Vector3, dir: Vector3, m_range: float) -> Vector3:
	var result = damage_ray_with_hit(origin, dir, m_range, 0.0, false)
	return result[1]

func get_all_mob_positions() -> Array[Vector3]:
	var res: Array[Vector3] = []
	for i in range(max_skeletons):
		if alive_flags[i] == 1 and states[i] < State.DEATH:
			res.append(positions[i] + Vector3(0, _foot_offset, 0))
	return res

func get_alive_count() -> int:
	var count = 0
	for i in range(max_skeletons):
		if alive_flags[i] == 1: count += 1
	return count

func _is_targetable(i: int) -> bool:
	return alive_flags[i] != 0 and states[i] != State.DEATH and states[i] != State.DEAD

func take_damage(index: int, amount: float) -> void:
	if index < 0 or index >= max_skeletons: return
	if alive_flags[index] == 0 or states[index] == State.DEATH or states[index] == State.DEAD: return
	hp[index] -= amount
	if hp[index] <= 0.0:
		states[index] = State.DEATH
		anim_timer[index] = 0.0
		AudioManager.play_sceleton_death_3d(positions[index])
		_spawn_exp_orb(index)
	else:
		states[index] = State.HIT
		anim_timer[index] = 0.0
		AudioManager.play_sceleton_hit_3d(positions[index])
	DamageNumberPool.spawn(int(amount), positions[index] + Vector3(0, _foot_offset, 0), false, index)
	AudioManager.play_hitmarker()
	_show_hitmarker()

# ---------- СЕПАРАЦИЯ ----------
func _rebuild_grid():
	_grid.clear()
	for i in range(max_skeletons):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		var cell = Vector2i(
			floori(positions[i].x / grid_size),
			floori(positions[i].z / grid_size)
		)
		if not _grid.has(cell): _grid[cell] = []
		_grid[cell].append(i)

func _update_separation_cache():
	var p_pos: Vector3 = _player.global_position if _player else Vector3.ZERO
	var lod_dist_sq := lod_distance * lod_distance
	for i in range(max_skeletons):
		_sep_cache[i] = Vector3.ZERO
	for i in range(max_skeletons):
		if alive_flags[i] == 0 or states[i] >= State.DEATH: continue
		if _player and positions[i].distance_squared_to(p_pos) > lod_dist_sq:
			continue
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

# ---------- ЛОГИКА ДВИЖЕНИЯ И АТАКИ ----------
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

	for i in range(max_skeletons):
		if alive_flags[i] == 0: continue

		anim_timer[i] += delta

		if states[i] == State.DEATH:
			if anim_timer[i] >= self.anim_duration("death"):
				alive_flags[i] = 0
				free_list.append(i)
			continue

		if states[i] == State.HIT:
			if anim_timer[i] >= self.anim_duration("hit"):
				states[i] = State.WALK
				anim_timer[i] = 0.0
		elif states[i] == State.ATTACK:
			if anim_timer[i] >= self.anim_duration("attack"):
				states[i] = State.WALK
				anim_timer[i] = 0.0

		attack_cd[i] = max(0.0, attack_cd[i] - delta)

		var to_p = p_pos - positions[i]
		to_p.y = 0
		var dist_to_player = to_p.length()

		if states[i] == State.WALK:
			var velocity = Vector3.ZERO
			if dist_to_player > attack_range:
				velocity += to_p.normalized()
			velocity += _get_separation_vector(i) * separation_strength
			var move = velocity.normalized() * move_speed * delta
			positions[i] += move

		if dist_to_player <= attack_range and attack_cd[i] <= 0.0 and states[i] == State.WALK:
			states[i] = State.ATTACK
			attack_cd[i] = attack_interval
			anim_timer[i] = 0.0
			AudioManager.play_sceleton_attack_3d(positions[i])
			if _player.has_method("take_damage"):
				_player.take_damage(attack_damage)

	_draw_all(p_pos)

# ---------- АНИМАЦИИ ----------
func frame_for(anim_name: String, timer: float) -> int:
	var a = _anim_data[anim_name]
	var idx = int(timer * a.fps)
	if a.loop: idx = idx % a.count
	else: idx = min(idx, a.count - 1)
	return a.start + idx

func anim_duration(anim_name: String) -> float:
	var a = _anim_data[anim_name]
	return a.count / a.fps

func _current_anim_name(i: int) -> String:
	match states[i]:
		State.ATTACK: return "attack"
		State.HIT: return "hit"
		State.DEATH: return "death"
		_: return "walk"

# ---------- ОТРИСОВКА ----------
func _draw_all(player_pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else player_pos
	var cull_dist_sq := cull_distance * cull_distance

	for i in range(max_skeletons):
		var base := i * FLOATS_PER_INSTANCE
		var should_draw := false
		if alive_flags[i] == 1:
			if states[i] == State.DEATH:
				should_draw = true
			else:
				var center := positions[i] + Vector3(0, (_foot_offset + ground_offset) * scales[i], 0)
				if cam_pos.distance_squared_to(center) <= cull_dist_sq:
					should_draw = true
		if should_draw:
			var s = scales[i]
			var draw_pos = positions[i] + Vector3(0, (_foot_offset + ground_offset) * s, 0)
			var frame = self.frame_for(_current_anim_name(i), anim_timer[i])
			var color_r = float(frame) / float(FRAME_PATHS.size())
			_mm_buffer[base + 0] = s
			_mm_buffer[base + 1] = 0.0
			_mm_buffer[base + 2] = 0.0
			_mm_buffer[base + 3] = draw_pos.x
			_mm_buffer[base + 4] = 0.0
			_mm_buffer[base + 5] = s
			_mm_buffer[base + 6] = 0.0
			_mm_buffer[base + 7] = draw_pos.y
			_mm_buffer[base + 8] = 0.0
			_mm_buffer[base + 9] = 0.0
			_mm_buffer[base + 10] = s
			_mm_buffer[base + 11] = draw_pos.z
			_mm_buffer[base + 12] = color_r
			_mm_buffer[base + 13] = 0.0
			_mm_buffer[base + 14] = 0.0
			_mm_buffer[base + 15] = 1.0
			_prev_visible[i] = 1
		else:
			if _prev_visible[i] == 1:
				_zero_buffer_slot(base)
				_prev_visible[i] = 0
	multimesh.buffer = _mm_buffer

func _zero_buffer_slot(base: int) -> void:
	for k in range(FLOATS_PER_INSTANCE):
		_mm_buffer[base + k] = 0.0

func _spawn_exp_orb(index: int) -> void:
	if exp_orb_scene == null: return
	if not is_inside_tree(): return
	var orb = exp_orb_scene.instantiate()
	orb.exp_amount = randi_range(exp_drop_min, exp_drop_max)
	get_tree().root.add_child(orb)
	orb.global_position = positions[index] + Vector3(0, 1.0, 0)

func _show_hitmarker() -> void:
	var crosshairs = get_tree().get_nodes_in_group("crosshair")
	if crosshairs.size() > 0:
		crosshairs[0].show_hitmarker()
	else:
		print("⚠️ Crosshair не найден в группе 'crosshair'")

# ==========================================================
# БЛИЖНИЙ БОЙ И АОЕ (для топора и взрывов)
# ==========================================================
func melee_splash(origin: Vector3, atk_range: float, damage: int) -> int:
	var hit_count = 0
	for i in range(max_skeletons):
		if not _is_targetable(i): continue
		var center = positions[i] + Vector3(0, _foot_offset, 0)
		if origin.distance_to(center) <= atk_range:
			take_damage(i, damage)
			hit_count += 1
	return hit_count

func aoe_damage(center: Vector3, radius: float, damage: int) -> int:
	var killed = 0
	for i in range(max_skeletons):
		if not _is_targetable(i): continue
		var center_pos = positions[i] + Vector3(0, _foot_offset, 0)
		if center.distance_to(center_pos) < radius:
			take_damage(i, damage)
			killed += 1
	return killed
