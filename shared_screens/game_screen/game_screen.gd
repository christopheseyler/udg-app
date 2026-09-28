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
## - add_throw() enregistre un jet (DartHit) et si ce jet compte pour le
##   score du joueur (badge dore ou neutre, voir TargetValueBadge) ;
## - Cancel hit retire le dernier jet (throw_cancelled est emis) ; quand le
##   tour du joueur est vide, il revient au joueur precedent
##   (previous_player_requested, puis son dernier jet est retire), ce qui
##   permet d'annuler les fleches une par une jusqu'au debut ;
## - set_round() met a jour le numero de round affiche ;
## - quand les fleches du tour sont toutes lancees, ou par Next player,
##   l'ecran "Remove your darts" (RemoveDartsScreen) s'affiche pendant
##   remove_darts_duration secondes (Next, qui reste accessible, passe le
##   decompte) ; ensuite next_player_requested est emis et le tour est remis
##   a zero ;
## - back_confirmed est emis quand le joueur confirme la sortie du jeu ;
## - announce_rank() annonce qu'un joueur (ou plusieurs ex aequo) termine a
##   une place donnee (ecran partage PlayerWinsScreen, avec coupe pour les
##   trois premieres places) ; les jets sont bloques tant qu'il est affiche.
##   Un jeu qui continue apres le premier gagnant reprend la partie a sa
##   fermeture ;
## - finish_game() termine la partie avec le classement final de tous les
##   joueurs (voir rank_standings) : apres l'eventuelle annonce en cours,
##   l'ecran de classement (RankingScreen) s'affiche, puis ramene a la
##   configuration de la partie quand il se ferme.

signal back_confirmed
signal throw_cancelled
signal next_player_requested
signal previous_player_requested

const DART_TEXTURE := preload("res://assets/dart.png")
const THROW_BADGE := preload("res://shared_screens/target_value_badge/target_value_badge.tscn")
## Taille d'affichage d'un badge de jet dans la liste (le composant a une
## taille fixe par defaut, voir target_value_badge.tscn ; agrandie ici pour
## rester lisible dans le panneau lateral).
const THROW_BADGE_SIZE := Vector2(195, 163)
## Espace vertical entre deux badges quand il y a de la place (voir
## _fit_throw_badges). Quand ils ne tiennent plus, ils sont d'abord resserres
## jusqu'a ne garder que THROW_BADGE_MIN_GAP entre leurs contenus ; la liste
## ne defile qu'au-dela.
const THROW_BADGE_SPACING := 16.0
const THROW_BADGE_MIN_GAP := 8.0
const DART_ICON_SIZE := Vector2(170, 255)
## RemoveDartsScreen, PlayerWinsScreen et RankingScreen ne sont pas des
## enfants fixes de la scene (voir _ready()) : instancies au runtime, pas de
## dependance dans le .tscn du template.
const REMOVE_DARTS_SCREEN := preload("res://shared_screens/remove_darts_screen/remove_darts_screen.tscn")
const PLAYER_WINS_SCREEN := preload("res://shared_screens/player_wins_screen/player_wins_screen.tscn")
const RANKING_SCREEN := preload("res://shared_screens/ranking_screen/ranking_screen.tscn")
## Ecart angulaire total de l'eventail de fleches (voir _build_slots) : la
## premiere et la derniere fleche sont chacune a la moitie de cette valeur
## de part et d'autre du centre.
const DART_FAN_SPREAD_DEGREES := 44.0
## Effet "pushed" du bouton Next (voir _on_next_button_down/_up) : il se
## tasse legerement et s'assombrit pendant l'appui.
const NEXT_BUTTON_PRESS_SCALE := 0.9
const NEXT_BUTTON_PRESS_DURATION := 0.08
## Pulsation lumineuse du bouton Next pendant "Remove your darts", pour
## montrer qu'il permet de passer le decompte (self_modulate : independante
## de l'effet "pushed", qui joue sur modulate).
const NEXT_BUTTON_PULSE_COLOR := Color(1.6, 1.4, 1.2)
const NEXT_BUTTON_PULSE_DURATION := 0.5
## Animation d'un jet (voir _animate_dart_out / _animate_dart_in) : la
## fleche lancee s'envole dans l'axe de l'eventail en s'effacant, puis la
## medaille du jet apparait (TargetValueBadge.play_appear). Une fleche
## rendue (Cancel hit, nouveau tour) redescend a sa place.
const DART_FLY_DISTANCE := 260.0
const DART_FLY_DURATION := 0.3
const DART_RETURN_DISTANCE := 80.0
const DART_RETURN_DURATION := 0.25
## Decalage entre les fleches rendues ensemble (nouveau tour).
const DART_RETURN_STAGGER := 0.08
## Delai avant l'apparition de la medaille : la fleche est deja bien partie.
const BADGE_APPEAR_DELAY := 0.1
## Delai avant "Remove your darts" apres le dernier jet du tour, pour laisser
## l'animation du jet se terminer (voir start_remove_darts_after_throw).
const REMOVE_DARTS_DELAY := 0.8

