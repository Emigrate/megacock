extends CharacterBody3D

@export var move_speed: float = 23.0
@export var gravity: float = 65.0
@export var jump_velocity: float = 20.0
@export var jump_forward := 6.0
@export var mouse_sensitivity: float = 0.001
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_interp_speed: float = 8.0

@export var dash_speed: float = 70.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.8
@export var dash_fov: float = -10.0

@export var strafe_follow := 6.0
@export var air_accel := 45.0
@export var strafe_side := 0.5

@export var noclip_speed := 35.0
@export var max_hp := 100

# --- РОСТ ПЕРСОНАЖА ---
@export var stand_height: float = 2.5
@export var crouch_height: float = 1.5

var hp := max_hp

@onready var camera: Camera3D = $Head/CameraShake/Camera3D
@onready var camera_shake: Node3D = $Head/CameraShake
@onready var collision: CollisionShape3D = $CollisionShape3D

var pitch: float = 0.0
var current_height: float = stand_height
var target_height: float = stand_height
var is_crouching: bool = false

var bob_time := 0.0
var bob_amp := 0.08
var stand_check := CapsuleShape3D.new()

var _dash_ready := true
var _dash_timer := 0.0
var _fov_shift := 0.0
var _base_fov := 90.0

var _crosshair_visible := false
var _noclip := false

var _step_timer := 0.0
var _step_interval := 0.4
var _was_in_air := false

# --- ОРУЖИЕ (4 слота) ---
var _weapons: Array = []
var _current_weapon_index := 0
var _current_weapon_is_auto := false

# --- ПАУЗА ---
var _pause_layer: CanvasLayer
var _pause_visible := false
var _animation_players: Array = []
var _fov_slider: HSlider
var _fov_value_label: Label

# --- НАСТРОЙКИ ОТДАЧИ ---
@export var recoil_z_multiplier := 3.0
@export var recoil_z_decay := 6.0
@export var fov_shake_multiplier := 1.0
@export var fov_shake_decay := 15.0

var _recoil_z := 0.0
var _fov_shake := 0.0

# ===== АПГРЕЙДЫ =====
var chain_count: int = 0   # Количество отскоков пули (апгрейд "Цепь")
# Здесь позже можно добавить другие переменные: damage_multiplier, magnet_radius, etc.
# ====================


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = stand_height
	collision.shape = capsule
	collision.position.y = stand_height * 0.5

	stand_check.radius = 0.5
	stand_check.height = stand_height

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	add_to_group("player")
	_base_fov = 90.0
	camera.fov = _base_fov

	# --- ЗАГРУЗКА ОРУЖИЯ (4 слота) ---

	# 1. Пистолет
	var pistol = null
	var pistol_scene = load("res://scenes/weapons/pistol.tscn")
	if pistol_scene != null:
		pistol = pistol_scene.instantiate()
		pistol.name = "Pistol"
		if pistol.get_script() == null:
			var script = load("res://scripts/pistol.gd")
			if script:
				pistol.set_script(script)
		if pistol.get_parent() != camera:
			camera.add_child(pistol)
		print("✅ Пистолет загружен")
	else:
		print("⚠️ pistol.tscn не найден, создаю заглушку.")
		pistol = Node3D.new()
		pistol.name = "Pistol"
		var script = load("res://scripts/pistol.gd")
		if script:
			pistol.set_script(script)
		pistol.position = Vector3(0.4, -0.5, -0.5)
		camera.add_child(pistol)

	# 2. Топор
	var axe = null
	var axe_scene = load("res://scenes/weapons/axe.tscn")
	if axe_scene != null:
		axe = axe_scene.instantiate()
		axe.name = "Axe"
		if axe.get_script() == null:
			var script = load("res://scripts/axe.gd")
			if script:
				axe.set_script(script)
		if axe.get_parent() != camera:
			camera.add_child(axe)
		print("✅ Топор загружен")
	else:
		print("⚠️ axe.tscn не найден, создаю заглушку.")
		axe = Node3D.new()
		axe.name = "Axe"
		var script = load("res://scripts/axe.gd")
		if script:
			axe.set_script(script)
		axe.position = Vector3(0.3, -0.15, -0.6)
		camera.add_child(axe)

	# 3. Калаш
	var ak = null
	var ak_scene = load("res://scenes/weapons/ak.tscn")
	if ak_scene != null:
		ak = ak_scene.instantiate()
		ak.name = "AK47"
		if ak.get_script() == null:
			var script = load("res://scripts/ak.gd")
			if script:
				ak.set_script(script)
		if ak.get_parent() != camera:
			camera.add_child(ak)
		print("✅ Калаш загружен")
	else:
		print("⚠️ ak.tscn не найден, создаю дубликат пистолета.")
		ak = pistol.duplicate()
		ak.name = "AK47"
		var script = load("res://scripts/ak.gd")
		if script:
			ak.set_script(script)
		if ak.get_parent() != camera:
			camera.add_child(ak)

	# 4. Дробовик
	var shotgun = null
	var shotgun_scene = load("res://scenes/weapons/shotgun.tscn")
	if shotgun_scene != null:
		shotgun = shotgun_scene.instantiate()
		shotgun.name = "Shotgun"
		if shotgun.get_script() == null:
			var script = load("res://scripts/shotgun.gd")
			if script:
				shotgun.set_script(script)
		if shotgun.get_parent() != camera:
			camera.add_child(shotgun)
		print("✅ Дробовик загружен")
	else:
		print("⚠️ shotgun.tscn не найден, создаю заглушку.")
		shotgun = Node3D.new()
		shotgun.name = "Shotgun"
		var script = load("res://scripts/shotgun.gd")
		if script:
			shotgun.set_script(script)
		shotgun.position = Vector3(0.5, -0.2, -0.8)
		camera.add_child(shotgun)

	_weapons = [axe, pistol, ak, shotgun]
	for w in _weapons:
		w.visible = false
	_weapons[0].visible = true
	_current_weapon_index = 0
	_current_weapon_is_auto = false

	_create_pause_ui()
	_collect_animation_players(get_tree().root)

	# --- Устанавливаем текущую высоту ---
	current_height = stand_height
	target_height = stand_height


