class_name PlayersOrderScreen
extends Control

## Ecran d'ordre de passage : invite tous les joueurs a lancer une fleche au
## plus pres du centre de la cible, puis permet de reordonner la liste a la
## main (boutons haut / bas) selon le resultat : la liste va du plus proche
## au plus loin. Le premier de la liste joue en premier, sauf avec
## set_reverse_order(true) (le plus proche joue alors en dernier). Alimenter
## la liste via set_players(), recuperer l'ordre de jeu via le signal
## order_confirmed (ou get_player_names()).
## Chaque ligne est une plaque du kit UI : medaillon a la couleur du joueur
## (celle de son rang dans la configuration) portant son rang actuel, nom et
## fleches haut / bas.

signal order_confirmed(names: Array[String])
signal back_pressed

const ROW_HEIGHT := 90
const ROW_FONT_SIZE := 44
const MOVE_BUTTON_SIZE := 88
const INSTRUCTION := "Each player throws one dart as close to the bullseye as possible. The closest goes first: reorder the list below with the arrows."
const REVERSE_INSTRUCTION := "Each player throws one dart as close to the bullseye as possible. Order the list below from the closest to the farthest with the arrows: the closest goes last."

@onready var instruction_label: Label = $Panel/Layout/Content/InstructionLabel
@onready var player_list: VBoxContainer = $Panel/Layout/Content/Scroll/ListMargin/PlayerList
@onready var back_button: Button = $Panel/Layout/Content/Buttons/BackButton
@onready var confirm_button: Button = $Panel/Layout/Content/Buttons/ConfirmButton

var _names: Array[String] = []
## Rang de chaque joueur dans la configuration (couleur de son medaillon),
## deplace avec son nom.
var _player_indexes: Array[int] = []
var _reverse_order := false

func _ready() -> void:
	PressScale.attach(back_button)
	PressScale.attach(confirm_button)
	back_button.pressed.connect(func(): back_pressed.emit())
	confirm_button.pressed.connect(func(): order_confirmed.emit(get_player_names()))
	_refresh()

func set_players(names: Array[String]) -> void:
	_names = names.duplicate()
	_player_indexes.clear()
	for i in _names.size():
		_player_indexes.append(i)
	_refresh()

## Ordre inverse (jeux ou le plus proche du centre joue en dernier) : la
## liste reste classee du plus proche au plus loin, seul l'ordre de jeu
## renvoye est inverse.
func set_reverse_order(reverse: bool) -> void:
	_reverse_order = reverse
	instruction_label.text = REVERSE_INSTRUCTION if reverse else INSTRUCTION

## Ordre de jeu (voir set_reverse_order).
func get_player_names() -> Array[String]:
	var names := _names.duplicate()
	if _reverse_order:
		names.reverse()
	return names

## Decale le joueur a l'index donne de `direction` places (-1 = plus tot,
## +1 = plus tard). Sans effet aux extremites de la liste.
func move_player(index: int, direction: int) -> void:
	var target := index + direction
	if index < 0 or index >= _names.size() or target < 0 or target >= _names.size():
		return
	var moved := _names[index]
	_names[index] = _names[target]
	_names[target] = moved
	var moved_index := _player_indexes[index]
	_player_indexes[index] = _player_indexes[target]
	_player_indexes[target] = moved_index
	_refresh()

func _refresh() -> void:
	for child in player_list.get_children():
		player_list.remove_child(child)
		child.queue_free()

	for i in _names.size():
		player_list.add_child(_build_row(i))

	confirm_button.disabled = _names.is_empty()

func _build_row(index: int) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"RowPlate"
	plate.custom_minimum_size = Vector2(0, ROW_HEIGHT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	plate.add_child(row)

	var player_index := _player_indexes[index] if index < _player_indexes.size() else index
	row.add_child(UiKit.medallion(player_index, index + 1))

	var name_label := Label.new()
	name_label.text = _names[index]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	var up := _build_move_button(&"RoundUpButton", index == 0)
	up.pressed.connect(move_player.bind(index, -1))
	row.add_child(up)

	var down := _build_move_button(&"RoundDownButton", index == _names.size() - 1)
	down.pressed.connect(move_player.bind(index, 1))
	row.add_child(down)

	return plate

func _build_move_button(variation: StringName, disabled: bool) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.disabled = disabled
	button.custom_minimum_size = Vector2(MOVE_BUTTON_SIZE, MOVE_BUTTON_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PressScale.attach(button)
	return button
