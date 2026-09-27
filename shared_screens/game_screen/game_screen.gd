class_name GameScreen
extends Control

## Template des ecrans de jeu. Bandeau inferieur (Back avec confirmation,
## Cancel, nom du jeu), panneau lateral droit (liste defilante des valeurs
## des jets en haut, fleches restantes toujours visibles en bas en eventail,
## meme si la liste des jets s'allonge) et zone de score libre pour le
## panneau propre au jeu (set_score_panel()). Le bouton Next flotte en rond
## au coin bas-droit, devant l'eventail de fleches. Un jeu herite de cette
## scene ; le template gere
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
## Pilote aussi la carte d'interface reelle (DartInputManager) : chaque debut
## de tour (reset_turn()) et chaque jet tant qu'il en reste (add_throw())
## arme l'attente d'un jet ; la fin du tour (_start_remove_darts(), donc
## Next player comme un tour termine normalement) l'interrompt.

signal back_confirmed
signal throw_cancelled(value: String)
signal next_player_requested
signal previous_player_requested

const DART_TEXTURE := preload("res://assets/dart.png")
const EMPTY_THROW_TEXT := "-"
const THROW_FONT_SIZE := 64
const DART_ICON_SIZE := Vector2(128, 192)
## RemoveDartsScreen et PlayerWinsScreen ne sont pas des enfants fixes de la
## scene (voir _ready()) : instancies au runtime, pas de dependance dans le
## .tscn du template.
const REMOVE_DARTS_SCREEN := preload("res://shared_screens/remove_darts_screen/remove_darts_screen.tscn")
const PLAYER_WINS_SCREEN := preload("res://shared_screens/player_wins_screen/player_wins_screen.tscn")
## Ecart angulaire total de l'eventail de fleches (voir _build_slots) : la
## premiere et la derniere fleche sont chacune a la moitie de cette valeur
## de part et d'autre du centre.
const DART_FAN_SPREAD_DEGREES := 44.0

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
@onready var game_name_label: Label = $BottomBar/Margin/Buttons/GameNameLabel
@onready var next_player_button: Button = $NextButton
@onready var round_label: Label = $SidePanel/Margin/Content/RoundLabel
@onready var throws_scroll: ScrollContainer = $SidePanel/Margin/Content/ThrowsScroll
@onready var throws_list: VBoxContainer = $SidePanel/Margin/Content/ThrowsScroll/ThrowsList
## Fleches restantes, en eventail derriere le bouton Next (voir
## _build_slots) plutot qu'en simple rangee.
@onready var darts_fan: Control = $SidePanel/Margin/Content/DartsFan
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var stay_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/StayButton
@onready var leave_button: Button = $ConfirmOverlay/Center/Dialog/Margin/Content/Buttons/LeaveButton

## Instancies au runtime plutot que fixes dans le .tscn (voir _ready()).
var remove_darts_screen: RemoveDartsScreen
var winner_screen: PlayerWinsScreen

var round_number := 1

var _game_over := false

var _throws: Array[String] = []
var _history: Array[Array] = []
var _throw_labels: Array[Label] = []
var _dart_icons: Array[TextureRect] = []

func _ready() -> void:
	remove_darts_screen = REMOVE_DARTS_SCREEN.instantiate()
	add_child(remove_darts_screen)
	winner_screen = PLAYER_WINS_SCREEN.instantiate()
	add_child(winner_screen)

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

## Affiche le nom du jeu en cours dans la barre du bas.
func set_game_name(value: String) -> void:
	game_name_label.text = value

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
	else:
		# Il reste des flechettes dans le tour : reargue l'attente sur la
		# carte reelle pour le prochain jet (voir DartInputManager).
		DartInputManager.start_turn()
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

## Efface les jets du tour (debut du tour du joueur suivant) et arme
## l'attente d'un jet sur la carte reelle pour ce nouveau tour.
func reset_turn() -> void:
	_throws.clear()
	_refresh()
	DartInputManager.start_turn()

## Oublie les tours precedents (nouvelle partie) : Cancel hit ne peut plus
## revenir en arriere.
func clear_history() -> void:
	_history.clear()
	_refresh()

func _start_remove_darts() -> void:
	# Coupe l'attente sur la carte reelle : sans effet si elle vient deja de
	# se terminer d'elle-meme sur le dernier jet, utile si le tour se termine
	# autrement (bouton Next player, bust en X01, ...).
	DartInputManager.stop_turn()
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
	for child in darts_fan.get_children():
		darts_fan.remove_child(child)
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

		# Toutes les fleches partagent le meme point de pivot (centre-bas de
		# darts_fan, derriere le bouton Next) et ne different que par leur
		# rotation : c'est ce qui donne l'effet d'eventail.
		var icon := TextureRect.new()
		icon.texture = DART_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = -DART_ICON_SIZE.x / 2.0
		icon.offset_right = DART_ICON_SIZE.x / 2.0
		icon.offset_top = -DART_ICON_SIZE.y
		icon.offset_bottom = 0.0
		icon.pivot_offset = Vector2(DART_ICON_SIZE.x / 2.0, DART_ICON_SIZE.y)
		icon.rotation_degrees = _fan_angle_degrees(i, darts_per_turn)
		darts_fan.add_child(icon)
		_dart_icons.append(icon)

	_refresh()

## Angle (degres) de la i-eme fleche dans l'eventail, reparties
## symetriquement de part et d'autre du centre sur DART_FAN_SPREAD_DEGREES.
func _fan_angle_degrees(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return lerpf(-DART_FAN_SPREAD_DEGREES / 2.0, DART_FAN_SPREAD_DEGREES / 2.0, float(index) / float(count - 1))

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
