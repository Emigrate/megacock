extends Node
## Менеджер апгрейдов (синглтон)

signal upgrades_offered(upgrade_list)

var all_upgrades = []

func _ready():
	print("🟢 UpgradeManager _ready() сработал!")
	_register_upgrades()

func _register_upgrades():
	# ========================================
	# 1. CHAIN REACTION (Легендарный)
	# ========================================
	var chain_up = UpgradeData.new()
	chain_up.upgrade_name = "Chain Reaction"
	chain_up.description = "Bullets bounce to the nearest enemy +1 time"
	chain_up.rarity = "Legendary"
	chain_up.apply_func = func(_player):
		_player.chain_count += 1
		print("⚡ Chain increased! Total bounces: ", _player.chain_count)
	all_upgrades.append(chain_up)

	# ========================================
	# 2. AUTO SHOT (Тоже Легендарный)
	# ========================================
	var auto_up = UpgradeData.new()
	auto_up.upgrade_name = "Auto Shot"
	auto_up.description = "Fires 1 auto-bullet per second at nearest enemy"
	auto_up.rarity = "Legendary"
	auto_up.apply_func = func(_player):
		_player.auto_shots += 1
		_player.auto_shot_damage += 15
		_player.reduce_auto_shot_interval(0.1)  # уменьшаем интервал на 0.1 сек
		print("🔫 Auto Shot increased! Shots: ", _player.auto_shots, " | Damage: ", _player.auto_shot_damage)
	all_upgrades.append(auto_up)

func offer_upgrades():
	print("🟡 offer_upgrades() вызван!")
	if all_upgrades.is_empty():
		return

	var pool = all_upgrades.duplicate()
	pool.shuffle()
	var chosen = pool.slice(0, 4)
	print("🛠️ Предлагаются апгрейды: ", chosen.map(func(u): return u.upgrade_name))
	upgrades_offered.emit(chosen)
