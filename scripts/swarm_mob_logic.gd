extends CharacterBody3D

@export var speed := 4.0
@export var hp := 3
@export var damage := 10.0

# --- КУЛДАУН АТАКИ ---
# Раньше урон наносился каждый physics-тик (60 раз/сек) пока моб
# стоял рядом с игроком. Теперь — не чаще attack_interval секунд.
@export var attack_interval: float = 0.8
var _attack_cooldown: float = 0.0

# --- ДИСТАНЦИОННЫЙ ТРОТТЛИНГ ФИЗИКИ ---
@export var far_distance: float = 40.0
@export var far_update_interval: float = 0.2
var _far_update_timer: float = 0.0
var _cached_dir: Vector3 = Vector3.ZERO
var _cached_dist: float = 0.0

# --- МЯГКОЕ РАЗДЕЛЕНИЕ (замена физической коллизии моб-моб) ---
# ВАЖНО: у мобов должна быть отключена коллизия ДРУГ С ДРУГОМ
# (collision_layer/mask настраивается в сцене или в _ready ниже) —
# иначе физический солвер и это разделение будут работать одновременно
# и толкать мобов вдвойне.
@export var separation_enabled: bool = true
@export var separation_gap: float = 1.2
@export var separation_strength: float = 0.5  # доля от speed, насколько сильно расталкивает

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

	# Отключаем коллизию мобов друг с другом на уровне кода — на случай,
	# если в сцене забыли настроить layers/mask. Подставьте свои реальные
	# номера слоёв игрока/окружения вместо примерных здесь.
	# collision_layer = 1 << 2       # например, слой "mobs" (бит 3)
	# collision_mask = (1 << 0) | (1 << 1)  # сталкиваемся только с игроком и окружением


func _physics_process(delta: float) -> void:
	if not _alive or _target == null:
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	# --- Троттлинг для дальних мобов ---
	var dist_to_target := global_position.distance_to(_target.global_position)
	var should_full_update := dist_to_target <= far_distance

	if should_full_update:
		_cached_dir = (_target.global_position - global_position).normalized()
		_cached_dist = dist_to_target
	else:
		_far_update_timer -= delta
		if _far_update_timer <= 0.0:
			_far_update_timer = far_update_interval
			_cached_dir = (_target.global_position - global_position).normalized()
			_cached_dist = dist_to_target

	var dir := _cached_dir
	var dist := _cached_dist

	# --- Мягкое разделение от соседей (вместо физической коллизии) ---
	var move_dir := dir
	if separation_enabled and MobManager != null:
		var nearby := MobManager.get_nearby_mobs(global_position)
		var push := MobManager.get_separation_push(self, nearby, separation_gap)
		if push != Vector3.ZERO:
			move_dir = (dir + push * separation_strength).normalized()

	if dist > 1.0:
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
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

	# --- Атака по кулдауну ---
	if dist < 1.2 and _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
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
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position:y", global_position.y + 0.5, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)