## Duree (secondes) du decompte "Remove your darts" entre deux tours.
@export var remove_darts_duration: float = 5.0

@export var darts_per_turn: int = 3:
	set(value):
		value = maxi(value, 1)
		# Les jeux peuvent le reaffecter a chaque jet (X01) : ne reconstruire
		# que si le nombre change, pour ne pas interrompre les animations.
		if value == darts_per_turn:
			return
		darts_per_turn = value
		if is_node_ready():
			_build_slots()

@onready var score_area: Control = $ScoreArea
@onready var back_button: Button = $BottomBar/Margin/Buttons/BackButton
@onready var cancel_hit_button: Button = $BottomBar/Margin/Buttons/CancelHitButton
@onready var game_name_label: Label = $BottomBar/Margin/Buttons/GameNameLabel
@onready var next_player_button: TextureButton = $NextButton
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
var ranking_screen: RankingScreen

var round_number := 1

var _game_over := false
## Classement final (voir finish_game), affiche par ranking_screen.
var _final_standings: Array[Dictionary] = []

## Chaque entree : {"hit": DartHit, "highlighted": bool} (highlighted = ce
## jet compte pour le score du joueur, voir TargetValueBadge.show_hit).
var _throws: Array[Dictionary] = []
var _history: Array[Array] = []
var _throw_badges: Array[TargetValueBadge] = []
var _dart_icons: Array[TextureRect] = []
## Etat affiche de chaque fleche de l'eventail et animation en cours : les
## animations ne sont jouees que quand une fleche change d'etat (voir
## _refresh).
var _dart_shown: Array[bool] = []
var _dart_tweens: Array[Tween] = []
## Nombre de medailles deja affichees : seules les suivantes sont animees.
var _badges_shown := 0
## Incremente a chaque changement de _throws : un "Remove your darts"
## differe (voir start_remove_darts_after_throw) est abandonne si un jet a ete
## ajoute ou annule entre-temps.
var _throws_serial := 0
## Derniere demande de "Remove your darts" differe : seule elle aboutit.
var _remove_darts_request := 0
var _next_pulse_tween: Tween

func _ready() -> void:
	remove_darts_screen = REMOVE_DARTS_SCREEN.instantiate()
	add_child(remove_darts_screen)
	# Sous le bouton Next : il reste visible et cliquable pendant "Remove your
	# darts" et sert alors a passer le decompte (voir _on_next_pressed).
	move_child(remove_darts_screen, next_player_button.get_index())
	winner_screen = PLAYER_WINS_SCREEN.instantiate()
	add_child(winner_screen)
	ranking_screen = RANKING_SCREEN.instantiate()
	add_child(ranking_screen)

	back_button.pressed.connect(func(): confirm_overlay.visible = true)
	stay_button.pressed.connect(func(): confirm_overlay.visible = false)
	leave_button.pressed.connect(_on_leave_pressed)
	cancel_hit_button.pressed.connect(cancel_last_throw)
	next_player_button.pressed.connect(_on_next_pressed)
	next_player_button.button_down.connect(_on_next_button_down)
	next_player_button.button_up.connect(_on_next_button_up)
	remove_darts_screen.finished.connect(_finish_turn)
	throws_scroll.resized.connect(_fit_throw_badges)
	winner_screen.continue_pressed.connect(_on_winner_continue)
	ranking_screen.continue_pressed.connect(func(): back_confirmed.emit())
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
	add_throw(hit, true)

