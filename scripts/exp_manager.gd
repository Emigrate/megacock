extends Node

signal exp_changed(current_exp: int, exp_needed: int)
signal level_up(new_level: int)

var current_exp: int = 0
var exp_to_next_level: int = 100
var level: int = 1
const EXP_MULTIPLIER = 2.0

func _ready():
	exp_changed.emit(current_exp, exp_to_next_level)

func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	
	current_exp += amount
	
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		exp_to_next_level = int(exp_to_next_level * EXP_MULTIPLIER)
		level_up.emit(level)
		
		# === ВЫЗОВ МЕНЕДЖЕРА АПГРЕЙДОВ ===
		UpgradeManager.offer_upgrades()
		# =====================================
	
	exp_changed.emit(current_exp, exp_to_next_level)
