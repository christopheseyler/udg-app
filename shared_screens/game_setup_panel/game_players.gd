class_name GamePlayers
extends SlidePanel

## Panneau de gestion des joueurs : bandeau titre "PLAYERS" en haut, puis un
## bouton "-" a gauche (retire le dernier joueur) et "+" a droite (ajoute un
## joueur), et la liste des joueurs en dessous ("Player #1", "Player #2", ...).
## Chaque joueur est une plaque (RowButton du theme setup_theme) avec un
## medaillon numerote a sa couleur, son nom et une icone crayon.
## Cliquer un joueur ouvre la vue d'edition de son nom.
## La liste demarre avec un joueur (minimum : MIN_PLAYERS).
## Le nombre maximum de joueurs depend du jeu selectionne : le definir via
## set_max_players() (ou l'export max_players).

signal players_changed(names: Array[String])
## Emis a l'ouverture / fermeture de la vue d'edition d'un nom : l'ecran
## parent y affiche / masque le clavier a l'ecran.
signal name_edit_opened
signal name_edit_closed

## Tous les jeux se jouent a 1 joueur minimum : la liste demarre avec un
## joueur et le bouton "-" ne descend pas en dessous.
const MIN_PLAYERS := 1

const PENCIL_SIZE := 56
const PENCIL := preload("res://assets/ui/setup/icon_pencil.png")

@export var max_players: int = 4

@onready var players_view: VBoxContainer = $Layout/Margin/PlayersView
@onready var edit_panel: PlayerEditPanel = $Layout/Margin/PlayerEditPanel
@onready var minus_button: Button = $Layout/Margin/PlayersView/Header/MinusButton
@onready var plus_button: Button = $Layout/Margin/PlayersView/Header/PlusButton
@onready var count_label: Label = $Layout/Margin/PlayersView/Header/CountLabel
@onready var player_list: VBoxContainer = $Layout/Margin/PlayersView/Scroll/ListMargin/PlayerList

var _names: Array[String] = []
var _editing_index := -1

func _ready() -> void:
	PressScale.attach(minus_button)
	PressScale.attach(plus_button)
	minus_button.pressed.connect(remove_last_player)
	plus_button.pressed.connect(add_player)
	edit_panel.name_confirmed.connect(_on_name_confirmed)
	edit_panel.cancelled.connect(_close_edit)
	_names.append(_next_default_name())
	_refresh()

func get_player_names() -> Array[String]:
	return _names.duplicate()

func add_player() -> void:
	if _names.size() >= max_players:
		return
	_names.append(_next_default_name())
	_refresh()

func remove_last_player() -> void:
	if _names.size() <= MIN_PLAYERS:
		return
	_names.pop_back()
	_refresh()

## Definit le nombre maximum de joueurs du jeu selectionne. Si la liste
## depasse la nouvelle limite, les derniers joueurs sont retires.
func set_max_players(value: int) -> void:
	max_players = maxi(value, 1)
	while _names.size() > max_players:
		_names.pop_back()
	if _editing_index >= _names.size():
		_close_edit()
	_refresh()

func _next_default_name() -> String:
	var n := 1
	while ("Player #%d" % n) in _names:
		n += 1
	return "Player #%d" % n

func _refresh() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for i in _names.size():
		player_list.add_child(_make_row(i))

	count_label.text = "%d / %d" % [_names.size(), max_players]
	minus_button.disabled = _names.size() <= MIN_PLAYERS
	plus_button.disabled = _names.size() >= max_players
	players_changed.emit(get_player_names())

## Ligne d'un joueur : plaque cliquable contenant medaillon, nom et crayon.
func _make_row(index: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"RowButton"
	button.custom_minimum_size = Vector2(0, 90)
	button.pressed.connect(_open_edit.bind(index))
	PressScale.attach(button)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -24
	content.add_theme_constant_override("separation", 24)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var medallion := UiKit.medallion(index, index + 1)
	content.add_child(medallion)

	var name_label := Label.new()
	name_label.text = _names[index]
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)

	content.add_child(UiKit.image(PENCIL, PENCIL_SIZE))
	for child in content.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button

func _open_edit(index: int) -> void:
	_editing_index = index
	players_view.visible = false
	edit_panel.visible = true
	edit_panel.open(_names[index])
	name_edit_opened.emit()

func _close_edit() -> void:
	_editing_index = -1
	edit_panel.visible = false
	players_view.visible = true
	name_edit_closed.emit()

func _on_name_confirmed(new_name: String) -> void:
	if _editing_index >= 0 and _editing_index < _names.size():
		_names[_editing_index] = new_name
	_close_edit()
	_refresh()