func _collect_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		_animation_players.append(node)
	for child in node.get_children():
		_collect_animation_players(child)


func _set_animation_players_process_mode(mode: ProcessMode) -> void:
	for ap in _animation_players:
		ap.process_mode = mode


func _create_pause_ui() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 10
	add_child(_pause_layer)
	_pause_layer.visible = false

	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0.6)
	rect.size = get_viewport().get_visible_rect().size
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(rect)

	var container := VBoxContainer.new()
	container.size = Vector2(300, 200)
	container.position = (rect.size - container.size) / 2
	container.add_theme_constant_override("separation", 20)
	_pause_layer.add_child(container)

	var btn := Button.new()
	btn.text = "Продолжить"
	btn.size = Vector2(200, 60)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_unpause)
	container.add_child(btn)

	var fov_box := HBoxContainer.new()
	fov_box.size = Vector2(200, 40)
	fov_box.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(fov_box)

	var fov_label := Label.new()
	fov_label.text = "FOV:"
	fov_label.add_theme_font_size_override("font_size", 20)
	fov_label.size = Vector2(50, 40)
	fov_box.add_child(fov_label)

	_fov_slider = HSlider.new()
	_fov_slider.min_value = 85.0
	_fov_slider.max_value = 100.0
	_fov_slider.step = 1.0
	_fov_slider.value = _base_fov
	_fov_slider.size = Vector2(140, 30)
	_fov_slider.custom_minimum_size = Vector2(140, 30)
	_fov_slider.value_changed.connect(_on_fov_changed)
	fov_box.add_child(_fov_slider)

	_fov_value_label = Label.new()
	_fov_value_label.text = str(_base_fov)
	_fov_value_label.add_theme_font_size_override("font_size", 18)
	_fov_value_label.size = Vector2(40, 40)
	fov_box.add_child(_fov_value_label)

	get_viewport().size_changed.connect(_resize_pause_ui)


func _resize_pause_ui() -> void:
	if _pause_layer == null:
		return
	var rect: ColorRect = _pause_layer.get_child(0)
	if rect:
		rect.size = get_viewport().get_visible_rect().size
	var container: VBoxContainer = _pause_layer.get_child(1) if _pause_layer.get_child_count() > 1 else null
	if container:
		container.position = (rect.size - container.size) / 2


func _on_fov_changed(value: float) -> void:
	camera.fov = value
	_base_fov = value
	if _fov_value_label:
		_fov_value_label.text = str(round(value))


func _unpause() -> void:
	_toggle_pause()


func _toggle_pause() -> void:
	_pause_visible = not _pause_visible
	_pause_layer.visible = _pause_visible
	get_tree().paused = _pause_visible
	if _pause_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_set_animation_players_process_mode(PROCESS_MODE_DISABLED)
		if _fov_slider:
			_fov_slider.value = camera.fov
			if _fov_value_label:
				_fov_value_label.text = str(round(camera.fov))
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_set_animation_players_process_mode(PROCESS_MODE_INHERIT)


