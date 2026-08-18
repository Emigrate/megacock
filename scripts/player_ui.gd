extends Control

@onready var fps_label: Label = $FPS
@onready var hp_label: Label = $HP
@onready var speed_label: Label = $SPEED
@onready var time_label: Label = $TimeLabel
@onready var mob_label: Label = $MobLabel

@export var hp_font_size: int = 55
@export var damage_flash_color: Color = Color.RED
@export var damage_flash_duration: float = 0.7
@export var damage_scale: float = 1.5

var player: Node3D = null
var prev_hp: int = -1
var original_scale: Vector2
var tween: Tween = null

func _ready():
	print("🟢 PlayerUI _ready() STARTED")

	fps_label.text = "FPS: 0"
	hp_label.text = "100"
	speed_label.text = "0"
	time_label.text = "Time: 00:00"
	mob_label.text = "Mobs: 0"
	hp_label.add_theme_font_size_override("font_size", hp_font_size)

	original_scale = hp_label.scale
	hp_label.modulate = Color.WHITE

	_find_player()

func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]
		print("✅ Игрок найден через группу: ", player.name)
		return

	var root = get_tree().current_scene
	if root:
		var found = _find_character_body(root)
		if found:
			player = found
			print("✅ Игрок найден по типу CharacterBody3D!")

func _find_character_body(node: Node) -> Node3D:
	if node is CharacterBody3D and node.has_method("take_damage"):
		return node
	for child in node.get_children():
		var result = _find_character_body(child)
		if result:
			return result
	return null

func _process(_delta):
	fps_label.text = "FPS " + str(Engine.get_frames_per_second())

	if player == null:
		_find_player()
		return

	if not is_instance_valid(player):
		player = null
		return

	var vel = player.get("velocity")
	if vel != null:
		speed_label.text = str(int(vel.length()))
	else:
		speed_label.text = "0"

	var current_hp = player.get("hp")
	if current_hp == null:
		return
	current_hp = int(current_hp)
	hp_label.text = str(current_hp)

	if prev_hp == -1:
		prev_hp = current_hp
		return

	if current_hp < prev_hp:
		print("💥 Урон! HP было ", prev_hp, ", стало ", current_hp)
		_trigger_flash()

	prev_hp = current_hp

	# Таймер забега (ММ:СС) — исправлено деление
	var elapsed_ms = Time.get_ticks_msec()
	var seconds = elapsed_ms / 1000.0          # <-- добавили .0, чтобы было деление с плавающей точкой
	var minutes = int(seconds / 60)
	var remaining_seconds = int(seconds) % 60
	time_label.text = "%02d:%02d" % [minutes, remaining_seconds]

	if Engine.has_singleton("SwarmManager"):
		mob_label.text = "Mobs: " + str(SwarmManager.get_count())
	else:
		mob_label.text = "Mobs: 0"

func _trigger_flash():
	print("🔥 _trigger_flash() ВЫЗВАН")

	if tween:
		tween.kill()
		tween = null

	hp_label.modulate = damage_flash_color
	hp_label.scale = original_scale * damage_scale

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(hp_label, "scale", original_scale, damage_flash_duration)
	tween.tween_property(hp_label, "modulate", Color.WHITE, damage_flash_duration)

	tween.finished.connect(_on_flash_finished)

func _on_flash_finished():
	if is_instance_valid(hp_label):
		hp_label.modulate = Color.WHITE
		hp_label.scale = original_scale
	tween = null
