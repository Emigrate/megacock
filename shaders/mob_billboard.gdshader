shader_type spatial;
render_mode cull_back, unshaded, depth_draw_opaque;

uniform sampler2DArray tex_array : source_color, filter_nearest;
uniform float frame_count = 15.0;

// --- Настройка дальности видимости ---
uniform float fade_start : hint_range(0.0, 300.0) = 25.0;   // с какой дистанции начинает темнеть
uniform float fade_end   : hint_range(0.0, 500.0) = 150.0;  // на какой дистанции достигает минимума
uniform float min_brightness : hint_range(0.0, 1.0) = 0.6;  // минимальная яркость (не даём уйти в 0.35 -> почти чёрный)

void vertex() {
	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 look_dir = vec3(camera_pos.x - world_pos.x, 0.0, camera_pos.z - world_pos.z);
	float len = length(look_dir);
	if (len > 0.0001) {
		look_dir /= len;
	} else {
		look_dir = vec3(0.0, 0.0, 1.0);
	}
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, look_dir));

	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);

	mat4 billboard_matrix = mat4(
		vec4(right * scale_x, 0.0),
		vec4(up * scale_y, 0.0),
		vec4(look_dir, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
}

void fragment() {
	float layer = floor(COLOR.r * frame_count + 0.5);
	vec4 tex = texture(tex_array, vec3(UV, layer));

	if (tex.a < 0.5) {
		discard;
	}

	ALBEDO = tex.rgb;

	float dist = length(VERTEX);
	float fade = clamp(1.0 - (dist - fade_start) / max(fade_end - fade_start, 0.001), min_brightness, 1.0);
	ALBEDO *= fade;
}