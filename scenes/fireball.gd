extends CharacterBody3D

@export var speed := 55.0
@export var damage := 15.0
@export var max_distance := 500.0

var _start_pos: Vector3
var _dir: Vector3
var _target: Node3D


func init(target: Node3D, dmg: float, start_pos: Vector3) -> void:
	_target = target
	damage = dmg
	_start_pos = start_pos
	if _target:
		_dir = (_target.global_position - start_pos).normalized()
		global_position = start_pos
		look_at(start_pos + _dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _dir == Vector3.ZERO:
		return
	
	velocity = _dir * speed
	move_and_slide()
	
	# Удаляем по дистанции
	if global_position.distance_to(_start_pos) > max_distance:
		queue_free()
		return
	
	# Проверяем столкновения
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Если столкнулись с игроком — наносим урон
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(damage)
		
		# В любом случае удаляем фаербол после столкновения
		queue_free()
		return
