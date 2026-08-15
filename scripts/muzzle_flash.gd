extends Node3D

@export var frame_count := 2
@export var animation_speed := 2
@export var start_size := 0.40
@export var end_size := 0.01
@export var light_energy := 2.5
@export var light_time := 0.1
@export var tex_size := 8               # разрешение текстуры (чем больше, тем детальнее)

# --- НАСТРОЙКИ ЗАТУХАНИЯ ---
@export var fade_delay := 0.01
@export var fade_duration := 0.03

var opacity := 1.0


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("flash")
	
	for i in range(frame_count):
		var t := float(i) / float(frame_count - 1)
		var brightness := 1.0 - t * 0.6
		var color := Color(1.0, 0.9 - t * 0.5, 0.4 - t * 0.3, brightness)
		var tex := _gen_explosion_cloud(tex_size, color)
		frames.add_frame("flash", tex)
	
	var anim_sprite := AnimatedSprite3D.new()
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "flash"
	anim_sprite.play()
	anim_sprite.speed_scale = animation_speed
	anim_sprite.pixel_size = start_size
	anim_sprite.modulate = Color(1, 1, 1, opacity)
	anim_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(anim_sprite)
	
	var expand_tween := create_tween()
	expand_tween.tween_property(anim_sprite, "pixel_size", start_size * 2.0, 0.05)
	expand_tween.tween_property(anim_sprite, "pixel_size", start_size * 1.4, 0.04)
	
	var alpha_tween := create_tween()
	alpha_tween.tween_property(anim_sprite, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	
	var light := OmniLight3D.new()
	light.light_energy = light_energy
	light.omni_range = 8.0
	light.light_color = Color(1.0, 0.7, 0.3)
	add_child(light)
	var light_tween := create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, light_time)
	
	var total_duration := fade_delay + fade_duration + 0.02
	get_tree().create_timer(total_duration).timeout.connect(queue_free)


func _gen_explosion_cloud(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center := Vector2(size/2.0, size/2.0)
	# Генерируем несколько центров взрыва (от 1 до 3)
	var centers = []
	var num_centers = randi() % 3 + 1
	for n in num_centers:
		var offset = Vector2(randf_range(-size*0.2, size*0.2), randf_range(-size*0.2, size*0.2))
		centers.append(center + offset)
	
	# Заполняем пиксели случайными точками с падением яркости от центров
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var max_val = 0.0
			# Берём максимальную близость к любому центру
			for c in centers:
				var dist = pos.distance_to(c)
				var val = 1.0 - clampf(dist / (size * 0.6), 0.0, 1.0)
				# Добавляем шум
				val *= 0.6 + randf() * 0.4
				if val > max_val:
					max_val = val
			# Применяем порог, чтобы было рвано
			if max_val > 0.15 and randf() < max_val * 0.9:
				var alpha = max_val * randf_range(0.6, 1.0)
				# Небольшая вариация цвета (жёлто-оранжево-красный)
				var col = Color(1.0, 0.7 + randf()*0.3, 0.1 + randf()*0.3, alpha)
				col = col.lerp(color, 0.5 + randf()*0.5)
				col.a *= alpha
				img.set_pixel(x, y, col)
	
	# Добавляем яркое ядро (несколько центральных пикселей)
	for c in centers:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var px = int(c.x + dx)
				var py = int(c.y + dy)
				if px >= 0 and px < size and py >= 0 and py < size:
					var dist = Vector2(px, py).distance_to(c)
					var val = 1.0 - clampf(dist / 3.0, 0.0, 1.0)
					if val > 0:
						img.set_pixel(px, py, Color(1.0, 0.9, 0.6, val * 0.8))
	
	return ImageTexture.create_from_image(img)
