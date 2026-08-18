extends Node
## Глобальный менеджер звуков (автолоад) с пулом объектов.
## v2: прогрев кэша стримов, free-list пулы (O(1)), ограничение роста пула,
## кэш зацикленного стрима фаербола.

# --- ИМЕНА ШИН ---
const BUS_MASTER = "Master"
const BUS_MOBS = "Mobs"
const BUS_SHOTS = "Shots"
const BUS_EXPLOSIONS = "Explosions"
const BUS_MOB_DEATHS = "MobDeaths"

# --- ЗВУКОВЫЕ РЕСУРСЫ ---
const SHOT_SOUNDS := [
	"res://assets/audio/weapons/glock_shot1.wav",
	"res://assets/audio/weapons/glock_shot2.wav",
	"res://assets/audio/weapons/glock_shot3.wav",
]
const AK_SHOT_SOUNDS := [
	"res://assets/audio/weapons/ak-47_shot1.ogg",
	"res://assets/audio/weapons/ak-47_shot2.ogg",
	"res://assets/audio/weapons/ak-47_shot3.ogg",
]
const STEP_SOUNDS := [
	"res://assets/audio/player/footstep_1.wav",
	"res://assets/audio/player/footstep_2.wav",
	"res://assets/audio/player/footstep_3.wav",
	"res://assets/audio/player/footstep_4.wav",
]
const DASH_SOUND := "res://assets/audio/player/dash.wav"
const AXE_SWING_SOUND := "res://assets/audio/weapons/axe_swing1.wav"
const SHOTGUN_SHOT_SOUND := "res://assets/audio/weapons/shotgun_shot1.wav"

# --- ЗВУКИ ГУЛЯ ---
const GHOUL_SPAWN_SOUND := "res://assets/audio/ghoul/ghoul_spawn.ogg"
const GHOUL_HIT_SOUND := "res://assets/audio/ghoul/ghoul_hit.ogg"
const GHOUL_DEATH_SOUND := "res://assets/audio/ghoul/ghoul_death.ogg"
const GHOUL_SWING_SOUND := "res://assets/audio/ghoul/ghoul_swing.ogg"

# --- ЗВУКИ ДЕМОНА ---
const WRATHDEMON_SPAWN_SOUND := "res://assets/audio/wrathdemon/wrathdemon_spawn.ogg"
const WRATHDEMON_HIT_SOUND := "res://assets/audio/wrathdemon/wrathdemon_hit.ogg"
const WRATHDEMON_DIE_SOUND := "res://assets/audio/wrathdemon/wrathdemon_die.ogg"
const WRATHDEMON_ATTACK_SOUND := "res://assets/audio/wrathdemon/wrathdemon_attack.ogg"

# --- ЗВУКИ СКЕЛЕТА ---
const SCELETON_HIT_SOUND := "res://assets/audio/skeleton/sceleton_hit.wav"
const SCELETON_DEATH_SOUND := "res://assets/audio/skeleton/sceleton_death.ogg"
const SCELETON_ATTACK_SOUNDS := [
	"res://assets/audio/skeleton/sceleton_attack1.ogg",
	"res://assets/audio/skeleton/sceleton_attack2.ogg",
]

# --- ЗВУКИ ФАЕРБОЛА ---
const FIREBALL_FLY_SOUND := "res://assets/audio/wrathdemon/wrathdemon_projectile_fly.ogg"
const FIREBALL_EXPLOSION_SOUND := "res://assets/audio/wrathdemon/wrathdemon_projectile_explosion.mp3"

# --- ЗВУКИ ИГРОКА ---
const PLAYER_HURT_SOUNDS := [
	"res://assets/audio/player/player_hit1.ogg",
	"res://assets/audio/player/player_hit2.ogg",
	"res://assets/audio/player/player_hit3.ogg",
]
const PLAYER_DEATH_SOUND := "res://assets/audio/player/player_death.ogg"

