extends Label3D
## Компонент одной "всплывающей цифры урона".
## Больше НЕ вызывает queue_free() сам — им управляет DamageNumberPool,
## который переиспользует ноды вместо создания/уничтожения.

# --- НАСТРОЙКИ ПОВЕДЕНИЯ ---
@export var float_speed: float = 6            # скорость подъёма
@export var fade_duration: float = 0.3        # время затухания
@export var pop_duration: float = 0.15        # длительность "выпрыгивания"
@export var pop_scale: float = 1.5            # насколько цифра увеличивается при появлении
@export var horizontal_spread: float = 4      # разлёт по горизонтали
@export var spawn_height: float = 2.0         # высота над мобом

# --- ЦВЕТА ---
@export var damage_color: Color = Color.WHITE
@export var chain_color: Color = Color.ORANGE

# --- ШРИФТ ---
@export var font_override: Font = null

var _tween: Tween
var _target_scale := Vector3.ONE

# Колбэк, который дергает пул, чтобы забрать нод обратно (вместо queue_free)
var _on_finished_callback: Callable


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 10
	if font_override:
		font = font_override
	if font_size < 64:
		font_size = 96
	# Обводка размером поменьше — заметный вклад в стоимость рендера
	# каждого лейбла при большом количестве одновременных цифр.
	outline_size = 2
	outline_modulate = Color.BLACK


## Вызывается пулом при выдаче нода. release_callback — функция пула,
## которая вернёт этот нод обратно в пул (не queue_free!).
## Если release_callback не передан (старый способ вызова напрямую,
## без пула) — нода после анимации просто queue_free() как раньше.
func init(damage: int, base_position: Vector3, is_chain: bool = false, release_callback: Callable = Callable()) -> void:
	_on_finished_callback = release_callback

	text = str(damage)
	modulate = chain_color if is_chain else damage_color
	modulate.a = 1.0

	var spread := Vector3(
		randf_range(-horizontal_spread, horizontal_spread),
		spawn_height,
		randf_range(-horizontal_spread, horizontal_spread)
	)
	global_position = base_position + spread
	scale = Vector3.ZERO
	_target_scale = Vector3.ONE * pop_scale
	visible = true
	_animate()


func _animate() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(self, "scale", _target_scale, pop_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE, pop_duration * 0.8).set_delay(pop_duration * 0.6)

	_tween.tween_property(self, "position:y", position.y + 2.5, float_speed)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.finished.connect(_despawn, CONNECT_ONE_SHOT)


func _despawn() -> void:
	visible = false
	if _on_finished_callback.is_valid():
		_on_finished_callback.call(self)
	else:
		# Нод создан не пулом (старый прямой вызов init без колбэка) —
		# ведём себя как раньше и просто уничтожаем себя.
		queue_free()