## Prepare l'ecran pour une partie : joueurs dans l'ordre de passage et
## options choisies dans l'ecran de selection. A surcharger par chaque jeu.
func setup(_players: Array[String], _options: Dictionary) -> void:
	pass

## Annonce que player_names (plusieurs noms = ex aequo) terminent a la place
## rank (1 = victoire) : ecran PlayerWinsScreen, jets bloques tant qu'il est
## affiche. A sa fermeture, la partie reprend, sauf si finish_game() a ete
## appele entre-temps (l'ecran de classement s'affiche alors).
func announce_rank(player_names: Array[String], rank: int) -> void:
	if _game_over:
		return
	DartInputManager.set_active(false)
	winner_screen.show_rank(player_names, rank)

## Termine la partie : bloque les jets et affiche l'ecran de classement
## (apres l'annonce announce_rank() en cours, s'il y en a une).
## standings : classement de tous les joueurs du premier au dernier, voir
## rank_standings() pour le construire.
func finish_game(standings: Array[Dictionary]) -> void:
	if _game_over:
		return
	_game_over = true
	DartInputManager.set_active(false)
	_final_standings = standings
	if not winner_screen.visible:
		ranking_screen.show_standings(_final_standings)

## Construit un classement a passer a finish_game() : entries (un
## Dictionary par joueur : "name", "score", "stats" facultatif, plus tout
## champ utile a better) triees avec better(a, b) (vrai si a est mieux classe
## que b), puis numerotees dans "rank". Les ex aequo (aucun des deux mieux
## classe que l'autre) partagent le meme rang et le suivant est decale
## (1, 2, 2, 4).
static func rank_standings(entries: Array[Dictionary], better: Callable) -> Array[Dictionary]:
	var sorted := entries.duplicate()
	sorted.sort_custom(better)
	for i in sorted.size():
		if i > 0 and not better.call(sorted[i - 1], sorted[i]):
			sorted[i]["rank"] = sorted[i - 1]["rank"]
		else:
			sorted[i]["rank"] = i + 1
	return sorted

func _on_winner_continue() -> void:
	winner_screen.hide_screen()
	if _game_over:
		ranking_screen.show_standings(_final_standings)
	else:
		DartInputManager.set_active(true)

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

func get_throws() -> Array[Dictionary]:
	return _throws.duplicate()

func get_remaining_darts() -> int:
	return darts_per_turn - _throws.size()

## Enregistre un jet du tour en cours. highlighted indique si ce jet compte
## pour le score du joueur (medaille doree) ou non (medaille neutre) : voir
## TargetValueBadge.show_hit(). Retourne false si les fleches du tour sont
## deja toutes lancees. Le dernier jet declenche "Remove your darts" (une fois
## son animation terminee).
func add_throw(hit: DartHit, highlighted: bool) -> bool:
	if get_remaining_darts() <= 0:
		return false
	_throws.append({"hit": hit, "highlighted": highlighted})
	_refresh()
	if get_remaining_darts() == 0:
		start_remove_darts_after_throw()
	return true

## Affiche "Remove your darts" apres delay secondes (par defaut
## REMOVE_DARTS_DELAY, le temps de l'animation du dernier jet ; un jeu peut
## allonger ce delai pour sa propre animation, ex. le Bust du X01). Un nouvel
## appel remplace le precedent. Abandonne si un jet est ajoute ou annule
## entre-temps, ou si la partie se termine (victoire sur ce jet).
func start_remove_darts_after_throw(delay: float = REMOVE_DARTS_DELAY) -> void:
	_remove_darts_request += 1
	# Connexion plutot qu'await : deconnectee automatiquement si l'ecran est
	# libere avant la fin du delai (sortie du jeu).
	get_tree().create_timer(delay).timeout.connect(
		_on_remove_darts_delay_elapsed.bind(_remove_darts_request, _throws_serial))

func _on_remove_darts_delay_elapsed(request: int, serial: int) -> void:
	if request == _remove_darts_request and serial == _throws_serial and not _game_over:
		_start_remove_darts()

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
	_throws.pop_back()
	_refresh()
	throw_cancelled.emit()

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
	_set_next_button_pulse(true)