# ===== ЗВУКИ АВТО-ШОТА =====
const PLAYER_AUTOSHOT_SOUNDS := [
	"res://assets/audio/player/player_autoshot1.ogg",
	"res://assets/audio/player/player_autoshot2.ogg",
]

const HITMARKER_SOUND := "res://assets/audio/hitmarker.ogg"

# --- РЕГУЛИРОВКА ГРОМКОСТИ ---
@export var master_volume_db: float = 10
@export var master_3d_volume_db: float = -10.0

# --- ГРОМКОСТЬ ОРУЖИЯ (шина Shots) ---
@export var shot_volume_db: float = -8.0
@export var ak_shot_volume_db: float = -7.0
@export var axe_swing_volume_db: float = -14.0
@export var shotgun_shot_volume_db: float = -3.0

# --- ГРОМКОСТЬ ОКРУЖЕНИЯ (шина Master) ---
@export var step_volume_db: float = -25.0
@export var land_volume_db: float = -25.0
@export var dash_volume_db: float = -25.0

# --- ГРОМКОСТЬ МОБОВ (шина Mobs, кроме смерти) ---
@export var ghoul_spawn_volume_db: float = -5.0
@export var ghoul_hit_volume_db: float = -5.0
@export var ghoul_swing_volume_db: float = -15.0

@export var wrathdemon_spawn_volume_db: float = -5.0
@export var wrathdemon_hit_volume_db: float = 5.0
@export var wrathdemon_attack_volume_db: float = 1.0

@export var sceleton_hit_volume_db: float = 5.0
@export var sceleton_attack_volume_db: float = -15.0

# --- ГРОМКОСТЬ СМЕРТИ МОБОВ (шина MobDeaths) ---
@export var ghoul_death_volume_db: float = -5.0
@export var wrathdemon_die_volume_db: float = -15.0
@export var sceleton_death_volume_db: float = -20.0

# --- ГРОМКОСТЬ ВЗРЫВОВ (шина Explosions) ---
@export var fireball_explosion_volume_db: float = -5.0
@export var fireball_fly_volume_db: float = -10.0

# --- ГРОМКОСТЬ ЗВУКОВ ИГРОКА (шина Master) ---
@export var player_hurt_volume_db: float = -5.0
@export var player_death_volume_db: float = -5.0
@export var hitmarker_volume_db: float = -23.0
@export var autoshot_volume_db: float = -20.0

# --- АНТИ-КЛИППИНГ ДЛЯ ХИТМАРКЕРА ---
@export var hitmarker_min_interval_ms: int = 45
var _last_hitmarker_time_ms: int = 0

# --- АНТИ-КЛИППИНГ ДЛЯ АВТО-ШОТА ---
@export var autoshot_min_interval_ms: int = 150
var _last_autoshot_time_ms: int = 0

# --- АНТИ-КЛИППИНГ ДЛЯ ЗВУКОВ ХИТА МОБОВ ---
@export var mob_hit_min_interval_ms: int = 100
var _last_mob_hit_times: Dictionary = {}

# --- ПУЛЫ ОБЪЕКТОВ ДЛЯ ЗВУКОВ (free-list, O(1) get/release) ---
var _2d_pool: Array[AudioStreamPlayer] = []
var _3d_pool: Array[AudioStreamPlayer3D] = []

# Все когда-либо созданные плееры — нужны для voice stealing при переполнении.
var _2d_all: Array[AudioStreamPlayer] = []
var _3d_all: Array[AudioStreamPlayer3D] = []

# --- ПРОГРЕВ ПУЛА ---
@export var prewarm_2d_count: int = 12
@export var prewarm_3d_count: int = 16

# --- ЖЁСТКИЙ ПОТОЛОК ПУЛА (voice stealing вместо бесконечного роста) ---
@export var max_2d_players: int = 32
@export var max_3d_players: int = 32

# --- ПАРАМЕТРЫ 3D-ЗВУКОВ ---
@export var max_distance_3d := 100.0
@export var unit_size_3d := 90.0
@export var attenuation_model := 2

