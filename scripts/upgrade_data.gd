extends Resource
class_name UpgradeData

@export var upgrade_name: String = "Апгрейд"
@export var description: String = "Описание"
@export var icon: Texture2D = null

var apply_func: Callable = func(_player): pass