func _set_next_button_pulse(active: bool) -> void:
	if _next_pulse_tween:
		_next_pulse_tween.kill()
		_next_pulse_tween = null
	next_player_button.self_modulate = Color.WHITE
	if not active:
		return
	_next_pulse_tween = create_tween().set_loops()
	_next_pulse_tween.tween_property(next_player_button, "self_modulate", NEXT_BUTTON_PULSE_COLOR, NEXT_BUTTON_PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_pulse_tween.tween_property(next_player_button, "self_modulate", Color.WHITE, NEXT_BUTTON_PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Bouton Next : termine le tour ("Remove your darts") ou, si cet ecran est
## deja affiche, passe son decompte.
func _on_next_pressed() -> void:
	if remove_darts_screen.visible:
		remove_darts_screen.skip()
	else:
		_start_remove_darts()

func _on_next_button_down() -> void:
	var tween := create_tween()
	tween.tween_property(next_player_button, "scale", Vector2.ONE * NEXT_BUTTON_PRESS_SCALE, NEXT_BUTTON_PRESS_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(next_player_button, "modulate", Color(0.75, 0.75, 0.75, 1.0), NEXT_BUTTON_PRESS_DURATION)

func _on_next_button_up() -> void:
	var tween := create_tween()
	tween.tween_property(next_player_button, "scale", Vector2.ONE, NEXT_BUTTON_PRESS_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(next_player_button, "modulate", Color.WHITE, NEXT_BUTTON_PRESS_DURATION)

func _finish_turn() -> void:
	_set_next_button_pulse(false)
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
	for tween in _dart_tweens:
		if tween:
			tween.kill()
	_throw_badges.clear()
	_dart_icons.clear()
	_dart_shown.clear()
	_dart_tweens.clear()
	# Les jets deja enregistres sont reaffiches sans animation.
	_badges_shown = _throws.size()

	for i in darts_per_turn:
		var badge: TargetValueBadge = THROW_BADGE.instantiate()
		badge.custom_minimum_size = THROW_BADGE_SIZE
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		throws_list.add_child(badge)
		_throw_badges.append(badge)

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
		_set_dart_shift(icon, Vector2.ZERO)
		icon.pivot_offset = Vector2(DART_ICON_SIZE.x / 2.0, DART_ICON_SIZE.y)
		icon.rotation_degrees = _fan_angle_degrees(i, darts_per_turn)
		darts_fan.add_child(icon)
		_dart_icons.append(icon)
		# Etat initial pose sans animation.
		_dart_shown.append(i < get_remaining_darts())
		_dart_tweens.append(null)
		icon.modulate.a = 1.0 if _dart_shown[i] else 0.0

	_refresh()

## Decale une fleche de l'eventail de shift par rapport a sa place (offsets
## plutot que position : la fleche reste ancree au centre-bas de darts_fan).
func _set_dart_shift(icon: Control, shift: Vector2) -> void:
	icon.offset_left = -DART_ICON_SIZE.x / 2.0 + shift.x
	icon.offset_right = DART_ICON_SIZE.x / 2.0 + shift.x
	icon.offset_top = -DART_ICON_SIZE.y + shift.y
	icon.offset_bottom = shift.y

## Fleche lancee : elle part dans son axe (vers la pointe) en accelerant et
## s'efface, puis est remise en place, invisible.
func _animate_dart_out(index: int) -> void:
	var icon := _dart_icons[index]
	var direction := Vector2.UP.rotated(icon.rotation)
	var tween := _restart_dart_tween(index)
	tween.tween_method(func(t: float): _set_dart_shift(icon, direction * DART_FLY_DISTANCE * t), 0.0, 1.0, DART_FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, DART_FLY_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_set_dart_shift.bind(icon, Vector2.ZERO))

## Fleche rendue : elle redescend a sa place depuis le haut de son axe en
## apparaissant, apres delay secondes.
func _animate_dart_in(index: int, delay: float) -> void:
	var icon := _dart_icons[index]
	var direction := Vector2.UP.rotated(icon.rotation)
	var tween := _restart_dart_tween(index)
	icon.modulate.a = 0.0
	_set_dart_shift(icon, direction * DART_RETURN_DISTANCE)
	tween.tween_interval(delay)
	tween.tween_method(func(t: float): _set_dart_shift(icon, direction * DART_RETURN_DISTANCE * (1.0 - t)), 0.0, 1.0, DART_RETURN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(icon, "modulate:a", 1.0, DART_RETURN_DURATION)

func _restart_dart_tween(index: int) -> Tween:
	if _dart_tweens[index]:
		_dart_tweens[index].kill()
	_dart_tweens[index] = create_tween()
	return _dart_tweens[index]

## Angle (degres) de la i-eme fleche dans l'eventail, reparties
## symetriquement de part et d'autre du centre sur DART_FAN_SPREAD_DEGREES.
func _fan_angle_degrees(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return lerpf(-DART_FAN_SPREAD_DEGREES / 2.0, DART_FAN_SPREAD_DEGREES / 2.0, float(index) / float(count - 1))

func _refresh() -> void:
	_throws_serial += 1
	var remaining := get_remaining_darts()
	var returned := 0
	for i in darts_per_turn:
		var thrown := i < _throws.size()
		if thrown:
			_throw_badges[i].show_hit(_throws[i].hit, _throws[i].highlighted)
			if i >= _badges_shown:
				_throw_badges[i].play_appear(BADGE_APPEAR_DELAY)
		else:
			_throw_badges[i].clear()
		# Les icones restent en place pour garder la mise en page : seules
		# les fleches restantes sont visibles. La fleche la plus a droite part
		# en premier ; les fleches rendues ensemble reviennent de gauche a
		# droite.
		var shown := i < remaining
		if shown != _dart_shown[i]:
			_dart_shown[i] = shown
			if shown:
				_animate_dart_in(i, returned * DART_RETURN_STAGGER)
				returned += 1
			else:
				_animate_dart_out(i)
	_badges_shown = _throws.size()
	_fit_throw_badges()
	cancel_hit_button.disabled = _throws.is_empty() and _history.is_empty()
	# Differe au prochain "idle" : le ScrollContainer ne connait la position
	# reelle du badge qu'une fois la mise en page (queue_sort) retraitee, ce
	# qui n'a pas encore eu lieu juste apres avoir change son contenu.
	_scroll_to_latest_throw.call_deferred()

## Hauteur de chaque badge de la liste des jets (la liste n'a pas d'espacement
## propre, voir game_screen.tscn : l'ecart est inclus dans la hauteur des
## badges, leur contenu y est centre). Tant que tout tient, chaque badge
## garde sa hauteur normale plus THROW_BADGE_SPACING ; sinon l'espace
## disponible est reparti a parts egales autour des contenus (plaque ou
## "MISSED", voir TargetValueBadge.get_content_height), sans descendre sous
## THROW_BADGE_MIN_GAP : ce n'est qu'alors que la liste deborde et defile.
func _fit_throw_badges() -> void:
	var available := throws_scroll.size.y
	if available <= 0.0 or _throw_badges.is_empty():
		return
	var width := THROW_BADGE_SIZE.x
	var slot_height := THROW_BADGE_SIZE.y + THROW_BADGE_SPACING
	var contents: Array[float] = []
	var total_content := 0.0
	for badge in _throw_badges:
		var content_height := badge.get_content_height(width)
		contents.append(content_height)
		total_content += content_height
	# Arrondi vers le bas : un debordement d'une fraction de pixel suffirait a
	# faire apparaitre la barre de defilement.
	var gap := maxf(floorf((available - total_content) / _throw_badges.size()) - 1.0, THROW_BADGE_MIN_GAP)
	for i in _throw_badges.size():
		var height := minf(floorf(contents[i]) + gap, maxf(slot_height, ceilf(contents[i]) + THROW_BADGE_MIN_GAP))
		_throw_badges[i].custom_minimum_size = Vector2(width, height)

## Fait defiler la liste des jets pour garder le dernier jet visible (le
## defilement se fait vers le haut ou le bas selon ce qui est deja visible).
## Appele a chaque changement de _throws, dont l'annulation d'un jet (le
## "dernier jet" devient alors le precedent).
func _scroll_to_latest_throw() -> void:
	if _throws.is_empty():
		return
	var index := mini(_throws.size() - 1, _throw_badges.size() - 1)
	if index >= 0:
		throws_scroll.ensure_control_visible(_throw_badges[index])