# --- КЕШ ЗАГРУЖЕННЫХ АУДИО-РЕСУРСОВ (главный фикс проседания FPS) ---
# держим сильную ссылку на каждый стрим постоянно, чтобы load()
# никогда не читал файл с диска повторно во время игры
var _stream_cache: Dictionary = {}

# Закэшированный зацикленный стрим для полёта фаербола (чтобы не
# делать duplicate() при каждом касте).
var _fireball_loop_stream: AudioStream


func _ready() -> void:
	_prewarm_stream_cache()
	_prewarm_pools()


# ============================================================
# ПРОГРЕВ КЭША СТРИМОВ — читаем все файлы с диска один раз, на старте,
# а не в момент первого выстрела/удара посреди геймплея.
# ============================================================
func _prewarm_stream_cache() -> void:
	var all_paths: Array = []
	all_paths.append_array(SHOT_SOUNDS)
	all_paths.append_array(AK_SHOT_SOUNDS)
	all_paths.append_array(STEP_SOUNDS)
	all_paths.append_array(SCELETON_ATTACK_SOUNDS)
	all_paths.append_array(PLAYER_HURT_SOUNDS)
	all_paths.append_array(PLAYER_AUTOSHOT_SOUNDS)
	all_paths.append_array([
		DASH_SOUND, AXE_SWING_SOUND, SHOTGUN_SHOT_SOUND,
		GHOUL_SPAWN_SOUND, GHOUL_HIT_SOUND, GHOUL_DEATH_SOUND, GHOUL_SWING_SOUND,
		WRATHDEMON_SPAWN_SOUND, WRATHDEMON_HIT_SOUND, WRATHDEMON_DIE_SOUND, WRATHDEMON_ATTACK_SOUND,
		SCELETON_HIT_SOUND, SCELETON_DEATH_SOUND,
		FIREBALL_FLY_SOUND, FIREBALL_EXPLOSION_SOUND,
		PLAYER_DEATH_SOUND, HITMARKER_SOUND,
	])

	for path in all_paths:
		_get_stream(path)

	# Готовим зацикленный дубликат стрима полёта фаербола заранее,
	# чтобы play_fireball_fly_3d() не делал duplicate() на каждый каст.
	var base := _get_stream(FIREBALL_FLY_SOUND)
	if base:
		_fireball_loop_stream = base.duplicate()
		_fireball_loop_stream.loop = true


func _prewarm_pools() -> void:
	for i in range(prewarm_2d_count):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_MASTER
		add_child(p)
		p.finished.connect(_release_2d_player.bind(p))
		_2d_pool.append(p)
		_2d_all.append(p)

	for i in range(prewarm_3d_count):
		var p3 := AudioStreamPlayer3D.new()
		p3.max_distance = max_distance_3d
		p3.unit_size = unit_size_3d
		@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
		p3.attenuation_model = attenuation_model
		p3.bus = BUS_MASTER
		add_child(p3)
		p3.finished.connect(_release_3d_player.bind(p3))
		_3d_pool.append(p3)
		_3d_all.append(p3)


func _get_camera() -> Camera3D:
	var viewport := get_tree().root.get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


# ============================================================
# КЕШ АУДИО-РЕСУРСОВ
# ============================================================
func _get_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := load(path) as AudioStream
	if stream:
		_stream_cache[path] = stream
	return stream


# ============================================================
# ВНУТРЕННИЕ ФУНКЦИИ ДЛЯ ПУЛА (2D) — free-list, O(1)
# ============================================================
func _get_2d_player() -> AudioStreamPlayer:
	if not _2d_pool.is_empty():
		return _2d_pool.pop_back()

	# Свободных нет. Если не уперлись в потолок — создаём новый.
	if _2d_all.size() < max_2d_players:
		var p_new := AudioStreamPlayer.new()
		add_child(p_new)
		p_new.finished.connect(_release_2d_player.bind(p_new))
		_2d_all.append(p_new)
		return p_new

	# Уперлись в потолок — крадём голос у самого первого проигрывающего
	# плеера (voice stealing), чтобы не плодить объекты бесконечно.
	for p in _2d_all:
		if p.playing:
			p.stop()
			return p
	# На крайний случай (не должно случаться) — просто первый из всех.
	return _2d_all[0]

