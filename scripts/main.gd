extends Node3D

@onready var mob_spawn = $MobSpawn
@onready var ghoul_swarm = $GhoulSwarm
@onready var demon_swarm = $WrathDemonSwarm
@onready var skeleton_swarm = $SkeletonSwarm  # <-- добавлено

func _ready() -> void:
	# Подключаем гулей
	if mob_spawn and ghoul_swarm:
		mob_spawn.set_ghoul_swarm(ghoul_swarm)
		print("✅ MobSpawn и GhoulSwarm соединены! Урон будет работать.")
	else:
		push_error("❌ Ошибка: Не найден MobSpawn или GhoulSwarm в дереве сцены!")

	# Подключаем демонов
	if mob_spawn and demon_swarm:
		mob_spawn.set_demon_swarm(demon_swarm)
		print("✅ MobSpawn и DemonSwarm соединены! Демоны будут спавниться.")
	else:
		push_error("❌ Ошибка: Не найден MobSpawn или DemonSwarm в дереве сцены!")

	# Подключаем скелетов
	if mob_spawn and skeleton_swarm:
		mob_spawn.set_skeleton_swarm(skeleton_swarm)
		print("✅ MobSpawn и SkeletonSwarm соединены! Скелеты будут спавниться.")
	else:
		push_error("❌ Ошибка: Не найден MobSpawn или SkeletonSwarm в дереве сцены!")
