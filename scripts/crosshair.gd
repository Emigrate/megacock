extends Control

# --- НАСТРОЙКИ ПРИЦЕЛА ---
@export var crosshair_color: Color = Color.WHITE_SMOKE
@export var crosshair_size: float = 5.0
@export var gap: float = 3
@export var thickness: float = 1.5
@export var dot_size: float = 0.0

# --- НАСТРОЙКИ ХИТМАРКЕРА (TextureRect) ---
@export var hitmarker_texture: Texture2D = null
@export var hitmarker_color: Color = Color.WHITE
@export var hitmarker_duration: float = 0.15
@export var hitmarker_scale: float = 0.03 : set = _set_hitmarker_scale
@export var hitmarker_offset: Vector2 = Vector2.ZERO : set = _set_hitmarker_offset

# Внутренние переменные
var _hitmarker: TextureRect = null
var _hitmarker_timer := 0.0


func _ready():
	add_to_group("crosshair")

	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size
	position = Vector2.ZERO

	# Загрузка текстуры
	if hitmarker_texture == null:
		var path = "res://assets/textures/hitmarker.png"
		if ResourceLoader.exists(path):
			hitmarker_texture = load(path)
			print("✅ Хитмаркер загружен из: ", path)
		else:
			print("❌ Не найден файл: ", path)

	if hitmarker_texture == null:
		print("⚠️ Текстура отсутствует, хитмаркер не будет работать.")
		return

	# Создаём TextureRect
	_hitmarker = TextureRect.new()
	_hitmarker.texture = hitmarker_texture
	_hitmarker.modulate = hitmarker_color
	_hitmarker.visible = false
	_hitmarker.z_index = 200
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # позволяет .size реально менять отображаемый размер
	_hitmarker.stretch_mode = TextureRect.STRETCH_SCALE         # растягивает текстуру под .size

	add_child(_hitmarker)

	_position_hitmarker()

	get_viewport().size_changed.connect(_update_position)


func _set_hitmarker_scale(value: float):
	hitmarker_scale = value
	_position_hitmarker()


func _set_hitmarker_offset(value: Vector2):
	hitmarker_offset = value
	_position_hitmarker()


func _position_hitmarker():
	if not _hitmarker or not _hitmarker.texture:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var tex_size = _hitmarker.texture.get_size() * hitmarker_scale
	_hitmarker.size = tex_size
	_hitmarker.pivot_offset = tex_size / 2.0
	_hitmarker.position = (viewport_size - tex_size) / 2.0 + hitmarker_offset


func _update_position():
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size
	position = Vector2.ZERO
	_position_hitmarker()


func _draw():
	var center = size / 2.0
	var color = crosshair_color
	var half_thick = thickness / 2.0

	if dot_size > 0.1:
		var dot_rect = Rect2(center.x - dot_size / 2, center.y - dot_size / 2, dot_size, dot_size)
		draw_rect(dot_rect, color)

	draw_rect(Rect2(center.x - half_thick, center.y - gap - crosshair_size, thickness, crosshair_size), color)
	draw_rect(Rect2(center.x - half_thick, center.y + gap, thickness, crosshair_size), color)
	draw_rect(Rect2(center.x - gap - crosshair_size, center.y - half_thick, crosshair_size, thickness), color)
	draw_rect(Rect2(center.x + gap, center.y - half_thick, crosshair_size, thickness), color)


func _process(delta):
	if _hitmarker and _hitmarker_timer > 0:
		_hitmarker_timer -= delta
		var alpha = clamp(_hitmarker_timer / hitmarker_duration, 0.0, 1.0)
		var color = hitmarker_color
		color.a = alpha
		_hitmarker.modulate = color

		if _hitmarker_timer <= 0.0:
			_hitmarker.visible = false
			_hitmarker.modulate = hitmarker_color


func show_hitmarker():
	if _hitmarker and _hitmarker.texture != null:
		_position_hitmarker()
		_hitmarker.visible = true
		_hitmarker.modulate = hitmarker_color
		_hitmarker_timer = hitmarker_duration
	else:
		print("⚠️ Хитмаркер не показан: TextureRect или текстура отсутствуют.")