func _release_2d_player(p: AudioStreamPlayer) -> void:
	p.stop()
	p.stream = null
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.bus = BUS_MASTER
	if not _2d_pool.has(p):
		_2d_pool.append(p)


# ============================================================
# ВНУТРЕННИЕ ФУНКЦИИ ДЛЯ ПУЛА (3D) — free-list, O(1)
# ============================================================
func _get_3d_player() -> AudioStreamPlayer3D:
	if not _3d_pool.is_empty():
		return _3d_pool.pop_back()

	if _3d_all.size() < max_3d_players:
		var p_new := AudioStreamPlayer3D.new()
		p_new.max_distance = max_distance_3d
		p_new.unit_size = unit_size_3d
		@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
		p_new.attenuation_model = attenuation_model
		add_child(p_new)
		p_new.finished.connect(_release_3d_player.bind(p_new))
		_3d_all.append(p_new)
		return p_new

	for p in _3d_all:
		if p.playing:
			p.stop()
			return p
	return _3d_all[0]

func _release_3d_player(p: AudioStreamPlayer3D) -> void:
	p.stop()
	p.stream = null
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.bus = BUS_MASTER
	p.global_position = Vector3.ZERO
	if not _3d_pool.has(p):
		_3d_pool.append(p)


# ============================================================
# 2D-ЗВУКИ (с поддержкой пула)
# ============================================================
func play_random(paths: Array, volume_db := -25.0, bus_name: String = BUS_MASTER) -> void:
	if paths.is_empty():
		return
	var idx := randi() % paths.size()
	play_single(paths[idx], volume_db, bus_name)

func play_single(path: String, volume_db := -25.0, bus_name: String = BUS_MASTER) -> void:
	var stream := _get_stream(path)
	if stream == null:
		return
	var p := _get_2d_player()
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = volume_db + master_volume_db
	p.bus = bus_name
	p.play()


# ============================================================
# 3D-ЗВУКИ (с поддержкой пула)
# ============================================================
func _play_3d(path: String, position: Vector3, volume_db: float, bus_name: String = BUS_MASTER) -> void:
	var stream := _get_stream(path)
	if stream == null:
		return
	var p := _get_3d_player()
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = volume_db + master_volume_db + master_3d_volume_db
	p.bus = bus_name
	p.global_position = position
	p.play()


# ============================================================
# ЗВУКИ ОРУЖИЯ — 2D (пул уже есть)
# ============================================================
func play_shot_2d() -> void:
	play_random(SHOT_SOUNDS, shot_volume_db, BUS_SHOTS)

func play_ak_shot_2d() -> void:
	play_random(AK_SHOT_SOUNDS, ak_shot_volume_db, BUS_SHOTS)

func play_shotgun_shot_2d() -> void:
	play_single(SHOTGUN_SHOT_SOUND, shotgun_shot_volume_db, BUS_SHOTS)

func play_axe_swing_2d() -> void:
	play_single(AXE_SWING_SOUND, axe_swing_volume_db, BUS_SHOTS)


# ============================================================
# ХИТМАРКЕР (2D, шина Master)
# ============================================================
func play_hitmarker() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hitmarker_time_ms < hitmarker_min_interval_ms:
		return
	_last_hitmarker_time_ms = now
	play_single(HITMARKER_SOUND, hitmarker_volume_db, BUS_MASTER)


# ============================================================
# ЗВУКИ МОБОВ (3D, шина Mobs)
# ============================================================
func _play_mob_hit_limited(sound_path: String, position: Vector3, volume_db: float, sound_key: String) -> void:
	var now := Time.get_ticks_msec()
	var last_time = _last_mob_hit_times.get(sound_key, 0)
	if now - last_time < mob_hit_min_interval_ms:
		return
	_last_mob_hit_times[sound_key] = now
	_play_3d(sound_path, position, volume_db, BUS_MOBS)

