extends CharacterBody3D

# --- ПАРАМЕТРЫ ---
@export var speed := 3.5
@export var hp := 40
@export var damage := 12.0
@export var attack_cooldown := 0.8
@export var detection_distance := 2.0
@export var rotation_speed := 0.2

var _target: Node3D
var _alive := true
var _animated_sprite: AnimatedSprite3D = null
var _can_attack := true


func _ready() -> void:
	_find_target()
	
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
		
		_animated_sprite.play("walk")
		_animated_sprite.animation_finished.connect(_on_animation_finished)

	# Звук спавна УБРАН


func _find_target() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node3D


func _on_animation_finished() -> void:
	if _animated_sprite == null:
		return
	
	if not _alive:
		if _animated_sprite.animation == "death":
			queue_free()
		return
	
	var current_anim: String = _animated_sprite.animation
	
	if current_anim == "hit":
		_animated_sprite.modulate = Color(1, 1, 1, 1)
		_animated_sprite.play("walk")
	
	if current_anim == "attack":
		_animated_sprite.play("walk")
		_can_attack = true


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	
	if _target == null:
		_find_target()
		if _target == null:
			return

	var dir: Vector3 = (_target.global_position - global_position).normalized()
	var dist: float = global_position.distance_to(_target.global_position)

	if dist > detection_distance * 0.7:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if dist > 0.3:
		var target_angle: float = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed)

	if _animated_sprite and _alive:
		var anim: String = _animated_sprite.animation
		
		if anim == "hit" or anim == "death":
			return
		
		if anim == "attack":
			return
		
		if dist < detection_distance and _can_attack:
			_animated_sprite.play("attack")
			_can_attack = false
			AudioManager.play_sceleton_attack()
			if _target.has_method("take_damage"):
				_target.take_damage(damage)
		else:
			if _animated_sprite.animation != "walk":
				_animated_sprite.play("walk")


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= int(amount)
	
	if hp <= 0:
		_alive = false
		_die()
		return

	AudioManager.play_sceleton_hit()

	if _animated_sprite and _animated_sprite.animation != "death":
		_animated_sprite.modulate = Color.WHITE
		if _animated_sprite.sprite_frames.has_animation("hit"):
			_animated_sprite.play("hit")


func _die() -> void:
	AudioManager.play_sceleton_death()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if _animated_sprite:
		_animated_sprite.play("death")
	else:
		queue_free()
