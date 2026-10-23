class_name PlayerDatabasePanel
extends VBoxContainer

## Vue de la base des joueurs inscrits (PlayerDatabase) : liste des joueurs
## (photo, nom, boutons d'edition et de suppression), bouton "+" pour en
## inscrire un et bouton Back. Cliquer un joueur le selectionne pour la place
## en cours d'edition (player_selected) ; le bouton crayon ouvre son profil
## (profile_requested).
## La suppression demande une confirmation : le bouton "-" de la ligne se
## change en bouton rouge "Delete" a toucher une seconde fois.

signal back_pressed
signal add_pressed
signal player_selected(player_name: String)
signal profile_requested(id: String)

const PHOTO_SIZE := 80
const PENCIL := preload("res://assets/ui/setup/icon_pencil.png")

@onready var count_label: Label = $Header/CountLabel
@onready var plus_button: Button = $Header/PlusButton
@onready var player_list: VBoxContainer = $Scroll/ListMargin/PlayerList
@onready var empty_label: Label = $Scroll/ListMargin/PlayerList/EmptyLabel
@onready var back_button: Button = $Buttons/BackButton

func _ready() -> void:
	PressScale.attach(plus_button)
	PressScale.attach(back_button)
	plus_button.pressed.connect(func(): add_pressed.emit())
	back_button.pressed.connect(func(): back_pressed.emit())
	PlayerDatabase.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for child in player_list.get_children():
		if child != empty_label:
			child.queue_free()
	var players := PlayerDatabase.get_players()
	for player in players:
		player_list.add_child(_make_row(player))
	empty_label.visible = players.is_empty()
	count_label.text = "%d registered" % players.size()

## Ligne d'un joueur : plaque cliquable (photo + nom), puis boutons
## d'edition du profil et de suppression a droite.
func _make_row(player: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var button := Button.new()
	button.theme_type_variation = &"RowButton"
	button.custom_minimum_size = Vector2(0, 90)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): player_selected.emit(player.name))
	PressScale.attach(button)
	row.add_child(button)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -24
	content.add_theme_constant_override("separation", 24)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	content.add_child(PlayerProfilePanel.photo_thumbnail(player.id, PHOTO_SIZE))

	var name_label := Label.new()
	name_label.text = player.name
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var edit_button := Button.new()
	edit_button.theme_type_variation = &"PillButton"
	edit_button.custom_minimum_size = Vector2(140, 90)
	edit_button.tooltip_text = "Edit profile"
	edit_button.pressed.connect(func(): profile_requested.emit(player.id))
	var pencil := CenterContainer.new()
	pencil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pencil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pencil.add_child(UiKit.image(PENCIL, 56))
	edit_button.add_child(pencil)
	PressScale.attach(edit_button)
	row.add_child(edit_button)

	var delete_button := Button.new()
	delete_button.theme_type_variation = &"RoundMinusButton"
	delete_button.custom_minimum_size = Vector2(80, 80)
	delete_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PressScale.attach(delete_button)
	row.add_child(delete_button)

	var confirm_button := Button.new()
	confirm_button.theme_type_variation = &"PillButtonRed"
	confirm_button.custom_minimum_size = Vector2(240, 90)
	confirm_button.text = "Delete"
	confirm_button.visible = false
	confirm_button.pressed.connect(func(): PlayerDatabase.remove_player(player.id))
	PressScale.attach(confirm_button)
	row.add_child(confirm_button)

	delete_button.pressed.connect(func():
		delete_button.visible = false
		confirm_button.visible = true)
	return row
