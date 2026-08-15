extends CharacterBody3D

@export var speed := 4.0
@export var hp := 50
@export var damage := 10.0

var _target: Node3D
var _alive := true
var _animated_sprite: AnimatedSprite3D = null


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node3D
	else:
		for node in get_tree().get_nodes_in_group(""):
			if node is CharacterBody3D:
				_target = node as Node3D
				break
	if _target:
		print("✅ Моб нашёл игрока: ", _target.name)
	else:
		print("❌ Моб НЕ нашёл игрока!")

	for child in get_children():
		if child is AnimatedSprite3D:
			_animated_sprite = child
			break
	
	if _animated_sprite:
		_animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not _alive or _target == null:
		return
	
	var dir := (_target.global_position - global_position).normalized()
	var dist := global_position.distance_to(_target.global_position)
	
	var moving := false
	if dist > 1.0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		moving = true
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()
	
	if dist > 0.3:
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)
	
	if dist < 1.2:
		if _target.has_method("take_damage"):
			_target.take_damage(damage)
	
	if _animated_sprite:
		if moving and _animated_sprite.animation != "walk":
			_animated_sprite.play("walk")
		elif not moving and _animated_sprite.animation != "idle":
			_animated_sprite.play("idle")


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= int(amount)
	print("💥 Моб получил урон! Осталось HP: ", hp)
	
	# ⚡ ХИТ-ЭФФЕКТ (ВСПЫШКА + ЧАСТИЦЫ)
	_play_hit_effect()
	
	if hp <= 0:
		_alive = false
		_die()


func _play_hit_effect() -> void:
	# 1. ВСПЫШКА (белый цвет, 0.15 сек)
	if _animated_sprite:
		_animated_sprite.modulate = Color.WHITE
		get_tree().create_timer(0.15).timeout.connect(_reset_color)
	
	# 2. ПИКСЕЛЬНЫЕ ИСКРЫ (частицы попадания)
	_spawn_hit_particles()


func _reset_color() -> void:
	if _animated_sprite:
		_animated_sprite.modulate = Color(1, 1, 1, 1)


func _spawn_hit_particles() -> void:
	"""Создаёт маленькие искры в точке попадания"""
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	
	var tex = _make_pixel_texture()
	var origin := global_position + Vector3(0, 0.5, 0)
	
	# 6 маленьких искр
	for i in range(6):
		var spr = Sprite3D.new()
		spr.texture = tex
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.04 * randf_range(0.5, 1.5)
		spr.render_priority = 10
		spr.modulate = Color(
			randf_range(0.8, 1.0),
			randf_range(0.6, 0.9),
			randf_range(0.0, 0.3),
			1.0
		)
		root.add_child(spr)
		spr.global_position = origin
		
		var vel := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.2, 1.0),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(1.0, 2.5)
		
		var lifetime := randf_range(0.15, 0.3)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spr, "global_position", spr.global_position + vel, lifetime)
		tween.tween_property(spr, "modulate:a", 0.0, lifetime)
		
		get_tree().create_timer(lifetime + 0.05).timeout.connect(spr.queue_free)


func _die() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	if _animated_sprite:
		_animated_sprite.stop()
		_animated_sprite.modulate = Color.WHITE
	
	_spawn_death_particles()
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	if _animated_sprite:
		tween.tween_property(_animated_sprite, "modulate", Color(1, 1, 1, 0), 0.4)
	
	tween.tween_property(self, "scale", Vector3(0.2, 0.2, 0.2), 0.4)
	tween.tween_property(self, "global_position:y", global_position.y - 1.5, 0.4)
	
	await tween.finished
	queue_free()


func _spawn_death_particles() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	
	var tex = _make_pixel_texture()
	var origin := global_position + Vector3(0, 0.5, 0)
	
	for i in range(12):
		var spr = Sprite3D.new()
		spr.texture = tex
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.08 * randf_range(0.5, 1.5)
		spr.render_priority = 10
		spr.modulate = Color(
			randf_range(0.7, 1.0),
			randf_range(0.2, 0.5),
			randf_range(0.0, 0.3),
			1.0
		)
		root.add_child(spr)
		spr.global_position = origin
		
		var vel := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.5, 2.0),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(2.0, 5.0)
		
		var lifetime := randf_range(0.3, 0.6)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spr, "global_position", spr.global_position + vel, lifetime)
		tween.tween_property(spr, "modulate:a", 0.0, lifetime)
		
		get_tree().create_timer(lifetime + 0.05).timeout.connect(spr.queue_free)


func _make_pixel_texture() -> ImageTexture:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(1, 5):
		for y in range(1, 5):
			img.set_pixel(x, y, Color(1.0, 0.8, 0.2, 1.0))
	img.set_pixel(0, 2, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(5, 2, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(0, 3, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(5, 3, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(2, 0, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(3, 0, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(2, 5, Color(1.0, 0.4, 0.0, 0.8))
	img.set_pixel(3, 5, Color(1.0, 0.4, 0.0, 0.8))
	return ImageTexture.create_from_image(img)
