extends Node
## Глобальный менеджер звуков (автолоад).

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

const HYDRA_DIE_SOUNDS := [
	"res://assets/audio/hydra_die1.wav",
	"res://assets/audio/hydra_die2.wav",
	"res://assets/audio/hydra_die3.wav",
]

# --- ЗВУКИ ДЕМОНА ---
const WRATHDEMON_SPAWN_SOUND := "res://assets/audio/wrathdemon_spawn.ogg"
const WRATHDEMON_HIT_SOUND := "res://assets/audio/wrathdemon_hit.ogg"
const WRATHDEMON_DIE_SOUND := "res://assets/audio/wrathdemon_die.ogg"

# --- ЗВУКИ ГУЛЯ ---
const GHOUL_SPAWN_SOUND := "res://assets/audio/ghoul_spawn.ogg"
const GHOUL_HIT_SOUND := "res://assets/audio/ghoul_hit.ogg"
const GHOUL_DEATH_SOUND := "res://assets/audio/ghoul_death.ogg"
const GHOUL_SWING_SOUND := "res://assets/audio/ghoul_swing.ogg"

# --- РЕГУЛИРОВКА ГРОМКОСТИ (в дБ) ---
@export var master_volume_db: float = 0.0
@export var shot_volume_db: float = -15.0
@export var ak_shot_volume_db: float = 0.0
@export var step_volume_db: float = -25.0
@export var land_volume_db: float = -25.0
@export var dash_volume_db: float = -25.0
@export var axe_swing_volume_db: float = -14.0
@export var hydra_die_volume_db: float = -20.0
@export var shotgun_shot_volume_db: float = -13.0

# --- ГРОМКОСТЬ ДЕМОНА ---
@export var wrathdemon_spawn_volume_db: float = -40.0
@export var wrathdemon_hit_volume_db: float = -10.0
@export var wrathdemon_die_volume_db: float = -30.0

# --- ГРОМКОСТЬ ГУЛЯ ---
@export var ghoul_spawn_volume_db: float = -20.0
@export var ghoul_hit_volume_db: float = -20.0
@export var ghoul_death_volume_db: float = -20.0
@export var ghoul_swing_volume_db: float = -20.0


func _get_camera() -> Camera3D:
	var viewport := get_tree().root.get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


func play_random(paths: Array, volume_db := -25.0) -> void:
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
	p.finished.connect(p.queue_free)
	p.play()


func play_single(path: String, volume_db := -25.0) -> void:
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
	p.finished.connect(p.queue_free)
	p.play()


func play_step() -> void:
	play_random(STEP_SOUNDS, step_volume_db)


func play_land() -> void:
	play_random(STEP_SOUNDS, land_volume_db)


func play_shot() -> void:
	play_random(SHOT_SOUNDS, shot_volume_db)


func play_ak_shot() -> void:
	play_random(AK_SHOT_SOUNDS, ak_shot_volume_db)


func play_dash() -> void:
	play_single(DASH_SOUND, dash_volume_db)


func play_axe_swing() -> void:
	play_single(AXE_SWING_SOUND, axe_swing_volume_db)


func play_hydra_die() -> void:
	play_random(HYDRA_DIE_SOUNDS, hydra_die_volume_db)


func play_shotgun_shot() -> void:
	play_single(SHOTGUN_SHOT_SOUND, shotgun_shot_volume_db)


# --- ЗВУКИ ДЕМОНА ---
func play_wrathdemon_spawn() -> void:
	play_single(WRATHDEMON_SPAWN_SOUND, wrathdemon_spawn_volume_db)


func play_wrathdemon_hit() -> void:
	play_single(WRATHDEMON_HIT_SOUND, wrathdemon_hit_volume_db)


func play_wrathdemon_die() -> void:
	play_single(WRATHDEMON_DIE_SOUND, wrathdemon_die_volume_db)


# --- ЗВУКИ ГУЛЯ ---
func play_ghoul_spawn() -> void:
	play_single(GHOUL_SPAWN_SOUND, ghoul_spawn_volume_db)


func play_ghoul_hit() -> void:
	play_single(GHOUL_HIT_SOUND, ghoul_hit_volume_db)


func play_ghoul_death() -> void:
	play_single(GHOUL_DEATH_SOUND, ghoul_death_volume_db)


func play_ghoul_swing() -> void:
	play_single(GHOUL_SWING_SOUND, ghoul_swing_volume_db)
