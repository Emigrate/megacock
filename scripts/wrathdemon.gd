extends CharacterBody3D

# --- Основные параметры ---
@export var speed := 4.0
@export var hp := 30
@export var damage := 15.0
@export var attack_cooldown := 1.0

# --- ВЫСОТА ПОЛЁТА (если 0 — случайная в диапазоне min/max) ---
@export var fixed_fly_height := 0.0          # если >0, демон будет летать строго на этой высоте
@export var fly_height_min := 8.0            # минимальная высота при случайном выборе (метров)
@export var fly_height_max := 25.0           # максимальная высота при случайном выборе (метров)

var _target: Node3D
var _alive := true
var _animated_sprite: AnimatedSprite3D = null
var _can_attack := true
var _hit_timer: float = 0.0
var _is_hit_animating: bool = false
var _fly_height: float = 0.0


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node3D

	for child in get_children():
		if child is AnimatedSprite3D:
			_animated_sprite = child
			break

	if _animated_sprite:
		_animated_sprite.play("fly")

	# --- ЗАДАЁМ ВЫСОТУ ПОЛЁТА ---
	if fixed_fly_height > 0:
		_fly_height = fixed_fly_height
	else:
		_fly_height = randf_range(fly_height_min, fly_height_max)

	# Поднимаем демона на высоту
	global_position.y = _fly_height

	AudioManager.play_wrathdemon_spawn()


func _physics_process(delta: float) -> void:
	if not _alive or _target == null:
		return

	# --- ОБРАБОТКА АНИМАЦИИ HIT ---
	if _is_hit_animating:
		_hit_timer += delta
		if _hit_timer >= 0.3:
			_is_hit_animating = false
			_hit_timer = 0.0
			if _animated_sprite and _alive:
				_animated_sprite.modulate = Color(1, 1, 1, 1)
				_animated_sprite.play("fly")
		return

	var dir := (_target.global_position - global_position).normalized()
	var dist := global_position.distance_to(_target.global_position)

	# --- ДВИЖЕНИЕ К ИГРОКУ (по горизонтали) ---
	if dist > 2.0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# --- ПОДДЕРЖИВАЕМ ВЫСОТУ ПОЛЁТА ---
	var y_diff = _fly_height - global_position.y
	velocity.y = clampf(y_diff * 2.0, -speed, speed)

	move_and_slide()

	# --- ПОВОРОТ В СТОРОНУ ИГРОКА ---
	if dist > 0.3:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)

	# --- АТАКА (ближний бой) ---
	if dist < 2.5 and _can_attack:
		if _target.has_method("take_damage"):
			_target.take_damage(damage)
			_can_attack = false
			get_tree().create_timer(attack_cooldown).timeout.connect(func(): _can_attack = true)

	# --- АНИМАЦИИ ---
	if _animated_sprite and _alive:
		if dist > 2.0:
			if _animated_sprite.animation != "fly":
				_animated_sprite.play("fly")
		else:
			if _animated_sprite.animation != "attack":
				_animated_sprite.play("attack")


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= int(amount)
	AudioManager.play_wrathdemon_hit()

	if _animated_sprite:
		_animated_sprite.modulate = Color.WHITE
		_animated_sprite.play("hit")
		_is_hit_animating = true
		_hit_timer = 0.0

	if hp <= 0:
		_alive = false
		_die()


func _die() -> void:
	AudioManager.play_wrathdemon_die()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if _animated_sprite:
		_animated_sprite.stop()
		_animated_sprite.play("death")

	var tween = create_tween()
	tween.set_parallel(true)

	if _animated_sprite:
		var death_frames = _animated_sprite.sprite_frames.get_frame_count("death")
		var death_duration = death_frames / 10.0
		tween.tween_property(_animated_sprite, "modulate", Color(1, 1, 1, 0), death_duration)
		tween.tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), death_duration)
		tween.tween_property(self, "global_position:y", global_position.y - 1.0, death_duration)

	await tween.finished
	queue_free()
