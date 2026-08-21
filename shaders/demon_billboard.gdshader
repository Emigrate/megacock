shader_type spatial;
render_mode cull_back, depth_draw_opaque, unshaded;
uniform sampler2DArray tex_array : source_color, filter_nearest;
uniform float frame_count = 14.0; // синхронизировано с FRAME_PATHS.size() из demon_swarm.gd
void vertex() {
	// Полный billboard с наклоном (следит за камерой со всех сторон)
	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 look_dir = normalize(camera_pos - world_pos);
	vec3 up = vec3(0.0, 1.0, 0.0);
	// Если смотрим строго вверх/вниз, меняем опорный up, чтобы избежать глюков
	if (abs(dot(look_dir, up)) > 0.999) {
		up = vec3(0.0, 0.0, 1.0);
	}
	vec3 right = normalize(cross(up, look_dir));
	up = normalize(cross(look_dir, right)); // пересчитываем up с наклоном
	// Сохраняем масштаб инстанса
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
	ALPHA = tex.a;
}
