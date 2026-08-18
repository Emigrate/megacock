extends Node
## Менеджер апгрейдов (синглтон)

signal upgrades_offered(upgrade_list)

var all_upgrades = []

func _ready():
	print("🟢 UpgradeManager _ready() сработал!")
	_register_upgrades()

func _register_upgrades():
	# ========================================
	# 1. CHAIN REACTION (было "Цепная реакция")
	# ========================================
	var chain_up = UpgradeData.new()
	chain_up.upgrade_name = "Chain Reaction"
	chain_up.description = "Bullets bounce to the nearest enemy +1 time"
	chain_up.apply_func = func(_player):
		_player.chain_count += 1
		print("⚡ Chain increased! Total bounces: ", _player.chain_count)
	all_upgrades.append(chain_up)

func offer_upgrades():
	print("🟡 offer_upgrades() вызван!")
	if all_upgrades.is_empty():
		return

	var pool = all_upgrades.duplicate()
	pool.shuffle()
	var chosen = pool.slice(0, 4)
	print("🛠️ Предлагаются апгрейды: ", chosen.map(func(u): return u.upgrade_name))
	upgrades_offered.emit(chosen)
