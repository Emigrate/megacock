shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2DArray tex_array : source_color, filter_nearest;
uniform float frame_count = 15.0;

void vertex() {
	// Цилиндрический биллборд: спрайт всегда стоит вертикально,
	// разворачивается к камере только по горизонтали
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

	// Сохраняем масштаб инстанса (из MODEL_MATRIX), применённый через
	// multimesh instance transform, чтобы scale jitter из GDScript работал
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
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	if (ALPHA < 0.5) discard;

	// Затемнение по дистанции до камеры — визуально разделяет слои
	// толпы (ближние ярче, дальние темнее), помогает глазу читать глубину
	float dist = length(VERTEX);
	float fade = clamp(1.0 - (dist - 5.0) / 40.0, 0.35, 1.0);
	ALBEDO *= fade;
}