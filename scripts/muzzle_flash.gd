extends Node3D

@export var tex_size := 2
@export var start_size := 0.10
@export var end_size := 0.01
@export var expand_time := 0.1
@export var fade_time := 0.02
@export var light_energy := 2.0
@export var light_time := 0.02
@export var particle_count := 15
@export var particle_speed := 0.5
@export var particle_lifetime := 0.01
@export var color_bright := Color(1.0, 0.95, 0.5, 1.0)
@export var color_mid := Color(1.0, 0.506, 0.102, 0.902)
@export var color_dark := Color(1.0, 0.3, 0.0, 0.5)


func _ready() -> void:
	var flash_tex := _gen_flash_texture()
	var particle_tex := _gen_particle_texture()

	var light := OmniLight3D.new()
	light.light_energy = light_energy
	light.omni_range = 8.0
	light.light_color = Color(1.0, 0.7, 0.3)
	add_child(light)
	get_tree().create_timer(light_time).timeout.connect(func():
		light.light_energy = 0.0)

	var spr := _make_sprite(flash_tex, start_size)
	add_child(spr)
	var tween := create_tween()
	tween.tween_property(spr, "pixel_size", end_size, expand_time)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

	for i in particle_count:
		var p := _make_sprite(particle_tex, start_size * randf_range(0.2, 0.45))
		p.modulate = color_mid if randf() > 0.5 else color_bright
		add_child(p)

		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.8), randf_range(-1.0, 1.0)).normalized()
		var dist := particle_speed * randf_range(0.4, 1.2)
		var lifetime := particle_lifetime * randf_range(0.5, 1.2)

		var pt := p.create_tween()
		pt.tween_property(p, "position", dir * dist, lifetime)
		pt.parallel().tween_property(p, "modulate:a", 0.0, lifetime)
		pt.tween_callback(p.queue_free)


func _make_sprite(tex: ImageTexture, px_size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = px_size
	return s


func _gen_flash_texture() -> ImageTexture:
	var s := tex_size
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var h := int(s / 2.0)   # исправлено
	var q := int(s / 4.0)   # исправлено
	var t := maxi(int(s / 8.0), 1)  # исправлено

	for x in range(h - t, h + t):
		for y in range(q, s - q):
			img.set_pixel(x, y, color_bright)
	for y in range(h - t, h + t):
		for x in range(q, s - q):
			img.set_pixel(x, y, color_bright)
	for x in range(h - q, h + q):
		for y in range(h - q, h + q):
			if img.get_pixel(x, y).a < 0.5:
				img.set_pixel(x, y, color_mid)

	img.set_pixel(q, h - 1, color_dark)
	img.set_pixel(q, h, color_dark)
	img.set_pixel(s - q - 1, h - 1, color_dark)
	img.set_pixel(s - q - 1, h, color_dark)
	if t > 1:
		img.set_pixel(h - 1, t - 1, color_dark)
		img.set_pixel(h, t - 1, color_dark)
		img.set_pixel(h - 1, s - t, color_dark)
		img.set_pixel(h, s - t, color_dark)

	return ImageTexture.create_from_image(img)


func _gen_particle_texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(1, 1, color_bright)
	img.set_pixel(2, 1, color_bright)
	img.set_pixel(1, 2, color_bright)
	img.set_pixel(2, 2, color_mid)
	return ImageTexture.create_from_image(img)
