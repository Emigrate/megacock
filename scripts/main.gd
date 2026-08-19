extends Node3D

@onready var mob_spawn = $MobSpawn
@onready var ghoul_swarm = $GhoulSwarm

func _ready() -> void:
	if mob_spawn and ghoul_swarm:
		mob_spawn.set_ghoul_swarm(ghoul_swarm)
		print("✅ MobSpawn и GhoulSwarm соединены! Урон будет работать.")
	else:
		push_error("❌ Ошибка: Не найден MobSpawn или GhoulSwarm в дереве сцены!")
