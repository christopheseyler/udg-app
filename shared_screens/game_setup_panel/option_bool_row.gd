class_name OptionBoolRow
extends HBoxContainer

## Ligne d'une option booleenne : nom, curseur on/off et bouton "?" (info).
## Appeler setup() une fois la ligne ajoutee a l'arbre avec un dictionnaire :
## {"id": String, "name": String, "default": bool, "info": String}

signal value_changed(id: String, value: bool)
signal info_requested(option_name: String, info: String)

@onready var name_label: Label = $NameLabel
@onready var toggle: CheckButton = $Toggle
@onready var info_button: Button = $InfoButton

var option_id := ""
var _option_name := ""
var _info := ""

func setup(option: Dictionary) -> void:
	option_id = option["id"]
	_option_name = option["name"]
	_info = option.get("info", "")
	name_label.text = _option_name
	toggle.set_pressed_no_signal(option.get("default", false))
	info_button.disabled = _info.is_empty()

	toggle.toggled.connect(func(pressed: bool): value_changed.emit(option_id, pressed))
	info_button.pressed.connect(func(): info_requested.emit(_option_name, _info))

func get_value() -> bool:
	return toggle.button_pressed
