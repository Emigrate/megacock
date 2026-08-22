extends Node3D
class_name BeholderSwarm

# ===== СТАТИЧЕСКИЕ ДАННЫЕ ТЕКСТУР =====
const FRAME_PATHS := [
	"res://assets/textures/beholder/beholder_fly1.png",
	"res://assets/textures/beholder/beholder_fly2.png",
	"res://assets/textures/beholder/beholder_fly3.png",
	"res://assets/textures/beholder/beholder_fly4.png",
	"res://assets/textures/beholder/beholder_death.png",   # death1
	"res://assets/textures/beholder/beholder_death2.png",  # death2
	"res://assets/textures/beholder/beholder_death3.png",  # death3 -> после него взрыв
]

const ANIM_BASE := {
	"fly":   {"start": 0, "count": 4, "fps": 8.0,  "loop": true},
	"death": {"start": 4, "count": 3, "fps": 10.0, "loop": false},
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

@export var max_beholders := 300
@export var mesh_size := Vector2(3, 3)
@export var move_speed := 7.0
@export var initial_hp := 15.0

# --- КАМИКАДЗЕ / ВЗРЫВ ---
@export var contact_range := 5.0          # на каком расстоянии сам взрывается об игрока
@export var explosion_radius := 20     # радиус урона от взрыва
@export var explosion_damage := 50        # урон игроку от взрыва
@export var explosion_mob_damage_mult := 0.5  # мобы получают в 2 раза меньше (0.5 = половина)
@export var explosion_scene: PackedScene  # сюда кидаешь свою explosion.tscn

# --- НОКБЭК ОТ ВЗРЫВА БЕХОЛДЕРА (для мобов, которых он задевает) ---
@export var explosion_knockback_force := 20.0    # сила отброса -> больше = дальше
@export var explosion_knockback_up_ratio := 0.6  # доля силы вверх -> больше = выше

# --- ВЫСОТА ПОЛЁТА (низко над землёй, НЕ привязано к игроку) ---
@export var ground_y := 0.0   # уровень земли, синхронизируй с GROUND_Y из MobSpawn
@export var fly_height_min := 3.0
@export var fly_height_max := 5.0
@export var bob_speed := 3.0
@export var bob_amount := 0.3

# --- РАСТАЛКИВАНИЕ (чтоб не слипались в кучу) ---
@export var separation_dist := 2.5
@export var separation_strength := 1.0
@export var grid_size := 3.0

# --- ОПТИМИЗАЦИЯ ---
@export var grid_rebuild_interval := 0.1
@export var separation_update_interval := 0.15
@export var cull_distance := 1000.0

# ===== КРУТИЛКИ СКОРОСТИ АНИМАЦИИ =====
@export var fly_anim_speed: float = 1.0
@export var death_anim_speed: float = 2
# =================================================

const MAX_NEIGHBORS_PER_CELL := 12
const MAX_CHECKED_NEIGHBORS := 15
const FLOATS_PER_INSTANCE := 16

enum State { FLY, DEATH, DEAD }

var multimesh: MultiMesh
var positions: PackedVector3Array
var hp: PackedFloat32Array
var states: PackedInt32Array
var anim_timer: PackedFloat32Array
var alive_flags: PackedByteArray
var scales: PackedFloat32Array
var bob_offset: PackedFloat32Array   # рандомный фазовый сдвиг покачивания
var exploded_flags: PackedByteArray  # чтоб взрыв не заспавнился дважды
var free_list: Array[int] = []

var _grid: Dictionary = {}
var _grid_timer := 0.0
var _sep_timer := 0.0
var _player: Node3D

var _sep_cache: PackedVector3Array = []
var _mm_buffer: PackedFloat32Array = []
var _prev_visible: PackedByteArray = []

var _anim_data: Dictionary = {}

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(SwarmManager):
		SwarmManager.set_beholder_swarm(self)
	_setup_arrays()
	_setup_multimesh()
	_sep_cache.resize(max_beholders)
	_init_anim_data()

func _init_anim_data() -> void:
	_anim_data = {}
	for anim in ANIM_BASE:
		var base = ANIM_BASE[anim]
		var speed = 1.0
		match anim:
			"fly": speed = fly_anim_speed
			"death": speed = death_anim_speed
		_anim_data[anim] = {
			"start": base.start,
			"count": base.count,
			"fps": base.fps * speed,
			"loop": base.loop
		}

func _setup_arrays() -> void:
	positions.resize(max_beholders)
	hp.resize(max_beholders)
	states.resize(max_beholders)
	anim_timer.resize(max_beholders)
	alive_flags.resize(max_beholders)
	scales.resize(max_beholders)
	bob_offset.resize(max_beholders)
	exploded_flags.resize(max_beholders)
	for i in range(max_beholders):
		alive_flags[i] = 0
		free_list.append(max_beholders - 1 - i)

func _setup_multimesh() -> void:
	var quad = QuadMesh.new()
	quad.size = mesh_size
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/mob_billboard.gdshader")
	mat.set_shader_parameter("tex_array", texture_array)
	mat.set_shader_parameter("frame_count", float(FRAME_PATHS.size()))  # 7 кадров, не дефолтные 15!

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = max_beholders
	multimesh.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = multimesh
	mmi.material_override = mat
	add_child(mmi)

	_mm_buffer.resize(max_beholders * FLOATS_PER_INSTANCE)
	_mm_buffer.fill(0.0)
	multimesh.buffer = _mm_buffer

	_prev_visible.resize(max_beholders)
	_prev_visible.fill(0)

func spawn(pos: Vector3) -> void:
	if free_list.is_empty(): return
	var i = free_list.pop_back()
	positions[i] = pos
	hp[i] = initial_hp
	states[i] = State.FLY
	anim_timer[i] = 0.0
	alive_flags[i] = 1
	scales[i] = randf_range(0.9, 1.1)
	bob_offset[i] = randf_range(0.0, TAU)
	exploded_flags[i] = 0

# ---------- БОЕВЫЕ ФУНКЦИИ ----------

func damage_ray_with_hit(origin: Vector3, dir: Vector3, m_range: float, dmg: float) -> Array:
	var best_dist = m_range
	var best_i = -1
	var best_center = origin + dir * m_range
	for i in range(max_beholders):
		if alive_flags[i] == 0 or states[i] != State.FLY: continue
		var center = positions[i]
		var to_mob = center - origin
		var proj = to_mob.dot(dir)
		if proj < 0 or proj > m_range: continue
		var closest = origin + dir * proj
		if closest.distance_to(center) < 2.5 and proj < best_dist:
			best_dist = proj
			best_i = i
			best_center = closest
	if best_i != -1:
		hp[best_i] -= dmg
		if hp[best_i] <= 0:
			_start_death(best_i)
		DamageNumberPool.spawn(int(dmg), positions[best_i], false, best_i)
		AudioManager.play_hitmarker()
		_show_hitmarker()
		return [true, best_center]
	return [false, Vector3.ZERO]

func damage_ray(origin: Vector3, dir: Vector3, m_range: float, dmg: float) -> bool:
	return damage_ray_with_hit(origin, dir, m_range, dmg)[0]

func get_hit_position(origin: Vector3, dir: Vector3, m_range: float) -> Vector3:
	return damage_ray_with_hit(origin, dir, m_range, 0.0)[1]

func take_damage(index: int, amount: float) -> void:
	if index < 0 or index >= max_beholders: return
	if alive_flags[index] == 0 or states[index] != State.FLY: return
	hp[index] -= amount
	if hp[index] <= 0.0:
		_start_death(index)
	DamageNumberPool.spawn(int(amount), positions[index], false, index)
	AudioManager.play_hitmarker()
	_show_hitmarker()

func _start_death(i: int) -> void:
	states[i] = State.DEATH
	anim_timer[i] = 0.0
	exploded_flags[i] = 0

func get_all_mob_positions() -> Array[Vector3]:
	var res: Array[Vector3] = []
	for i in range(max_beholders):
		if alive_flags[i] == 1 and states[i] == State.FLY:
			res.append(positions[i])
	return res

func get_alive_count() -> int:
	var count = 0
	for i in range(max_beholders):
		if alive_flags[i] == 1: count += 1
	return count

func melee_splash(origin: Vector3, atk_range: float, damage: int) -> int:
	var hit_count = 0
	for i in range(max_beholders):
		if alive_flags[i] == 0 or states[i] != State.FLY: continue
		if origin.distance_to(positions[i]) <= atk_range:
			take_damage(i, damage)
			hit_count += 1
	return hit_count

func aoe_damage(center: Vector3, radius: float, damage: int) -> int:
	var killed = 0
	for i in range(max_beholders):
		if alive_flags[i] == 0 or states[i] != State.FLY: continue
		if center.distance_to(positions[i]) < radius:
			take_damage(i, damage)
			killed += 1
	return killed

func clear_all() -> void:
	for i in range(max_beholders):
		if alive_flags[i] == 1:
			alive_flags[i] = 0
			free_list.append(i)

# ---------- РАСТАЛКИВАНИЕ ----------
func _rebuild_grid():
	_grid.clear()
	for i in range(max_beholders):
		if alive_flags[i] == 0 or states[i] != State.FLY: continue
		var cell = Vector2i(floori(positions[i].x / grid_size), floori(positions[i].z / grid_size))
		if not _grid.has(cell):
			_grid[cell] = []
		var bucket: Array = _grid[cell]
		if bucket.size() < MAX_NEIGHBORS_PER_CELL:
			bucket.append(i)

func _update_separation_cache():
	for i in range(max_beholders):
		_sep_cache[i] = Vector3.ZERO

	for i in range(max_beholders):
		if alive_flags[i] == 0 or states[i] != State.FLY: continue
		var pos = positions[i]
		var base_cell = Vector2i(floori(pos.x / grid_size), floori(pos.z / grid_size))
		var push = Vector3.ZERO
		var checked := 0
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cell = base_cell + Vector2i(dx, dz)
				if not _grid.has(cell): continue
				for other_idx in _grid[cell]:
					if other_idx == i: continue
					var diff = pos - positions[other_idx]
					var dist = diff.length()
					if dist < separation_dist and dist > 0.01:
						push += (diff / dist) * (separation_dist - dist)
					checked += 1
					if checked >= MAX_CHECKED_NEIGHBORS: break
				if checked >= MAX_CHECKED_NEIGHBORS: break
			if checked >= MAX_CHECKED_NEIGHBORS: break
		_sep_cache[i] = push

# ---------- ОСНОВНОЙ ЦИКЛ ----------
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

	for i in range(max_beholders):
		if alive_flags[i] == 0: continue

		anim_timer[i] += delta

		if states[i] == State.DEATH:
			# ===== ВЗРЫВ ПОСЛЕ ПОЛНОЙ АНИМАЦИИ СМЕРТИ (3 кадра) =====
			if anim_timer[i] >= self.anim_duration("death"):
				if exploded_flags[i] == 0:
					_trigger_explosion(i)
					exploded_flags[i] = 1
				alive_flags[i] = 0
				free_list.append(i)
			continue

		# --- FLY: летим к игроку низко над землёй ---
		var to_p = p_pos - positions[i]
		var dist_xz = Vector2(to_p.x, to_p.z).length()

		if dist_xz <= contact_range:
			_start_death(i)
			continue

		var dir_xz = Vector3(to_p.x, 0, to_p.z).normalized()
		var velocity = dir_xz + _sep_cache[i] * separation_strength
		positions[i] += velocity.normalized() * move_speed * delta

		# высота: над землёй (НЕ над игроком!) + покачивание
		var target_h = lerp(fly_height_min, fly_height_max, sin(bob_offset[i]) * 0.5 + 0.5)
		var bob = sin((Time.get_ticks_msec() / 1000.0) * bob_speed + bob_offset[i]) * bob_amount
		positions[i].y = ground_y + target_h + bob

	_draw_all(p_pos)

func _trigger_explosion(i: int) -> void:
	var pos = positions[i]
	AudioManager.play_ghoul_death_3d(pos)  # можешь завести отдельный звук взрыва бехолдера

	# ===== УРОН МОБАМ (в 2 раза меньше, чем игроку) + НОКБЭК =====
	var mob_damage = int(explosion_damage * explosion_mob_damage_mult)
	SwarmManager.aoe_damage(pos, explosion_radius, mob_damage, explosion_knockback_force, explosion_knockback_up_ratio)

	# ===== УРОН ИГРОКУ =====
	if _player and _player.has_method("take_damage"):
		var dist_to_player = pos.distance_to(_player.global_position)
		if dist_to_player <= explosion_radius:
			_player.take_damage(explosion_damage)

	if explosion_scene:
		var fx = explosion_scene.instantiate()
		get_tree().root.add_child(fx)
		fx.global_position = pos

# ---------- АНИМАЦИЯ ----------
func frame_for(anim_name: String, timer: float) -> int:
	var a = _anim_data[anim_name]
	var idx = int(timer * a.fps)
	if a.loop:
		idx = idx % a.count
	else:
		idx = min(idx, a.count - 1)
	return a.start + idx

func anim_duration(anim_name: String) -> float:
	var a = _anim_data[anim_name]
	return a.count / a.fps

func _current_anim_name(i: int) -> String:
	return "death" if states[i] == State.DEATH else "fly"

# ---------- ОТРИСОВКА ----------
func _draw_all(player_pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else player_pos
	var cull_dist_sq := cull_distance * cull_distance

	for i in range(max_beholders):
		var base := i * FLOATS_PER_INSTANCE
		var should_draw := false

		if alive_flags[i] == 1:
			if cam_pos.distance_squared_to(positions[i]) <= cull_dist_sq:
				should_draw = true

		if should_draw:
			var s = scales[i]
			var draw_pos = positions[i]
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

func _show_hitmarker() -> void:
	var crosshairs = get_tree().get_nodes_in_group("crosshair")
	if crosshairs.size() > 0:
		crosshairs[0].show_hitmarker()
	else:
		print("⚠️ Crosshair не найден в группе 'crosshair'")