func _process(delta: float) -> void:
	# --- ОТДАЧА ПО Z ---
	var shake_pos := Vector3.ZERO
	if abs(_recoil_z) > 0.001:
		shake_pos.z -= _recoil_z
		_recoil_z *= exp(-recoil_z_decay * delta)
	else:
		_recoil_z = 0.0

	# --- FOV-ШЕЙК ---
	if abs(_fov_shake) > 0.001:
		_fov_shake *= exp(-fov_shake_decay * delta)
	else:
		_fov_shake = 0.0

	if camera_shake:
		camera_shake.position = shake_pos
		camera_shake.rotation = Vector3.ZERO
	else:
		print("⚠️ camera_shake узел не найден!")

	if abs(_recoil_z) <= 0.001 and abs(_fov_shake) <= 0.001:
		camera_shake.position = Vector3.ZERO


func add_camera_shake(intensity: float) -> void:
	_recoil_z = max(_recoil_z, intensity * recoil_z_multiplier)
	_fov_shake = max(_fov_shake, intensity * fov_shake_multiplier)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if _noclip:
		var fly_dir := camera.global_transform.basis.z * input_dir.y + camera.global_transform.basis.x * input_dir.x
		if Input.is_action_pressed("jump"):
			fly_dir.y += 1.0
		if Input.is_action_pressed("crouch"):
			fly_dir.y -= 1.0
		fly_dir = fly_dir.normalized()
		velocity = fly_dir * noclip_speed
		move_and_slide()
		_was_in_air = false
		return

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if Input.is_action_pressed("crouch"):
		if not is_crouching:
			is_crouching = true
			target_height = crouch_height
	else:
		if is_crouching and can_stand_up():
			is_crouching = false
			target_height = stand_height

	if _dash_timer > 0.0:
		_dash_timer -= delta
		var dash_dir := -camera.global_transform.basis.z
		velocity += dash_dir * dash_speed * delta * 2.0
		var horiz := Vector2(velocity.x, velocity.z)
		var max_speed := dash_speed * 1.8
		if horiz.length() > max_speed:
			horiz = horiz.normalized() * max_speed
			velocity.x = horiz.x
			velocity.z = horiz.y
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta

		if Input.is_action_pressed("jump") and is_on_floor():
			if is_crouching and can_stand_up():
				is_crouching = false
				target_height = stand_height
			if not is_crouching:
				velocity.y = jump_velocity
				var jump_fwd := -camera.global_transform.basis.z
				jump_fwd.y = 0.0
				jump_fwd = jump_fwd.normalized()
				velocity.x += jump_fwd.x * jump_forward
				velocity.z += jump_fwd.z * jump_forward

		if not is_on_floor():
			var strafe := Input.get_axis("move_left", "move_right")
			var view_dir := Vector2(-camera.global_transform.basis.z.x, -camera.global_transform.basis.z.z)
			var side := Vector2(-view_dir.y, view_dir.x)
			var horiz := Vector2(velocity.x, velocity.z)

			if strafe != 0.0:
				var desired := (view_dir + side * strafe * strafe_side).normalized()
				if horiz.length() > 0.01:
					var diff := wrapf(desired.angle() - horiz.angle(), -PI, PI)
					var max_turn := strafe_follow * delta
					horiz = horiz.rotated(clampf(diff, -max_turn, max_turn))
				else:
					horiz = desired * (air_accel * delta)
				horiz += side * strafe * air_accel * delta
			else:
				var base := Vector2(velocity.x, velocity.z)
				if base.length() > move_speed:
					var damp := 1.0 - exp(-3.0 * delta)
					base = base.lerp(base.normalized() * move_speed, damp)
					horiz = base

			velocity.x = horiz.x
			velocity.z = horiz.y

		var speed := move_speed
		if is_crouching:
			speed *= crouch_speed_multiplier
		var target_vel := direction * speed
		var ground_damp := -12.0 if is_on_floor() else -0.001
		velocity.x = lerpf(velocity.x, target_vel.x, 1.0 - exp(ground_damp * delta))
		velocity.z = lerpf(velocity.z, target_vel.z, 1.0 - exp(ground_damp * delta))

	current_height = move_toward(current_height, target_height, delta * crouch_interp_speed)
	collision.shape.height = current_height
	collision.position.y = current_height * 0.5

	var moving := input_dir.length() > 0.0 and is_on_floor()
	if moving and _dash_timer <= 0.0:
		bob_time += delta * 12.0
		$Head.position.y = current_height * 0.9 + sin(bob_time) * bob_amp
	else:
		bob_time = 0.0
		$Head.position.y = lerpf($Head.position.y, current_height * 0.9, 1.0 - exp(-10.0 * delta))

	_handle_steps(delta, moving)

	if _weapons.size() > 0:
		var current_weapon = _weapons[_current_weapon_index]
		if current_weapon and current_weapon.has_method("set_bob"):
			current_weapon.set_bob(sin(bob_time) * bob_amp, cos(bob_time) * bob_amp * 0.5, moving)

	var fov_damp := 1.0 - exp(-10.0 * delta)
	_fov_shift = lerpf(_fov_shift, 0.0, fov_damp)
	camera.fov = _base_fov + _fov_shift + _fov_shake

	if _current_weapon_is_auto and Input.is_action_pressed("shoot"):
		var current_weapon = _weapons[_current_weapon_index]
		if current_weapon and current_weapon.has_method("try_fire"):
			current_weapon.try_fire()

	move_and_slide()

	if _was_in_air and is_on_floor():
		AudioManager.play_land()
	_was_in_air = not is_on_floor()


