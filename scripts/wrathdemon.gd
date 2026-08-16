extends CharacterBody3D

# --- Основные параметры ---
@export var speed := 4.0
@export var hp := 30
@export var damage := 15.0

# --- ИНТЕРВАЛЫ АТАКИ (случайный выбор между min и max) ---
@export var min_attack_interval := 2.0
@export var max_attack_interval := 6.0

# --- ВЫСОТА ПОЛЁТА ---
@export var fixed_fly_height := 0.0
@export var fly_height_min := 8.0
@export var fly_height_max := 25.0

# --- Ссылка на фаербол ---
const FIREBALL_SCENE := preload("res://scenes/fireball.tscn")

var _target: Node3D
var _alive := true
var _animated_sprite: AnimatedSprite3D = null
var _can_attack := true
var _hit_timer: float = 0.0
var _is_hit_animating: bool = false
var _fly_height: float = 0.0
var _has_fired := false


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node3D

	for child in get_children():
		if child is AnimatedSprite3D:
			_animated_sprite = child
			break

	if _animated_sprite:
		if _animated_sprite.sprite_frames.has_animation("hit"):
			_animated_sprite.sprite_frames.set_animation_loop("hit", false)
		if _animated_sprite.sprite_frames.has_animation("death"):
			_animated_sprite.sprite_frames.set_animation_loop("death", false)
		if _animated_sprite.sprite_frames.has_animation("attack"):
			_animated_sprite.sprite_frames.set_animation_loop("attack", false)
		
		_animated_sprite.play("fly")
		_animated_sprite.animation_finished.connect(_on_animation_finished)

	if fixed_fly_height > 0:
		_fly_height = fixed_fly_height
	else:
		_fly_height = randf_range(fly_height_min, fly_height_max)
	global_position.y = _fly_height

	AudioManager.play_wrathdemon_spawn()


func _on_animation_finished() -> void:
	if _animated_sprite == null:
		return
	
	if not _alive:
		if _animated_sprite.animation == "death":
			queue_free()
		return
	
	var current_anim = _animated_sprite.animation
	
	if current_anim == "hit":
		_animated_sprite.modulate = Color(1, 1, 1, 1)
		_animated_sprite.play("fly")
		_is_hit_animating = false
	
	if current_anim == "attack":
		_animated_sprite.play("fly")
		_has_fired = false
		# После завершения анимации атаки не сбрасываем _can_attack — таймер уже работает


func _physics_process(delta: float) -> void:
	if not _alive or _target == null:
		return

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

	if dist > 2.0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	var y_diff = _fly_height - global_position.y
	velocity.y = clampf(y_diff * 2.0, -speed, speed)

	move_and_slide()

	if dist > 0.3:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)

	if _animated_sprite and _alive:
		var anim = _animated_sprite.animation
		
		if anim == "attack":
			if not _has_fired:
				if _animated_sprite.get_frame() == 1:
					_fire_fireball()
					_has_fired = true
			return
		
		# Запускаем атаку, если можем
		if _can_attack and _animated_sprite.sprite_frames.has_animation("attack"):
			_can_attack = false
			_has_fired = false
			AudioManager.play_wrathdemon_attack()
			_animated_sprite.play("attack")
			
			# Случайный интервал до следующей атаки (от 2 до 6 секунд)
			var next_interval = randf_range(min_attack_interval, max_attack_interval)
			get_tree().create_timer(next_interval).timeout.connect(func(): 
				_can_attack = true
				print("🔄 Следующая атака через ", next_interval, " сек")
			)


func _fire_fireball() -> void:
	if not _alive or _target == null:
		return
	
	var dir_to_target := (_target.global_position - global_position).normalized()
	var start_pos := global_position + dir_to_target * 1.2
	start_pos.y += 0.5
	
	var fireball = FIREBALL_SCENE.instantiate()
	get_tree().current_scene.add_child(fireball)
	fireball.init(_target, damage, start_pos)
	print("🔥 Фаербол выпущен!")


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= int(amount)
	AudioManager.play_wrathdemon_hit()

	if _animated_sprite and _animated_sprite.animation != "death":
		_animated_sprite.modulate = Color.WHITE
		if _animated_sprite.sprite_frames.has_animation("hit"):
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
		if _animated_sprite.sprite_frames.has_animation("death"):
			_animated_sprite.play("death")
		else:
			queue_free()
			return

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
