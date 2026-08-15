extends CharacterBody3D

@export var speed := 4.0
@export var hp := 3
@export var damage := 10.0

var _target: Node3D
var _alive := true


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


func _physics_process(delta: float) -> void:
	if not _alive or _target == null:
		return
	
	var dir := (_target.global_position - global_position).normalized()
	var dist := global_position.distance_to(_target.global_position)
	
	if dist > 1.0:
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
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)
	
	if dist < 1.2:
		if _target.has_method("take_damage"):
			_target.take_damage(damage)


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= int(amount)
	if hp <= 0:
		_alive = false
		_die()


func _die() -> void:
	# Отключаем физику и коллизию
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	# Анимация смерти: уменьшаемся, поднимаемся и исчезаем
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position:y", global_position.y + 0.5, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	
	# Удаляем моба после анимации
	tween.finished.connect(queue_free)
