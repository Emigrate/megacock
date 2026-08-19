extends Node
class_name GhoulData

const FRAME_PATHS := [
	"res://assets/textures/ghoul/ghoul_attack1.png",
	"res://assets/textures/ghoul/ghoul_attack2.png",
	"res://assets/textures/ghoul/ghoul_attack3.png",
	"res://assets/textures/ghoul/ghoul_death1.png",
	"res://assets/textures/ghoul/ghoul_death2.png",
	"res://assets/textures/ghoul/ghoul_death3.png",
	"res://assets/textures/ghoul/ghoul_death4.png",
	"res://assets/textures/ghoul/ghoul_death5.png",
	"res://assets/textures/ghoul/ghoul_death6.png",
	"res://assets/textures/ghoul/ghoul_death7.png",
	"res://assets/textures/ghoul/ghoul_death8.png",
	"res://assets/textures/ghoul/ghoul_hit1.png",
	"res://assets/textures/ghoul/ghoul_hit.png",
	"res://assets/textures/ghoul/ghoul_walking1.png",
	"res://assets/textures/ghoul/ghoul_walking2.png",
]

const ANIM := {
	"attack": {"start": 0,  "count": 3, "fps": 6.0,  "loop": false},
	"death":  {"start": 3,  "count": 8, "fps": 8.0,  "loop": false},
	"hit":    {"start": 11, "count": 2, "fps": 10.0, "loop": false},
	"walk":   {"start": 13, "count": 2, "fps": 6.0,  "loop": true},
}

static var _cached_texture: Texture2DArray = null

static var texture_array: Texture2DArray:
	get:
		if _cached_texture == null:
			_cached_texture = _build_texture_array()
		return _cached_texture

static func _build_texture_array() -> Texture2DArray:
	var images: Array[Image] = []
	var max_w := 0
	var max_h := 0

	for path in FRAME_PATHS:
		var tex = load(path) as Texture2D
		if not tex: continue
		var img = tex.get_image()
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
		max_w = max(max_w, img.get_width())
		max_h = max(max_h, img.get_height())

	var normalized_images: Array[Image] = []
	for img in images:
		var canvas = Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
		var offset_x = (max_w - img.get_width()) / 2
		var offset_y = max_h - img.get_height() # Прижимаем к низу
		canvas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(offset_x, offset_y))
		normalized_images.append(canvas)

	var tex_array = Texture2DArray.new()
	tex_array.create_from_images(normalized_images)
	return tex_array

static func frame_for(anim_name: String, timer: float) -> int:
	var a = ANIM[anim_name]
	var idx = int(timer * a.fps)
	if a.loop: idx = idx % a.count
	else: idx = min(idx, a.count - 1)
	return a.start + idx

static func anim_duration(anim_name: String) -> float:
	return ANIM[anim_name].count / ANIM[anim_name].fps
