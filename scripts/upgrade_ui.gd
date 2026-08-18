extends CanvasLayer

var _pending_upgrades: Array = []
var _is_showing := false
var _buttons: Array[Button] = []
var _container: VBoxContainer
var _bg: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

	# Фон
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Заголовок "LEVEL UP"
	var title := Label.new()
	title.text = "LEVEL UP"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.5
	title.offset_left = -250
	title.offset_right = 250
	title.offset_top = -230
	title.offset_bottom = -170
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg.add_child(title)

	# Контейнер для кнопок (по центру) — центрируем вручную через anchor+offset
	_container = VBoxContainer.new()
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 0.5
	_container.anchor_bottom = 0.5
	_container.offset_left = -250
	_container.offset_right = 250
	_container.offset_top = -150
	_container.offset_bottom = 150
	_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_container.add_theme_constant_override("separation", 16)
	_bg.add_child(_container)

	await get_tree().process_frame

	var mgr = get_tree().root.get_node_or_null("UpgradeManager")
	if mgr:
		mgr.upgrades_offered.connect(_on_upgrades_offered)
		print("✅ UpgradeUI подключён к UpgradeManager")
	else:
		print("❌ UpgradeManager не найден! Проверь автозагрузку и имя узла.")


func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _style_button(btn: Button) -> void:
	var normal := _make_button_style(Color(0.12, 0.12, 0.16, 0.95), Color(0.35, 0.35, 0.42))
	var hover := _make_button_style(Color(0.18, 0.18, 0.24, 0.95), Color(1.0, 0.85, 0.3))
	var pressed := _make_button_style(Color(0.08, 0.08, 0.1, 0.95), Color(1.0, 0.7, 0.2))

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.3))

	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_upgrades_offered(upgrade_list: Array):
	if _is_showing:
		return

	_is_showing = true
	_pending_upgrades = upgrade_list

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true

	# Очищаем старые кнопки
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	# Создаём новые кнопки с лямбда-обработчиком
	var count = min(upgrade_list.size(), 4)
	for i in range(count):
		var upgrade = upgrade_list[i]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(500, 70)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.text = ""
		_style_button(btn)

		# Название + описание отдельными строками (название крупнее)
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.anchor_left = 0
		vbox.anchor_right = 1
		vbox.anchor_top = 0
		vbox.anchor_bottom = 1
		vbox.offset_left = 10
		vbox.offset_right = -10
		vbox.offset_top = 4
		vbox.offset_bottom = -4
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var name_label := Label.new()
		name_label.text = upgrade.upgrade_name
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = upgrade.description
		desc_label.add_theme_font_size_override("font_size", 15)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

		btn.add_child(vbox)

		btn.pressed.connect(func():
			_on_button_pressed(i)
		)
		_container.add_child(btn)
		_buttons.append(btn)
	print("🟠 Кнопки созданы, ожидают нажатия.")


func _on_button_pressed(index: int):
	print("🔵 Нажата кнопка с индексом ", index)
	var upgrade = _pending_upgrades[index]
	if upgrade == null:
		print("❌ Ошибка: upgrade null")
		return

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("❌ Игрок не найден!")
		return

	print("🟢 Применяем апгрейд: ", upgrade.upgrade_name)
	upgrade.apply_func.call(player)
	print("✅ Апгрейд применён")

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false
	_is_showing = false
