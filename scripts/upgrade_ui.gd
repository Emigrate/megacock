extends CanvasLayer

var _pending_upgrades: Array = []
var _is_showing := false
var _buttons: Array[Button] = []
var _container: VBoxContainer
var _bg: ColorRect
var _title: Label
var _buttons_enabled := false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.modulate = Color(1, 1, 1, 0)
	add_child(_bg)

	_title = Label.new()
	_title.text = "LEVEL UP"
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 0.5
	_title.offset_left = -250
	_title.offset_right = 250
	_title.offset_top = -230
	_title.offset_bottom = -170
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.pivot_offset = Vector2(250, 30)
	_title.scale = Vector2(0.5, 0.5)
	_title.modulate = Color(1, 1, 1, 0)
	_bg.add_child(_title)

	_container = VBoxContainer.new()
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 0.5
	_container.anchor_bottom = 0.5
	_container.offset_left = -250
	_container.offset_right = 250
	_container.offset_top = -150
	_container.offset_bottom = 150
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_theme_constant_override("separation", 16)
	_bg.add_child(_container)

	await get_tree().process_frame

	var mgr = get_tree().root.get_node_or_null("UpgradeManager")
	if mgr:
		mgr.upgrades_offered.connect(_on_upgrades_offered)
		print("✅ UpgradeUI подключён к UpgradeManager")
	else:
		print("❌ UpgradeManager не найден! Проверь автозагрузку.")


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary":
			return Color(1.0, 0.84, 0.0)
		"Rare":
			return Color(0.2, 0.4, 0.8)
		_:
			return Color(0.4, 0.4, 0.4)


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


func _style_button(btn: Button, rarity: String) -> void:
	var color = _get_rarity_color(rarity)
	var normal := _make_button_style(Color(0.12, 0.12, 0.16, 0.95), color)
	var hover := _make_button_style(Color(0.18, 0.18, 0.24, 0.95), color)
	var pressed := _make_button_style(Color(0.08, 0.08, 0.1, 0.95), color)
	# такой же стиль, что и normal — чтобы рамка редкости была видна сразу,
	# пока кнопка технически disabled во время анимации появления
	var disabled := _make_button_style(Color(0.12, 0.12, 0.16, 0.95), color)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.3))
	btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.95))

	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = true

	btn.modulate = Color(1, 1, 1, 0)
	btn.scale = Vector2(0.8, 0.8)

	# hover-отклик
	btn.mouse_entered.connect(func():
		if _buttons_enabled:
			var t = create_tween()
			t.set_trans(Tween.TRANS_BACK)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.15)
	)
	btn.mouse_exited.connect(func():
		if _buttons_enabled:
			var t = create_tween()
			t.set_trans(Tween.TRANS_QUAD)
			t.set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	)


func _on_upgrades_offered(upgrade_list: Array):
	if _is_showing:
		return

	_is_showing = true
	_pending_upgrades = upgrade_list

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true

	_buttons_enabled = false

	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	# --- сброс перед новой анимацией ---
	_bg.pivot_offset = _bg.size / 2
	_bg.scale = Vector2(1.08, 1.08)
	_bg.modulate = Color(1, 1, 1, 0)

	_title.modulate = Color(1, 1, 1, 0)
	_title.scale = Vector2(0.5, 0.5)

	var player = get_tree().get_first_node_in_group("player")
	var count = min(upgrade_list.size(), 4)

	for i in range(count):
		var upgrade = upgrade_list[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(500, 70)
		btn.pivot_offset = Vector2(250, 35)  # центр кнопки (500x70)
		_style_button(btn, upgrade.rarity)

		var display_name = upgrade.upgrade_name
		var display_desc = upgrade.description
		if player and upgrade.upgrade_name == "Chain Reaction":
			var next_level = player.chain_count + 1
			var chance = 0.5 + 0.1 * (next_level - 1)
			var chance_percent = int(chance * 100)
			display_desc = "Level " + str(next_level) + ": " + str(chance_percent) + "% chance for " + str(next_level) + " bounce(s)"
		elif player and upgrade.upgrade_name == "Auto Shot":
			var next_level = player.auto_shots + 1
			var next_dmg = player.auto_shot_damage + 15
			display_desc = "Level " + str(next_level) + ": +1 shot/s, " + str(next_dmg) + " dmg"

		btn.text = display_name + "\n" + display_desc
		btn.pressed.connect(func():
			_on_button_pressed(i)
		)
		_container.add_child(btn)
		_buttons.append(btn)

	print("🟠 Кнопки созданы. Анимация...")

	# ждём, пока VBoxContainer реально расставит кнопки по местам,
	# иначе ручное смещение position ниже перезапишется контейнером
	# и получится рывок/задержка
	await get_tree().process_frame
	await get_tree().process_frame

	# теперь можно безопасно сдвинуть кнопки вниз для slide-up эффекта
	for btn in _buttons:
		btn.position.y += 30

	# === ШАГ 1: фон плавно "оседает" — fade + лёгкий zoom-out ===
	var bg_tween = create_tween()
	bg_tween.set_parallel(true)
	bg_tween.tween_property(_bg, "modulate", Color(1, 1, 1, 1), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bg_tween.tween_property(_bg, "scale", Vector2(1, 1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.12).timeout

	# === ШАГ 2: тайтл ===
	var title_tween = create_tween()
	title_tween.set_parallel(true)
	title_tween.tween_property(_title, "modulate", Color(1, 1, 1, 1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(_title, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# === ШАГ 3: кнопки по очереди ===
	var stagger_delay := 0.08
	for i in range(_buttons.size()):
		var btn = _buttons[i]
		var target_y = btn.position.y - 30
		var delay = 0.05 + i * stagger_delay

		var chain = create_tween()
		chain.tween_interval(delay)
		chain.set_parallel(true)
		chain.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		chain.tween_property(btn, "scale", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		chain.tween_property(btn, "position:y", target_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var total_delay = 0.12 + 0.05 + (_buttons.size() - 1) * stagger_delay + 0.4
	await get_tree().create_timer(total_delay).timeout
	_buttons_enabled = true
	for btn in _buttons:
		btn.disabled = false
	print("🟢 Кнопки активны!")


func _on_button_pressed(index: int):
	if not _buttons_enabled:
		print("⛔ Слишком рано!")
		return

	print("🔵 Клик по кнопке ", index)
	var upgrade = _pending_upgrades[index]
	if upgrade == null:
		print("❌ Ошибка: апгрейд null")
		return

	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		print("❌ Игрок не найден")
		return

	_buttons_enabled = false
	for btn in _buttons:
		btn.disabled = true

	var chosen_btn = _buttons[index]

	# === АНИМАЦИЯ ЗАКРЫТИЯ ===
	var close_tween = create_tween()
	close_tween.set_parallel(true)

	close_tween.tween_property(chosen_btn, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for i in range(_buttons.size()):
		if i == index:
			continue
		var btn = _buttons[i]
		close_tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		close_tween.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.12).timeout

	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_bg, "modulate", Color(1, 1, 1, 0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(chosen_btn, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(chosen_btn, "modulate:a", 0.0, 0.18)

	await get_tree().create_timer(0.18).timeout

	print("🟢 Применяем: ", upgrade.upgrade_name)
	upgrade.apply_func.call(player)

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false
	_is_showing = false
	_buttons_enabled = false
