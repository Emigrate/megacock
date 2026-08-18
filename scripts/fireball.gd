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

# --- ЦЕПНОЙ ОТСКОК ---
var _chain_level: int = 0
var _chain_chance: float = 0.0
var _already_hit: Array = []
var _bounces_left: int = 0
var _is_chaining: bool = false

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

	# --- СЧИТЫВАЕМ УРОВЕНЬ ЦЕПИ У ИГРОКА ---
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_chain_level = player.chain_count
		_chain_chance = 0.5 + 0.1 * (_chain_level - 1)
		_bounces_left = _chain_level
	else:
		_chain_level = 0
		_chain_chance = 0.0
		_bounces_left = 0

	# --- ЗВУК ПОЛЁТА ---
	_fly_sound = AudioManager.play_fireball_fly_3d(global_position)
	if _fly_sound:
		# Добавляем только если у плеера ещё нет родителя (теперь он всегда без родителя)
		if _fly_sound.get_parent() == null:
			add_child(_fly_sound)
		else:
			# Если почему-то уже есть родитель, просто переносим
			_fly_sound.reparent(self)

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

		# Если попал во врага (моб)
		if collider and collider.is_in_group("mob") and collider.has_method("take_damage"):
			if _is_chaining and collider in _already_hit:
				continue # не бьём дважды одного и того же

			collider.take_damage(damage)
			_already_hit.append(collider)

			if _bounces_left > 0 and _chain_chance > 0.0:
				_bounces_left -= 1

				# Проверяем шанс на отскок
				if randf() < _chain_chance or _is_chaining == false:
					var next_enemy = _find_next_enemy(collider.global_position, _already_hit)
					if next_enemy:
						_dir = (next_enemy.global_position - global_position).normalized()
						_is_chaining = true
						continue # не взрываемся, продолжаем полёт

			_explode()
			return

		# Если попал в игрока или другой объект — взрыв
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(damage)
			_explode()
			return
		elif collider and not collider.is_in_group("mob"):
			_explode()
			return


func _find_next_enemy(current_pos: Vector3, exclude: Array) -> Node3D:
	var enemies = get_tree().get_nodes_in_group("mob")
	var closest_dist = INF
	var closest_enemy: Node3D = null

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in exclude or enemy == self:
			continue
		var d = current_pos.distance_to(enemy.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_enemy = enemy

	return closest_enemy


func take_damage(dmg: float) -> void:
	if _exploded:
		return
	_current_hp -= int(dmg)

	# ===== ХИТМАРКЕР (звук и визуал) =====
	var crosshairs = get_tree().get_nodes_in_group("crosshair")
	if crosshairs.size() > 0:
		crosshairs[0].show_hitmarker()
	AudioManager.play_hitmarker()
	# ================================================

	if _current_hp <= 0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	velocity = Vector3.ZERO

	if _fly_sound and is_instance_valid(_fly_sound):
		_fly_sound.stop()
		_fly_sound.queue_free()

	AudioManager.play_fireball_explosion_3d(global_position)
	SwarmManager.unregister_fireball(self)
	anim_sprite.play("explosion")
	anim_sprite.animation_finished.connect(_on_explosion_finished)


func _on_explosion_finished() -> void:
	if anim_sprite.animation == "explosion":
		queue_free()


func is_exploded() -> bool:
	return _exploded
