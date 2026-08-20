extends Area3D

# --- НАСТРОЙКИ ЭКСПЫ ---
@export var exp_amount: int = 1
@export var lifetime: float = 10.0
@export var float_speed: float = 1.5
@export var float_height: float = 0.25

# --- НАСТРОЙКИ МАГНИТА ---
@export var magnet_radius: float = 200     # Радиус притяжения
@export var magnet_speed: float = 50       # Скорость притяжения
@export var magnet_delay: float = 0.1      # Задержка перед включением магнита
@export var collision_radius: float = 2    # Радиус касания для подбора

# --- НАСТРОЙКИ ВЫЛЕТА ---
@export var horizontal_speed_min: float = 4.0
@export var horizontal_speed_max: float = 6.0
@export var vertical_speed_min: float = 6.0
@export var vertical_speed_max: float = 8.0
@export var fly_gravity: float = 35.0

# Переменные для полёта
var start_y: float
var floor_y: float
var is_flying := true
var fly_velocity := Vector3.ZERO

# Флаг: можно ли притягиваться (включается после приземления)
var can_magnet := false

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	# Настраиваем спрайт и коллизию
	if not sprite.texture:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.8, 0.0))
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.scale = Vector3(2.5, 2.5, 1.0)
		
	if not collision_shape.shape:
		var default_shape = SphereShape3D.new()
		default_shape.radius = collision_radius
		collision_shape.shape = default_shape

	start_y = global_position.y
	
	# --- ИСПРАВЛЕНИЕ: луч вниз на 1000 метров (достанет пол с любой высоты) ---
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position - Vector3(0, 1000, 0))
	var result = space_state.intersect_ray(query)
	if result:
		floor_y = result.position.y + 0.05
	else:
		# Если пол не найден (например, над пропастью), падаем вниз на 2 метра
		floor_y = start_y - 2.0

	# Запускаем бросок
	var random_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	var horizontal_speed = randf_range(horizontal_speed_min, horizontal_speed_max)
	var vertical_speed = randf_range(vertical_speed_min, vertical_speed_max)
	
	fly_velocity = random_dir * horizontal_speed
	fly_velocity.y = vertical_speed

	get_tree().create_timer(lifetime).timeout.connect(_despawn)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_flying:
		# Полёт
		fly_velocity.y -= fly_gravity * delta
		global_position += fly_velocity * delta
		rotate_y(delta * 3.0)
		
		if fly_velocity.y <= 0 and global_position.y <= floor_y:
			_on_landed()
	else:
		# После приземления — покачивание + вращение
		var time = Time.get_ticks_msec() * 0.001
		global_position.y = floor_y + sin(time * float_speed) * float_height
		rotate_y(delta * 1.5)
		
		# --- МАГНИТ: притягиваемся к игроку, если он рядом ---
		if can_magnet:
			var player = _get_nearest_player()
			if player:
				var dist = global_position.distance_to(player.global_position)
				if dist <= magnet_radius and dist > 0.1:
					var direction = (player.global_position - global_position).normalized()
					global_position += direction * magnet_speed * delta

func _on_landed():
	is_flying = false
	global_position.y = floor_y
	
	# Задержка перед магнитом
	await get_tree().create_timer(magnet_delay).timeout
	can_magnet = true

func _on_body_entered(body):
	if body.is_in_group("player"):
		# ПРАВИЛЬНЫЙ ВЫЗОВ: просто по имени, без Engine.has_singleton
		ExpManager.add_exp(exp_amount) 
		_despawn()

func _despawn():
	queue_free()

# --- Вспомогательная функция: найти ближайшего игрока ---
func _get_nearest_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var nearest = players[0]
	var min_dist = global_position.distance_squared_to(nearest.global_position)
	for p in players:
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest
