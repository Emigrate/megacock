extends CanvasLayer
## ХУД: прицел + FPS + скорость + HP + счётчик мобов.

var speed_label: Label
var fps_label: Label
var hp_label: Label
var mob_label: Label
var _crosshair_nodes: Array = []


func _ready() -> void:
	_build_fps_label()
	_build_speed_label()
	_build_hp_label()
	_build_mob_label()
	_build_crosshair()


func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _build_fps_label() -> void:
	fps_label = Label.new()
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 18)
	add_child(fps_label)


func _build_speed_label() -> void:
	speed_label = Label.new()
	speed_label.position = Vector2(10, 30)
	speed_label.add_theme_font_size_override("font_size", 18)
	add_child(speed_label)


func _build_hp_label() -> void:
	hp_label = Label.new()
	hp_label.position = Vector2(10, 50)
	hp_label.add_theme_font_size_override("font_size", 18)
	add_child(hp_label)


func _build_mob_label() -> void:
	mob_label = Label.new()
	mob_label.position = Vector2(10, 70)
	mob_label.add_theme_font_size_override("font_size", 18)
	mob_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	add_child(mob_label)


func _build_crosshair() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5

	var v := ColorRect.new()
	v.color = Color.WHITE
	v.size = Vector2(2, 14)
	v.position = center - Vector2(1, 7)
	add_child(v)
	_crosshair_nodes.append(v)

	var h := ColorRect.new()
	h.color = Color.WHITE
	h.size = Vector2(14, 2)
	h.position = center - Vector2(7, 1)
	add_child(h)
	_crosshair_nodes.append(h)

	var dot := ColorRect.new()
	dot.color = Color(0, 0, 0, 0.5)
	dot.size = Vector2(2, 2)
	dot.position = center - Vector2(1, 1)
	add_child(dot)
	_crosshair_nodes.append(dot)


func set_speed(text: String) -> void:
	if speed_label:
		speed_label.text = text


func set_hp(current: int, max_hp: int) -> void:
	if hp_label:
		hp_label.text = "HP: %d/%d" % [current, max_hp]


func set_mob_count(count: int) -> void:
	if mob_label:
		mob_label.text = "Мобов: %d" % count


func set_crosshair_visible(v: bool) -> void:
	for n in _crosshair_nodes:
		n.visible = v
