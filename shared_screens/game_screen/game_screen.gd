class_name GameScreen
extends Control

## Template des ecrans de jeu. Bandeau inferieur (Back avec confirmation,
## Cancel hit, Next player), panneau lateral droit (liste defilante des
## valeurs des jets en haut, fleches restantes toujours visibles en bas,
## meme si la liste des jets s'allonge) et zone de score libre pour le
## panneau propre au jeu (set_score_panel()). Un jeu herite de cette scene ;
## le template gere
## les jets du tour en cours et signale les actions du joueur :
## - add_throw() enregistre la valeur d'un jet (ex. "T20", "25", "Miss") ;
## - Cancel hit retire le dernier jet (throw_cancelled est emis avec sa
##   valeur) ; quand le tour du joueur est vide, il revient au joueur
##   precedent (previous_player_requested, puis son dernier jet est retire),
##   ce qui permet d'annuler les fleches une par une jusqu'au debut ;
## - set_round() met a jour le numero de round affiche ;
## - quand les fleches du tour sont toutes lancees, ou par Next player,
##   l'ecran "Remove your darts" (RemoveDartsScreen) s'affiche pendant
##   remove_darts_duration secondes ; ensuite next_player_requested est emis
##   et le tour est remis a zero ;
## - back_confirmed est emis quand le joueur confirme la sortie du jeu ;
## - announce_winner() termine la partie sur une victoire et affiche l'ecran
##   partage PlayerWinsScreen ; end_game() la termine sans vainqueur (ex :
##   nombre de rounds maximal atteint). Les deux bloquent les jets et
##   ramenent a la configuration de la partie quand l'ecran se ferme.

signal back_confirmed
signal throw_cancelled(value: String)
signal next_player_requested
signal previous_player_requested

const DART_TEXTURE := preload("res://assets/dart.png")
const EMPTY_THROW_TEXT := "-"
const THROW_FONT_SIZE := 64
const DART_ICON_SIZE := Vector2(0, 192)

## Duree (secondes) du decompte "Remove your darts" entre deux tours.
@export var remove_darts_duration: float = 5.0

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
@onready var throws_scroll: ScrollContainer = $SidePanel/Margin/Content/ThrowsScroll
@onready var throws_list: VBoxContainer = $SidePanel/Margin/Content/ThrowsScroll/ThrowsList
@onready var darts_list: HBoxContainer = $SidePanel/Margin/Content/DartsList
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var remove_darts_screen: RemoveDartsScreen = $RemoveDartsScreen
@onready var winner_screen: PlayerWinsScreen = $PlayerWinsScreen
@onready var stay_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/StayButton
@onready var leave_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/LeaveButton

var round_number := 1

var _game_over := false

var _throws: Array[String] = []
var _history: Array[Array] = []
var _throw_labels: Array[Label] = []
var _dart_icons: Array[TextureRect] = []

func _ready() -> void:
	back_button.pressed.connect(func(): confirm_overlay.visible = true)
	stay_button.pressed.connect(func(): confirm_overlay.visible = false)
	leave_button.pressed.connect(_on_leave_pressed)
	cancel_hit_button.pressed.connect(cancel_last_throw)
	next_player_button.pressed.connect(_start_remove_darts)
	remove_darts_screen.finished.connect(_finish_turn)
	winner_screen.continue_pressed.connect(func(): back_confirmed.emit())
	_build_slots()
	DartInputManager.set_active(true)
	DartInputManager.hit_detected.connect(_on_dart_hit)

func _exit_tree() -> void:
	DartInputManager.hit_detected.disconnect(_on_dart_hit)
	DartInputManager.set_active(false)

## Jet detecte par la source de jets (carte UART ou simulateur). Par defaut
## le jet est simplement ajoute au tour ; un jeu surcharge cette methode pour
## y appliquer ses regles (appeler super pour l'affichage). Ignore tant que la
## confirmation de sortie ou le decompte "Remove your darts" est affiche, ou
## une fois la partie terminee.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	add_throw(hit.get_label())

## Prepare l'ecran pour une partie : joueurs dans l'ordre de passage et
## options choisies dans l'ecran de selection. A surcharger par chaque jeu.
func setup(_players: Array[String], _options: Dictionary) -> void:
	pass

## Termine la partie sur une victoire : bloque les jets et affiche l'ecran
## partage de victoire (contenu provisoire). A appeler par le jeu quand ses
## regles determinent un gagnant.
func announce_winner(player_name: String) -> void:
	if _game_over:
		return
	_game_over = true
	DartInputManager.set_active(false)
	winner_screen.show_winner(player_name)

## Termine la partie sans vainqueur (ex : nombre de rounds maximal atteint) :
## bloque les jets et revient directement a la configuration de la partie.
func end_game(reason: String = "") -> void:
	if _game_over:
		return
	_game_over = true
	DartInputManager.set_active(false)
	if reason != "":
		print(reason)
	back_confirmed.emit()

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
## sont deja toutes lancees. Le dernier jet declenche "Remove your darts".
func add_throw(value: String) -> bool:
	if get_remaining_darts() <= 0:
		return false
	_throws.append(value)
	_refresh()
	if get_remaining_darts() == 0:
		_start_remove_darts()
	return true

## Annule le dernier jet (bouton Cancel hit). Si le tour en cours est vide,
## revient d'abord au tour du joueur precedent (jets restaures, signal
## previous_player_requested) puis retire son dernier jet, s'il en a.
func cancel_last_throw() -> void:
	if _throws.is_empty():
		if _history.is_empty():
			return
		_throws.assign(_history.pop_back())
		previous_player_requested.emit()
	if _throws.is_empty():
		_refresh()
		return
	var value: String = _throws.pop_back()
	_refresh()
	throw_cancelled.emit(value)

## Efface les jets du tour (debut du tour du joueur suivant).
func reset_turn() -> void:
	_throws.clear()
	_refresh()

## Oublie les tours precedents (nouvelle partie) : Cancel hit ne peut plus
## revenir en arriere.
func clear_history() -> void:
	_history.clear()
	_refresh()

func _start_remove_darts() -> void:
	if remove_darts_screen.visible:
		return
	remove_darts_screen.start(remove_darts_duration)

func _finish_turn() -> void:
	_history.append(_throws.duplicate())
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
	cancel_hit_button.disabled = _throws.is_empty() and _history.is_empty()
	# Differe au prochain "idle" : le ScrollContainer ne connait la position
	# reelle du label qu'une fois la mise en page (queue_sort) retraitee,
	# ce qui n'a pas encore eu lieu juste apres avoir change son texte.
	_scroll_to_latest_throw.call_deferred()

## Fait defiler la liste des jets pour garder le dernier jet visible (le
## defilement se fait vers le haut ou le bas selon ce qui est deja visible).
## Appele a chaque changement de _throws, dont l'annulation d'un jet (le
## "dernier jet" devient alors le precedent).
func _scroll_to_latest_throw() -> void:
	if _throws.is_empty():
		return
	var index := mini(_throws.size() - 1, _throw_labels.size() - 1)
	if index >= 0:
		throws_scroll.ensure_control_visible(_throw_labels[index])
