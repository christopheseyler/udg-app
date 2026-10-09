class_name OptionEnumRow
extends HBoxContainer

## Ligne d'une option a choix multiples : nom, valeur courante avec des
## fleches gauche/droite pour changer (defilement en boucle) et bouton "?"
## (info) tout a droite. Le cadre de la valeur a une largeur fixe (texte trop
## long tronque) pour que les fleches ne bougent pas d'une valeur a l'autre.
## Appeler setup() une fois la ligne ajoutee a l'arbre :
## {"id": String, "name": String, "items": Array[String],
##  "default": String (un des items, sinon le premier), "info": String}

signal value_changed(id: String, value: String)
signal info_requested(option_name: String, info: String)

@onready var name_label: Label = $NameLabel
@onready var prev_button: Button = $PrevButton
@onready var value_label: Label = $ValueLabel
@onready var next_button: Button = $NextButton
@onready var info_button: Button = $InfoButton

var option_id := ""
var _option_name := ""
var _info := ""
var _items: Array[String] = []
var _index := 0

func setup(option: Dictionary) -> void:
	option_id = option["id"]
	_option_name = option["name"]
	_info = option.get("info", "")
	_items.assign(option["items"])
	_index = maxi(_items.find(option.get("default", "")), 0)

	name_label.text = _option_name
	info_button.disabled = _info.is_empty()
	prev_button.disabled = _items.size() <= 1
	next_button.disabled = _items.size() <= 1
	_update_label()

	for button in [prev_button, next_button, info_button]:
		PressScale.attach(button)
	prev_button.pressed.connect(func(): _step(-1))
	next_button.pressed.connect(func(): _step(1))
	info_button.pressed.connect(func(): info_requested.emit(_option_name, _info))

func get_value() -> String:
	return _items[_index] if not _items.is_empty() else ""

func _step(direction: int) -> void:
	if _items.is_empty():
		return
	_index = posmod(_index + direction, _items.size())
	_update_label()
	value_changed.emit(option_id, get_value())

func _update_label() -> void:
	value_label.text = get_value()
