extends Node
## Глобальный менеджер звуков (автолоад).

# --- ИМЕНА ШИН ---
const BUS_MASTER = "Master"
const BUS_MOBS = "Mobs"
const BUS_SHOTS = "Shots"
const BUS_EXPLOSIONS = "Explosions"
const BUS_MOB_DEATHS = "MobDeaths"

# --- ЗВУКОВЫЕ РЕСУРСЫ ---
const SHOT_SOUNDS := [
	"res://assets/audio/glock_shot1.wav",
	"res://assets/audio/glock_shot2.wav",
	"res://assets/audio/glock_shot3.wav",
]
const AK_SHOT_SOUNDS := [
	"res://assets/audio/ak-47_shot1.wav",
	"res://assets/audio/ak-47_shot2.wav",
	"res://assets/audio/ak-47_shot3.wav",
]
const STEP_SOUNDS := [
	"res://assets/audio/footstep_1.wav",
	"res://assets/audio/footstep_2.wav",
	"res://assets/audio/footstep_3.wav",
	"res://assets/audio/footstep_4.wav",
]
const DASH_SOUND := "res://assets/audio/dash.wav"
const AXE_SWING_SOUND := "res://assets/audio/axe_swing1.wav"
const SHOTGUN_SHOT_SOUND := "res://assets/audio/shotgun_shot1.wav"

# --- ЗВУКИ ГУЛЯ ---
const GHOUL_SPAWN_SOUND := "res://assets/audio/ghoul_spawn.ogg"
const GHOUL_HIT_SOUND := "res://assets/audio/ghoul_hit.ogg"
const GHOUL_DEATH_SOUND := "res://assets/audio/ghoul_death.ogg"
const GHOUL_SWING_SOUND := "res://assets/audio/ghoul_swing.ogg"

# --- ЗВУКИ ДЕМОНА ---
const WRATHDEMON_SPAWN_SOUND := "res://assets/audio/wrathdemon_spawn.ogg"
const WRATHDEMON_HIT_SOUND := "res://assets/audio/wrathdemon_hit.ogg"
const WRATHDEMON_DIE_SOUND := "res://assets/audio/wrathdemon_die.ogg"
const WRATHDEMON_ATTACK_SOUND := "res://assets/audio/wrathdemon_attack.ogg"

# --- ЗВУКИ СКЕЛЕТА ---
const SCELETON_HIT_SOUND := "res://assets/audio/sceleton_hit.wav"
const SCELETON_DEATH_SOUND := "res://assets/audio/sceleton_death.ogg"
const SCELETON_ATTACK_SOUNDS := [
	"res://assets/audio/sceleton_attack1.ogg",
	"res://assets/audio/sceleton_attack2.ogg",
]

# --- ЗВУКИ ФАЕРБОЛА ---
const FIREBALL_FLY_SOUND := "res://assets/audio/wrathdemon_projectile_fly.ogg"
const FIREBALL_EXPLOSION_SOUND := "res://assets/audio/wrathdemon_projectile_explosion.mp3"

# --- ЗВУКИ ИГРОКА ---
const PLAYER_HURT_SOUNDS := [
	"res://assets/audio/player_hit1.ogg",
	"res://assets/audio/player_hit2.ogg",
	"res://assets/audio/player_hit3.ogg",
]
const PLAYER_DEATH_SOUND := "res://assets/audio/player_death.ogg"

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

# --- ПАРАМЕТРЫ 3D-ЗВУКОВ ---
@export var max_distance_3d := 100.0
@export var unit_size_3d := 90.0
@export var attenuation_model := 2


func _get_camera() -> Camera3D:
	var viewport := get_tree().root.get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


# ============================================================
# 2D-ЗВУКИ (с поддержкой выбора шины)
# ============================================================
func play_random(paths: Array, volume_db := -25.0, bus_name: String = BUS_MASTER) -> void:
	if paths.is_empty():
		return
	var p := AudioStreamPlayer.new()
	var cam := _get_camera()
	if cam:
		cam.add_child(p)
	else:
		get_tree().root.add_child(p)
	var idx := randi() % paths.size()
	p.stream = load(paths[idx]) as AudioStream
	p.pitch_scale = 1.0
	p.volume_db = volume_db + master_volume_db
	p.bus = bus_name
	p.finished.connect(p.queue_free)
	p.play()


func play_single(path: String, volume_db := -25.0, bus_name: String = BUS_MASTER) -> void:
	if path.is_empty():
		return
	var p := AudioStreamPlayer.new()
	var cam := _get_camera()
	if cam:
		cam.add_child(p)
	else:
		get_tree().root.add_child(p)
	p.stream = load(path) as AudioStream
	p.pitch_scale = 1.0
	p.volume_db = volume_db + master_volume_db
	p.bus = bus_name
	p.finished.connect(p.queue_free)
	p.play()


