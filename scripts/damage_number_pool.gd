extends Node
## Автолоад. Пул объектов для DamageNumber (аналогично AudioManager):
## - переиспользует ноды вместо create/queue_free на каждый хит
## - ограничивает максимум одновременных цифр (voice stealing)
## - опционально "стэкает" урон по одной цели в короткое окно времени,
##   чтобы дробовик/очередь не плодили по 8 цифр за 100мс
##
## Ноды создаются напрямую в коде (Label3D + set_script), поэтому
## отдельная .tscn-сцена не нужна. Если у вас уже есть готовая сцена
## с настроенным Label3D — см. комментарий внизу файла, как её
## подставить вместо этого.

const DamageNumberScript := preload("res://scripts/damage_number.gd")

@export var prewarm_count: int = 20
@export var max_concurrent: int = 40

# --- ВКЛ/ВЫКЛ ЦИФР УРОНА (настройка из меню паузы) ---
# ПО УМОЛЧАНИЮ ВЫКЛЮЧЕНО!
var numbers_enabled: bool = false

# --- СТЭКИНГ УРОНА ---
# Если два хита по одному и тому же target_id прилетают в течение
# stack_window_ms — они суммируются в одну цифру вместо двух отдельных.
@export var stack_window_ms: int = 80

var _pool: Array[Label3D] = []
var _all: Array[Label3D] = []
var _active_count: int = 0

# target_id -> {label: Label3D, damage: int, time: int}
var _stack_map: Dictionary = {}


func _ready() -> void:
	for i in range(prewarm_count):
		var inst := _make_instance()
		add_child(inst)
		inst.visible = false
		_pool.append(inst)
		_all.append(inst)


func _make_instance() -> Label3D:
	var inst := Label3D.new()
	inst.set_script(DamageNumberScript)
	return inst


func set_numbers_enabled(value: bool) -> void:
	print("🔧 set_numbers_enabled вызван! value = ", value)  # ОТЛАДКА
	numbers_enabled = value
	if not value:
		# Прячем все уже активные цифры сразу, чтобы выключение
		# срабатывало мгновенно, а не только для будущих хитов.
		for n in _all:
			if n.visible:
				n.visible = false
				_release(n)
		_stack_map.clear()


func spawn(damage: int, world_position: Vector3, is_chain: bool = false, target_id: int = -1) -> void:
	if not numbers_enabled:
		return

	# --- Стэкинг: если недавно уже был хит по этой же цели, просто
	# обновляем число на существующей цифре вместо спавна новой. ---
	if target_id != -1 and _stack_map.has(target_id):
		var entry: Dictionary = _stack_map[target_id]
		var now := Time.get_ticks_msec()
		if now - entry.time < stack_window_ms and is_instance_valid(entry.label):
			entry.damage += damage
			entry.time = now
			entry.label.text = str(entry.damage)
			entry.label.call("_animate")  # небольшой повторный "поп"
			return

	var label := _get_free_label()
	if label == null:
		return  # лимит достигнут и красть не у кого — пропускаем этот хит

	label.call("init", damage, world_position, is_chain, Callable(self, "_release"))
	_active_count += 1

	if target_id != -1:
		_stack_map[target_id] = {"label": label, "damage": damage, "time": Time.get_ticks_msec()}


func _get_free_label() -> Label3D:
	if not _pool.is_empty():
		return _pool.pop_back()

	if _all.size() < max_concurrent:
		var inst := _make_instance()
		add_child(inst)
		_all.append(inst)
		return inst

	# Лимит достигнут — крадём самый старый активный лейбл.
	for n in _all:
		if n.visible:
			return n
	return null


func _release(label: Label3D) -> void:
	_active_count = max(0, _active_count - 1)
	if not _pool.has(label):
		_pool.append(label)
	# Чистим устаревшие записи стэкинга, указывающие на этот лейбл.
	for key in _stack_map.keys():
		if _stack_map[key].label == label:
			_stack_map.erase(key)
