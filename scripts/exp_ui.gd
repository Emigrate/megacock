extends Control

@onready var exp_bar: ProgressBar = $ProgressBar
@onready var level_label: Label = $ProgressBar/Label

@export var anim_duration: float = 0.25
@export var flash_color: Color = Color(1, 0.85, 0.2)

var _tween: Tween

func _ready():
	if is_instance_valid(ExpManager):
		_connect_manager()
	else:
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(ExpManager):
			_connect_manager()
		else:
			print("❌ ExpUI: менеджер не найден.")
			exp_bar.max_value = 100
			exp_bar.value = 0
			level_label.text = "Lvl 1"

func _connect_manager():
	print("✅ ExpUI: подключён к ExpManager!")
	
	# Принудительно задаём цвет заливки, если ещё не переопределён
	if not exp_bar.has_theme_color_override("fill"):
		exp_bar.add_theme_color_override("fill", Color(1, 0.8, 0))
	
	ExpManager.exp_changed.connect(_update_ui)
	ExpManager.level_up.connect(_update_level)
	
	_update_ui(ExpManager.current_exp, ExpManager.exp_to_next_level)
	_update_level(ExpManager.level)

func _update_ui(current_exp: int, exp_needed: int):
	exp_bar.max_value = exp_needed
	_animate_bar(current_exp)
	_flash_fill()

func _update_level(new_level: int):
	level_label.text = "Lvl " + str(new_level)

func _animate_bar(target_value: int):
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(exp_bar, "value", target_value, anim_duration)

func _flash_fill():
	var original_color = exp_bar.get_theme_color("fill")
	if original_color == null:
		original_color = Color(1, 0.8, 0)
	
	var tween_flash = create_tween()
	tween_flash.set_parallel(true)
	
	# Анимируем смену цвета через add_theme_color_override
	tween_flash.tween_method(
		func(color):
			exp_bar.add_theme_color_override("fill", color),
		original_color,
		flash_color,
		0.08
	)
	tween_flash.tween_method(
		func(color):
			exp_bar.add_theme_color_override("fill", color),
		flash_color,
		original_color,
		0.15
	)
