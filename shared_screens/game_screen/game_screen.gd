class_name GameScreen
extends Control

## Template des ecrans de jeu. Bandeau inferieur (Back avec confirmation,
## Cancel hit, Next player), panneau lateral droit (valeurs des jets en haut,
## fleches restantes en bas) et zone de score libre pour le panneau propre au
## jeu (set_score_panel()). Un jeu herite de cette scene ; le template gere
## les jets du tour en cours et signale les actions du joueur :
## - add_throw() enregistre la valeur d'un jet (ex. "T20", "25", "Miss") ;
## - throw_cancelled est emis avec la valeur retiree par Cancel hit ;
## - set_round() met a jour le numero de round affiche ;
## - next_player_requested est emis par Next player, puis le tour est remis
##   a zero ;
## - back_confirmed est emis quand le joueur confirme la sortie du jeu.

signal back_confirmed
signal throw_cancelled(value: String)
signal next_player_requested

const DART_TEXTURE := preload("res://assets/dart.png")
const EMPTY_THROW_TEXT := "-"
const THROW_FONT_SIZE := 64
const DART_ICON_SIZE := Vector2(0, 192)

@export var darts_per_turn: int = 3:
	set(value):
		darts_per_turn = maxi(value, 1)
		if is_node_ready():
			_build_slots()

@onready var score_area: Control = $ScoreArea
@onready var back_button: Button = $BottomBar/Margin/Buttons/BackButton
@onready var cancel_hit_button: Button = $BottomBar/Margin/Buttons/CancelHitButton
@onready var next_player_button: Button = $BottomBar/Margin/Buttons/NextPlayerButton
@onready var round_label: Label = $SidePanel/Margin/Content/RoundLabel
@onready var throws_list: VBoxContainer = $SidePanel/Margin/Content/ThrowsList
@onready var darts_list: HBoxContainer = $SidePanel/Margin/Content/DartsList
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var stay_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/StayButton
@onready var leave_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/LeaveButton

var round_number := 1

var _throws: Array[String] = []
var _throw_labels: Array[Label] = []
var _dart_icons: Array[TextureRect] = []

func _ready() -> void:
	back_button.pressed.connect(func(): confirm_overlay.visible = true)
	stay_button.pressed.connect(func(): confirm_overlay.visible = false)
	leave_button.pressed.connect(_on_leave_pressed)
	cancel_hit_button.pressed.connect(cancel_last_throw)
	next_player_button.pressed.connect(_on_next_player_pressed)
	_build_slots()

## Prepare l'ecran pour une partie : joueurs dans l'ordre de passage et
## options choisies dans l'ecran de selection. A surcharger par chaque jeu.
func setup(_players: Array[String], _options: Dictionary) -> void:
	pass

## Place le panneau de score du jeu dans la zone dediee (il en remplit tout
## l'espace). Remplace le panneau precedent s'il y en avait un.
func set_score_panel(panel: Control) -> void:
	for child in score_area.get_children():
		score_area.remove_child(child)
		child.queue_free()
	score_area.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Definit le numero du round affiche en haut du panneau lateral. C'est au
## jeu de l'appeler quand tous les joueurs ont joue.
func set_round(number: int) -> void:
	round_number = maxi(number, 1)
	round_label.text = "Round #%d" % round_number

func get_throws() -> Array[String]:
	return _throws.duplicate()

func get_remaining_darts() -> int:
	return darts_per_turn - _throws.size()

## Enregistre un jet du tour en cours. Retourne false si les fleches du tour
## sont deja toutes lancees.
func add_throw(value: String) -> bool:
	if get_remaining_darts() <= 0:
		return false
	_throws.append(value)
	_refresh()
	return true

## Retire le dernier jet du tour en cours (bouton Cancel hit).
func cancel_last_throw() -> void:
	if _throws.is_empty():
		return
	var value: String = _throws.pop_back()
	_refresh()
	throw_cancelled.emit(value)

## Efface les jets du tour (debut du tour du joueur suivant).
func reset_turn() -> void:
	_throws.clear()
	_refresh()

func _on_next_player_pressed() -> void:
	next_player_requested.emit()
	reset_turn()

func _on_leave_pressed() -> void:
	confirm_overlay.visible = false
	back_confirmed.emit()

func _build_slots() -> void:
	for child in throws_list.get_children():
		throws_list.remove_child(child)
		child.queue_free()
	for child in darts_list.get_children():
		darts_list.remove_child(child)
		child.queue_free()
	_throw_labels.clear()
	_dart_icons.clear()

	for i in darts_per_turn:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", THROW_FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		throws_list.add_child(label)
		_throw_labels.append(label)

		var icon := TextureRect.new()
		icon.texture = DART_TEXTURE
		icon.custom_minimum_size = DART_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		darts_list.add_child(icon)
		_dart_icons.append(icon)

	_refresh()

func _refresh() -> void:
	var remaining := get_remaining_darts()
	for i in darts_per_turn:
		var thrown := i < _throws.size()
		_throw_labels[i].text = _throws[i] if thrown else EMPTY_THROW_TEXT
		_throw_labels[i].modulate.a = 1.0 if thrown else 0.35
		# Les icones restent en place pour garder la mise en page : seules
		# les fleches restantes sont visibles.
		_dart_icons[i].modulate.a = 1.0 if i < remaining else 0.0
	cancel_hit_button.disabled = _throws.is_empty()
