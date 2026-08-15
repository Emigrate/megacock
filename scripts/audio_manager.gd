extends Node
## Глобальный менеджер звуков (автолоад "AudioManager").
## Все звуки спавнятся как дети активной камеры — всегда слышно чётко.

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

# --- НОВЫЙ МАССИВ ДЛЯ СМЕРТИ ГИДРЫ ---
const HYDRA_DIE_SOUNDS := [
	"res://assets/audio/hydra_die1.wav",
	"res://assets/audio/hydra_die2.wav",
	"res://assets/audio/hydra_die3.wav",
]

# --- РЕГУЛИРОВКА ГРОМКОСТИ (в дБ) ---
@export var master_volume_db: float = 0.0
@export var shot_volume_db: float = -20.0
@export var ak_shot_volume_db: float = -13.0
@export var step_volume_db: float = -25.0
@export var land_volume_db: float = -25.0
@export var dash_volume_db: float = -25.0
@export var axe_swing_volume_db: float = -14.0
@export var hydra_die_volume_db: float = -20.0


func _get_camera() -> Camera3D:
	var viewport := get_tree().root.get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


func play_random(paths: Array, volume_db := -25.0, pitch_min := 0.9, pitch_max := 1.1) -> void:
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
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.volume_db = volume_db + master_volume_db
	p.finished.connect(p.queue_free)
	p.play()


func play_single(path: String, volume_db := -25.0, pitch_min := 1.0, pitch_max := 1.0) -> void:
	if path.is_empty():
		return

	var p := AudioStreamPlayer.new()

	var cam := _get_camera()
	if cam:
		cam.add_child(p)
	else:
		get_tree().root.add_child(p)

	p.stream = load(path) as AudioStream
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.volume_db = volume_db + master_volume_db
	p.finished.connect(p.queue_free)
	p.play()


func play_step() -> void:
	play_random(STEP_SOUNDS, step_volume_db, 0.9, 1.1)


func play_land() -> void:
	play_random(STEP_SOUNDS, land_volume_db, 0.9, 1.0)


func play_shot() -> void:
	play_random(SHOT_SOUNDS, shot_volume_db, 0.95, 1.05)


func play_ak_shot() -> void:
	play_random(AK_SHOT_SOUNDS, ak_shot_volume_db, 0.95, 1.05)


func play_dash() -> void:
	play_single(DASH_SOUND, dash_volume_db, 0.95, 1.05)


func play_axe_swing() -> void:
	play_single(AXE_SWING_SOUND, axe_swing_volume_db)


func play_hydra_die() -> void:   # старый метод, можно оставить для совместимости
	play_random(HYDRA_DIE_SOUNDS, hydra_die_volume_db, 0.9, 1.1)
