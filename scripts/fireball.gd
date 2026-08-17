extends CharacterBody3D

@export var speed := 55.0
@export var damage := 15.0
@export var hp := 2
@export var explosion_radius := 5.0
@export var max_distance := 500.0

var _start_pos: Vector3
var _dir: Vector3
var _target: Node3D
var _exploded := false
var _current_hp: int
var _fly_sound: AudioStreamPlayer3D = null

@onready var anim_sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	anim_sprite.sprite_frames.set_animation_loop("explosion", false)


func init(target: Node3D, dmg: float, start_pos: Vector3) -> void:
	_target = target
	damage = dmg
	_start_pos = start_pos
	_current_hp = hp
	if _target:
		_dir = (_target.global_position - start_pos).normalized()
		global_position = start_pos
		look_at(start_pos + _dir, Vector3.UP)
		anim_sprite.play("fly")
	
	# --- ЗАПУСКАЕМ ЗВУК ПОЛЁТА ---
	_fly_sound = AudioManager.play_fireball_fly_3d(global_position)
	if _fly_sound:
		add_child(_fly_sound)            # добавляем в сцену (становится дочерним фаербола)
		_fly_sound.global_position = global_position  # теперь можно ставить позицию
		_fly_sound.play()                # и запускаем воспроизведение (цикличное)
	
	SwarmManager.register_fireball(self)


func _physics_process(_delta: float) -> void:
	if _exploded:
		return
	if _dir == Vector3.ZERO:
		return
	
	velocity = _dir * speed
	move_and_slide()
	
	if global_position.distance_to(_start_pos) > max_distance:
		_explode()
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(damage)
		_explode()
		return


func take_damage(dmg: float) -> void:
	if _exploded:
		return
	_current_hp -= int(dmg)
	if _current_hp <= 0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	velocity = Vector3.ZERO
	
	# --- ОСТАНАВЛИВАЕМ ЗВУК ПОЛЁТА ---
	if _fly_sound and is_instance_valid(_fly_sound):
		_fly_sound.stop()
		_fly_sound.queue_free()
	
	# --- ЗВУК ВЗРЫВА ---
	AudioManager.play_fireball_explosion_3d(global_position)
	
	SwarmManager.unregister_fireball(self)
	anim_sprite.play("explosion")
	# Если не нужен AoE урон — закомментируй следующую строку
	# SwarmManager.aoe_damage(global_position, explosion_radius, 20)
	anim_sprite.animation_finished.connect(_on_explosion_finished)


func _on_explosion_finished() -> void:
	if anim_sprite.animation == "explosion":
		queue_free()


func is_exploded() -> bool:
	return _exploded
