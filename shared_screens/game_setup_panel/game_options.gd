class_name GameOptions
extends SlidePanel

## Panneau des options d'un jeu. Les options sont fournies par set_options()
## sous forme de dictionnaires, de trois types :
##   {"type": "group", "name": "Scoring"}  (titre de groupe + ligne dessous,
##    sans valeur ; il introduit les options qui le suivent)
##   {"id": "double_out", "type": "bool", "name": "Double out",
##    "default": true, "info": "Texte d'aide"}
##   {"id": "legs", "type": "enum", "name": "Legs",
##    "items": ["1", "3", "5"], "default": "3", "info": "Texte d'aide"}
## Chaque option a un bouton "?" qui remplace la liste par son texte d'aide.
## get_values() renvoie {id: valeur} (bool ou String pour les enums).

signal options_changed(values: Dictionary)

const GROUP_TITLE := preload("res://shared_screens/game_setup_panel/option_group_title.tscn")
const BOOL_ROW := preload("res://shared_screens/game_setup_panel/option_bool_row.tscn")
const ENUM_ROW := preload("res://shared_screens/game_setup_panel/option_enum_row.tscn")

@onready var options_view: VBoxContainer = $Margin/OptionsView
@onready var option_list: VBoxContainer = $Margin/OptionsView/Scroll/OptionList
@onready var info_view: VBoxContainer = $Margin/InfoView
@onready var info_title: Label = $Margin/InfoView/InfoTitle
@onready var info_text: Label = $Margin/InfoView/InfoText
@onready var close_button: Button = $Margin/InfoView/CloseButton

var _elements: Array[Control] = []
var _rows: Array[Control] = []

func _ready() -> void:
	close_button.pressed.connect(_close_info)

func set_options(options: Array) -> void:
	_close_info()
	for element in _elements:
		option_list.remove_child(element)
		element.queue_free()
	_elements.clear()
	_rows.clear()

	for option: Dictionary in options:
		var element: Control
		match option.get("type", ""):
			"group":
				element = GROUP_TITLE.instantiate()
			"bool":
				element = BOOL_ROW.instantiate()
			"enum":
				element = ENUM_ROW.instantiate()
			_:
				push_warning("Option '%s' ignoree : type inconnu '%s'" % [option.get("id", option.get("name", "?")), option.get("type", "")])
				continue
		option_list.add_child(element)
		element.setup(option)
		_elements.append(element)

		if option["type"] != "group":
			element.value_changed.connect(func(_id, _value): options_changed.emit(get_values()))
			element.info_requested.connect(_show_info)
			_rows.append(element)

func get_values() -> Dictionary:
	var values := {}
	for row in _rows:
		values[row.option_id] = row.get_value()
	return values

func _show_info(option_name: String, info: String) -> void:
	info_title.text = option_name
	info_text.text = info
	options_view.visible = false
	info_view.visible = true

func _close_info() -> void:
	info_view.visible = false
	options_view.visible = true