func play_ghoul_spawn_3d(pos: Vector3) -> void:
	_play_3d(GHOUL_SPAWN_SOUND, pos, ghoul_spawn_volume_db, BUS_MOBS)

func play_ghoul_hit_3d(pos: Vector3) -> void:
	_play_mob_hit_limited(GHOUL_HIT_SOUND, pos, ghoul_hit_volume_db, "ghoul_hit")

func play_ghoul_swing_3d(pos: Vector3) -> void:
	_play_3d(GHOUL_SWING_SOUND, pos, ghoul_swing_volume_db, BUS_MOBS)

func play_wrathdemon_spawn_3d(pos: Vector3) -> void:
	_play_3d(WRATHDEMON_SPAWN_SOUND, pos, wrathdemon_spawn_volume_db, BUS_MOBS)

func play_wrathdemon_hit_3d(pos: Vector3) -> void:
	_play_mob_hit_limited(WRATHDEMON_HIT_SOUND, pos, wrathdemon_hit_volume_db, "wrathdemon_hit")

func play_wrathdemon_attack_3d(pos: Vector3) -> void:
	_play_3d(WRATHDEMON_ATTACK_SOUND, pos, wrathdemon_attack_volume_db, BUS_MOBS)

func play_sceleton_hit_3d(pos: Vector3) -> void:
	_play_mob_hit_limited(SCELETON_HIT_SOUND, pos, sceleton_hit_volume_db, "sceleton_hit")

func play_sceleton_attack_3d(pos: Vector3) -> void:
	var idx := randi() % SCELETON_ATTACK_SOUNDS.size()
	var stream := _get_stream(SCELETON_ATTACK_SOUNDS[idx])
	if stream == null:
		return
	var p := _get_3d_player()
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = sceleton_attack_volume_db + master_volume_db + master_3d_volume_db
	p.bus = BUS_MOBS
	p.global_position = pos
	p.play()


# ============================================================
# ЗВУКИ СМЕРТИ МОБОВ (3D, шина MobDeaths)
# ============================================================
func play_ghoul_death_3d(pos: Vector3) -> void:
	_play_3d(GHOUL_DEATH_SOUND, pos, ghoul_death_volume_db, BUS_MOB_DEATHS)

func play_wrathdemon_die_3d(pos: Vector3) -> void:
	_play_3d(WRATHDEMON_DIE_SOUND, pos, wrathdemon_die_volume_db, BUS_MOB_DEATHS)

func play_sceleton_death_3d(pos: Vector3) -> void:
	_play_3d(SCELETON_DEATH_SOUND, pos, sceleton_death_volume_db, BUS_MOB_DEATHS)


# ============================================================
# ЗВУКИ ВЗРЫВОВ (3D, шина Explosions)
# ============================================================
func play_fireball_explosion_3d(pos: Vector3) -> void:
	_play_3d(FIREBALL_EXPLOSION_SOUND, pos, fireball_explosion_volume_db, BUS_EXPLOSIONS)


# ============================================================
# ЗВУКИ ИГРОКА (3D, шина Master)
# ============================================================
func play_player_hurt_3d(pos: Vector3) -> void:
	var idx := randi() % PLAYER_HURT_SOUNDS.size()
	_play_3d(PLAYER_HURT_SOUNDS[idx], pos, player_hurt_volume_db, BUS_MASTER)

func play_player_death_3d(pos: Vector3) -> void:
	_play_3d(PLAYER_DEATH_SOUND, pos, player_death_volume_db, BUS_MASTER)