# ============================================================
# ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ 3D-ЗВУКОВ
# ============================================================
func _create_3d_player(stream_path: String, position: Vector3, volume_db: float, bus_name: String = BUS_MASTER) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(stream_path):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = load(stream_path) as AudioStream
	p.pitch_scale = 1.0
	p.volume_db = volume_db + master_volume_db + master_3d_volume_db
	p.max_distance = max_distance_3d
	p.unit_size = unit_size_3d
	@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
	p.attenuation_model = attenuation_model
	p.bus = bus_name
	var world := get_tree().current_scene
	if world:
		world.add_child(p)
	else:
		get_tree().root.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	return p


# ============================================================
# ЗВУКИ ОРУЖИЯ — 2D (без пространства, шина Shots)
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
# ЗВУКИ МОБОВ (3D, шина Mobs) — кроме смерти
# ============================================================
func play_ghoul_spawn_3d(pos: Vector3) -> void:
	var p = _create_3d_player(GHOUL_SPAWN_SOUND, pos, ghoul_spawn_volume_db, BUS_MOBS)
	if p: p.play()

func play_ghoul_hit_3d(pos: Vector3) -> void:
	var p = _create_3d_player(GHOUL_HIT_SOUND, pos, ghoul_hit_volume_db, BUS_MOBS)
	if p: p.play()

func play_ghoul_swing_3d(pos: Vector3) -> void:
	var p = _create_3d_player(GHOUL_SWING_SOUND, pos, ghoul_swing_volume_db, BUS_MOBS)
	if p: p.play()

func play_wrathdemon_spawn_3d(pos: Vector3) -> void:
	var p = _create_3d_player(WRATHDEMON_SPAWN_SOUND, pos, wrathdemon_spawn_volume_db, BUS_MOBS)
	if p: p.play()

func play_wrathdemon_hit_3d(pos: Vector3) -> void:
	var p = _create_3d_player(WRATHDEMON_HIT_SOUND, pos, wrathdemon_hit_volume_db, BUS_MOBS)
	if p: p.play()

func play_wrathdemon_attack_3d(pos: Vector3) -> void:
	var p = _create_3d_player(WRATHDEMON_ATTACK_SOUND, pos, wrathdemon_attack_volume_db, BUS_MOBS)
	if p: p.play()

func play_sceleton_hit_3d(pos: Vector3) -> void:
	var p = _create_3d_player(SCELETON_HIT_SOUND, pos, sceleton_hit_volume_db, BUS_MOBS)
	if p: p.play()

func play_sceleton_attack_3d(pos: Vector3) -> void:
	var p = _create_3d_player(SCELETON_ATTACK_SOUNDS[randi() % SCELETON_ATTACK_SOUNDS.size()], pos, sceleton_attack_volume_db, BUS_MOBS)
	if p: p.play()


# ============================================================
# ЗВУКИ СМЕРТИ МОБОВ (3D, шина MobDeaths)
# ============================================================
func play_ghoul_death_3d(pos: Vector3) -> void:
	var p = _create_3d_player(GHOUL_DEATH_SOUND, pos, ghoul_death_volume_db, BUS_MOB_DEATHS)
	if p: p.play()

func play_wrathdemon_die_3d(pos: Vector3) -> void:
	var p = _create_3d_player(WRATHDEMON_DIE_SOUND, pos, wrathdemon_die_volume_db, BUS_MOB_DEATHS)
	if p: p.play()

func play_sceleton_death_3d(pos: Vector3) -> void:
	var p = _create_3d_player(SCELETON_DEATH_SOUND, pos, sceleton_death_volume_db, BUS_MOB_DEATHS)
	if p: p.play()


# ============================================================
# ЗВУКИ ВЗРЫВОВ (3D, шина Explosions)
# ============================================================
func play_fireball_explosion_3d(pos: Vector3) -> void:
	var p = _create_3d_player(FIREBALL_EXPLOSION_SOUND, pos, fireball_explosion_volume_db, BUS_EXPLOSIONS)
	if p: p.play()

func play_fireball_fly_3d(_pos: Vector3) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(FIREBALL_FLY_SOUND):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = load(FIREBALL_FLY_SOUND)
	p.stream.loop = true
	p.pitch_scale = 1.0
	p.volume_db = fireball_fly_volume_db + master_volume_db + master_3d_volume_db
	p.max_distance = max_distance_3d
	p.unit_size = unit_size_3d
	@warning_ignore("INT_AS_ENUM_WITHOUT_CAST")
	p.attenuation_model = attenuation_model
	p.bus = BUS_EXPLOSIONS
	return p


# ============================================================
# ЗВУКИ ИГРОКА (3D, шина Master — можно оставить, они не обязаны быть 2D)
# ============================================================
func play_player_hurt_3d(pos: Vector3) -> void:
	var p = _create_3d_player(PLAYER_HURT_SOUNDS[randi() % PLAYER_HURT_SOUNDS.size()], pos, player_hurt_volume_db, BUS_MASTER)
	if p: p.play()

func play_player_death_3d(pos: Vector3) -> void:
	var p = _create_3d_player(PLAYER_DEATH_SOUND, pos, player_death_volume_db, BUS_MASTER)
	if p: p.play()


# ============================================================
# 2D-ОБЁРТКИ (для старого кода, оставлены для совместимости)
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