func _handle_steps(delta: float, moving: bool) -> void:
	if not moving:
		_step_timer = 0.0
		return
	var horiz := Vector2(velocity.x, velocity.z).length()
	_step_interval = clampf(0.42 - horiz * 0.008, 0.18, 0.42)
	_step_timer += delta
	if _step_timer >= _step_interval:
		_step_timer = 0.0
		AudioManager.play_step()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if get_tree().paused and not _pause_visible:
			return  # игра на паузе из-за другого UI (например, апгрейда) — своё меню не трогаем
		_toggle_pause()
		return

	if get_tree().paused:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
		camera.rotation.x = pitch

		if _weapons.size() > 0:
			var current_weapon = _weapons[_current_weapon_index]
			if current_weapon and current_weapon.has_method("set_yaw_input"):
				current_weapon.set_yaw_input(event.relative.x)

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("shoot"):
		var current_weapon = _weapons[_current_weapon_index]
		if current_weapon and current_weapon.has_method("try_fire"):
			if not _current_weapon_is_auto:
				current_weapon.try_fire()

	if event.is_action_pressed("dash"):
		do_dash()

	if event.is_action_pressed("spawn_enemy"):
		spawn_enemy_at_crosshair()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Z:
				_toggle_noclip()
			KEY_X:
				_toggle_crosshair()
			KEY_1:
				_switch_weapon(0)
			KEY_2:
				_switch_weapon(1)
			KEY_3:
				_switch_weapon(2)
			KEY_4:
				_switch_weapon(3)
			KEY_R:
				print("🔴 Тестовый шейк по R!")
				add_camera_shake(2.0)


func _toggle_noclip() -> void:
	_noclip = not _noclip
	collision.disabled = _noclip
	print("🕊️ Noclip: ", "ВКЛ" if _noclip else "ВЫКЛ")


func _toggle_crosshair() -> void:
	_crosshair_visible = not _crosshair_visible
	print("🔫 Прицел: ", "ВКЛ" if _crosshair_visible else "ВЫКЛ")


func _switch_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	if _current_weapon_index == index:
		return
	_weapons[_current_weapon_index].visible = false
	_current_weapon_index = index
	_weapons[_current_weapon_index].visible = true

	var weapon = _weapons[_current_weapon_index]
	_current_weapon_is_auto = weapon.is_auto if "is_auto" in weapon else false


func do_dash() -> void:
	if not _dash_ready or _dash_timer > 0.0:
		return
	_dash_ready = false
	_dash_timer = dash_time
	_fov_shift = dash_fov

	if _weapons.size() > 0:
		var current_weapon = _weapons[_current_weapon_index]
		if current_weapon and current_weapon.has_method("set_yaw_input"):
			current_weapon.set_yaw_input(6.0)

	AudioManager.play_dash()

	get_tree().create_timer(dash_cooldown).timeout.connect(func():
		_dash_ready = true)


func can_stand_up() -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = stand_check
	query.transform = Transform3D(Basis(), Vector3(global_position.x, global_position.y + stand_height * 0.5, global_position.z))
	query.exclude = [get_rid()]
	return space.intersect_shape(query, 1).is_empty()


func take_damage(amount: float) -> void:
	hp -= int(amount)

	# --- ЗВУКИ ИГРОКА ---
	if hp <= 0:
		AudioManager.play_player_death_3d(global_position)
		hp = max_hp
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
		print("💀 Игрок умер, респавн")
	else:
		AudioManager.play_player_hurt_3d(global_position)
		print("💔 Игрок получил урон! HP: ", hp)


func spawn_enemy_at_crosshair() -> void:
	var spawn_pos := camera.global_position - camera.global_transform.basis.z * 5.0
	spawn_pos.y += 2.0
	SwarmManager.spawn(spawn_pos)


func spawn_enemy_random() -> void:
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(5.0, 15.0)
	var pos := global_position + Vector3(cos(angle) * dist, 2.0, sin(angle) * dist)
	SwarmManager.spawn(pos)	
