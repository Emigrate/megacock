extends Node3D

@export var damage := 50.0
@export var attack_range := 5
@export var attack_cooldown := 0.25
@export var anim_player: AnimationPlayer
@export var hit_timing := 0.3155
@export var is_auto := false

var can_attack := true
var _is_animating := false
var _bob_x := 0.0
var _bob_y := 0.0
var _bob_moving := false
var _yaw_input := 0.0
var _lean_cur := 0.0
var _original_position := Vector3.ZERO
var _original_rotation := Vector3.ZERO
var _damage_dealt := false


func _ready() -> void:
	_original_position = position
	_original_rotation = rotation

	if anim_player == null:
		anim_player = _find_animation_player(self)
		if anim_player == null:
			print("⚠️ AnimationPlayer не найден!")
		else:
			print("✅ AnimationPlayer найден!")
	
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")


func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null


func set_bob(bob_x: float, bob_y: float, moving: bool) -> void:
	_bob_x = bob_x
	_bob_y = bob_y
	_bob_moving = moving


func set_yaw_input(yaw: float) -> void:
	_yaw_input = yaw


func _process(delta: float) -> void:
	if not _is_animating:
		var bob_offset: Vector3 = Vector3(_bob_x * 0.05, _bob_y * 0.03, 0)
		position = _original_position + bob_offset
		
		_lean_cur = lerp(_lean_cur, clampf(-_yaw_input * 0.08, -0.15, 0.15), 1.0 - exp(-8.0 * delta))
		rotation.z = _original_rotation.z + _lean_cur
	_yaw_input = 0.0


func try_fire() -> bool:
	if not can_attack:
		return false
	if _is_animating:
		return false
	
	can_attack = false
	get_tree().create_timer(attack_cooldown).timeout.connect(func():
		can_attack = true)
	
	_damage_dealt = false
	
	if anim_player and anim_player.has_animation("attack"):
		anim_player.stop()
		var attack_anim: Animation = anim_player.get_animation("attack")
		if attack_anim:
			attack_anim.loop_mode = Animation.LOOP_NONE
		_is_animating = true
		anim_player.play("attack")
		
		# --- ЗВУК ЗАМАХА (2D, на шину Shots) ---
		AudioManager.play_axe_swing_2d()
		
		await get_tree().create_timer(hit_timing).timeout
		if not _damage_dealt and _is_animating:
			_deal_damage()
		
		var duration: float = attack_anim.length if attack_anim else 0.5
		await get_tree().create_timer(duration - hit_timing).timeout
		if anim_player.is_playing():
			anim_player.stop()
		
		_is_animating = false
		position = _original_position
		rotation = _original_rotation
		
		if anim_player and anim_player.has_animation("idle"):
			anim_player.play("idle")
	else:
		_deal_damage()
	
	return true


func _deal_damage() -> void:
	if _damage_dealt:
		return
	var cam: Camera3D = get_parent() as Camera3D
	if cam:
		var count = SwarmManager.melee_splash(cam.global_position, attack_range, int(damage))
		if count > 0:
			_damage_dealt = true
			# Можно добавить звук попадания, если есть