# ============================================================
# ЗВУК АВТО-ШОТА (2D, шина Master, с защитой и пулом)
# ============================================================
func play_player_autoshot_2d() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_autoshot_time_ms < autoshot_min_interval_ms:
		return
	_last_autoshot_time_ms = now

	var idx := randi() % PLAYER_AUTOSHOT_SOUNDS.size()
	var stream := _get_stream(PLAYER_AUTOSHOT_SOUNDS[idx])
	if stream == null:
		return
	var p := _get_2d_player()
	p.stream = stream
	p.pitch_scale = randf_range(0.95, 1.05)
	p.volume_db = autoshot_volume_db + master_volume_db
	p.bus = BUS_MASTER
	p.play()


# ============================================================
# ФАЕРБОЛ (3D, шина Explosions, отдельный не-пуловый плеер — им
# управляет сам фаербол-объект, поэтому пул тут не подходит).
# Стрим для зацикливания теперь берём из кэша _fireball_loop_stream,
# посчитанного один раз при старте, а не duplicate() на каждый вызов.
# ============================================================
func play_fireball_fly_3d(_pos: Vector3) -> AudioStreamPlayer3D:
	if _fireball_loop_stream == null:
		# fallback на случай, если ресурс появился уже после _ready()
		if not ResourceLoader.exists(FIREBALL_FLY_SOUND):
			return null
		var base_stream := _get_stream(FIREBALL_FLY_SOUND)
		if base_stream == null:
			return null
		_fireball_loop_stream = base_stream.duplicate()
		_fireball_loop_stream.loop = true

	var p := AudioStreamPlayer3D.new()
	p.max_distance = max_distance_3d
	p.unit_size = unit_size_3d
	@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
	p.attenuation_model = attenuation_model
	p.stream = _fireball_loop_stream
	p.pitch_scale = 1.0
	p.volume_db = fireball_fly_volume_db + master_volume_db + master_3d_volume_db
	p.bus = BUS_EXPLOSIONS
	# Возвращаем плеер без родителя — фаербол сам добавит его как дочерний.
	return p


# ============================================================
# 2D-ОБЁРТКИ (для старого кода, но теперь с пулом и кешем)
# ============================================================
func play_step() -> void: play_random(STEP_SOUNDS, step_volume_db)
func play_land() -> void: play_random(STEP_SOUNDS, land_volume_db)
func play_shot() -> void: play_random(SHOT_SOUNDS, shot_volume_db)
func play_ak_shot() -> void: play_random(AK_SHOT_SOUNDS, ak_shot_volume_db)
func play_dash() -> void: play_single(DASH_SOUND, dash_volume_db)
func play_axe_swing() -> void: play_single(AXE_SWING_SOUND, axe_swing_volume_db)
func play_shotgun_shot() -> void: play_single(SHOTGUN_SHOT_SOUND, shotgun_shot_volume_db)
func play_ghoul_spawn() -> void: play_single(GHOUL_SPAWN_SOUND, ghoul_spawn_volume_db)
func play_ghoul_hit() -> void: play_single(GHOUL_HIT_SOUND, ghoul_hit_volume_db)
func play_ghoul_death() -> void: play_single(GHOUL_DEATH_SOUND, ghoul_death_volume_db)
func play_ghoul_swing() -> void: play_single(GHOUL_SWING_SOUND, ghoul_swing_volume_db)
func play_wrathdemon_spawn() -> void: play_single(WRATHDEMON_SPAWN_SOUND, wrathdemon_spawn_volume_db)
func play_wrathdemon_hit() -> void: play_single(WRATHDEMON_HIT_SOUND, wrathdemon_hit_volume_db)
func play_wrathdemon_die() -> void: play_single(WRATHDEMON_DIE_SOUND, wrathdemon_die_volume_db)
func play_wrathdemon_attack() -> void: play_single(WRATHDEMON_ATTACK_SOUND, wrathdemon_attack_volume_db)
func play_sceleton_hit() -> void: play_single(SCELETON_HIT_SOUND, sceleton_hit_volume_db)
func play_sceleton_death() -> void: play_single(SCELETON_DEATH_SOUND, sceleton_death_volume_db)
func play_sceleton_attack() -> void: play_random(SCELETON_ATTACK_SOUNDS, sceleton_attack_volume_db)
