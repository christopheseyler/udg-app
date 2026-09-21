extends Control

## Ecran de selection de jeu. S'ouvre sur le titre (intro), puis le titre
## disparait et le carrousel apparait. Carrousel d'images disposees sur un
## cylindre virtuel. L'image en face du joueur est nette, les autres
## s'estompent progressivement selon leur angle sur le cylindre.
## Navigation par gesture (glisser au tactile ou a la souris) : la
## transparence et la position se mettent a jour en temps reel pendant
## le geste, puis le carrousel se cale sur la carte la plus proche au
## relachement. Bouton PlayButton pour valider la selection.

## Definition des jeux : "max_players" (defaut DEFAULT_MAX_PLAYERS) et
## "options" (voir game_options.gd ; un jeu sans option desactive le bouton
## Options) sont facultatifs.
const DEFAULT_MAX_PLAYERS := 4
const GAMES := [
	{
		"id": "x01", "name": "X01", "image": "res://assets/game_selector/game_selector_301.png",
		"max_players": 8,
		"options": [
			{
				"id": "start_value", "type": "enum", "name": "Game",
				"items": ["301", "501", "701", "1001"], "default": "501",
				"info": "Starting score. Each player counts down from this value to zero.",
			},
			{"type": "group", "name": "In / Out conditions"},
			{
				"id": "in_condition", "type": "enum", "name": "In",
				"items": ["None", "Double", "Triple", "Master"], "default": "None",
				"info": "Condition to start the game: a player's score only starts to count down once they hit a double (Double), a triple (Triple) or either of them (Master). None: any dart counts.",
			},
			{
				"id": "out_condition", "type": "enum", "name": "Out",
				"items": ["None", "Double", "Triple", "Master"], "default": "Double",
				"info": "Condition to finish the game: the last dart must reach exactly zero with a double (Double), a triple (Triple) or either of them (Master). None: any dart finishes.",
			},
		],
	},
	{"id": "321_zap", "name": "3-2-1 Zap", "image": "res://assets/game_selector/game_selector_321_zap.png"},
	{"id": "halve_it", "name": "Halve It", "image": "res://assets/game_selector/game_selector_halve_it.png"},
	{"id": "shanghai", "name": "Shanghai", "image": "res://assets/game_selector/game_selector_shanghai.png"},
	{"id": "cricket", "name": "Cricket", "image": "res://assets/game_selector/game_selector_cricket.png"},
	{"id": "around_the_clock", "name": "Around the Clock", "image": "res://assets/game_selector/game_selector_around_the_clock.png"},
]

@export var card_size: float = 500.0
@export var cylinder_radius: float = 900.0
@export var angle_step_degrees: float = 42.0
@export var min_alpha: float = 0.00
@export var alpha_falloff_power: float = 4
@export var min_scale_x: float = 0.06
@export var carousel_center_y_ratio: float = 0.42
@export var settle_duration: float = 0.35

@export_group("Bouton Jouer")
@export var button_press_scale: float = 0.88
@export var button_press_offset: float = 8.0
@export var button_press_duration: float = 0.07

@export_group("Intro")
@export var carousel_fade_in_duration: float = 0.8

@export_group("Selection")
@export var select_duration: float = 0.6
@export var selected_zoom: float = 1.15
@export var others_slide_distance: float = 600.0

@onready var card_container: Control = $CardContainer
@onready var play_button: TextureButton = $PlayButton
@onready var setup_panel: GameSetupPanel = $SetupPanel
@onready var players_panel: GamePlayers = $PlayersPanel
@onready var options_panel: GameOptions = $OptionsPanel

var current_index: int = 0
var _intro_done := false
var _selecting := false
var _selection_amount := 0.0
var _cards: Array[TextureRect] = []
var _scroll_offset: float = 0.0
var _px_per_card: float = 1.0

var _dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_offset: float = 0.0
var _tween: Tween

var _play_button_base_position: Vector2
var _button_tween: Tween

func _ready() -> void:
	_px_per_card = cylinder_radius * deg_to_rad(angle_step_degrees)
	_build_cards()
	_update_cards()
	_setup_play_button()
	_setup_panels()

	if has_node("LeftButton"):
		$LeftButton.pressed.connect(func(): _go_to_index(current_index - 1))
	if has_node("RightButton"):
		$RightButton.pressed.connect(func(): _go_to_index(current_index + 1))

	_play_intro()

## Ouverture : le carrousel et le bouton apparaissent en fondu sur le
## fond deja assombri. Les interactions sont bloquees pendant le fondu.
func _play_intro() -> void:
	card_container.modulate.a = 0.0
	play_button.modulate.a = 0.0
	play_button.disabled = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_container, "modulate:a", 1.0, carousel_fade_in_duration)
	tween.tween_property(play_button, "modulate:a", 1.0, carousel_fade_in_duration)
	tween.set_parallel(false)
	tween.tween_callback(_on_intro_finished)

func _on_intro_finished() -> void:
	_intro_done = true
	play_button.disabled = false

func _build_cards() -> void:
	for game in GAMES:
		var card := TextureRect.new()
		card.size = Vector2(card_size, card_size)
		card.pivot_offset = Vector2(card_size, card_size) / 2.0
		card.texture = load(game["image"])
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_container.add_child(card)
		_cards.append(card)

## Positionne, estompe et "tourne" chaque carte selon son angle sur le
## cylindre virtuel, en fonction de _scroll_offset courant. Le delta
## angulaire passe par wrapf pour un defilement infini : une carte peut
## se rapprocher du centre par la gauche ou par la droite selon le
## chemin le plus court sur le cylindre.
## La rotation autour de l'axe Y (comme une carte collee sur un
## cylindre qui tourne) est simulee en 2D par un ecrasement horizontal :
## scale.x = cos(angle), la hauteur ne change pas. Une carte de face
## (angle = 0) garde sa largeur pleine ; une carte de profil (angle =
## +-90 deg) devient une fine tranche verticale.
func _update_cards() -> void:
	var screen_center := get_viewport_rect().size / 2.0
	var center := get_viewport_rect().size * Vector2(0.5, carousel_center_y_ratio)
	var angle_step := deg_to_rad(angle_step_degrees)
	var n := _cards.size()

	for i in n:
		var card := _cards[i]
		var delta := wrapf(i - _scroll_offset, -n / 2.0, n / 2.0)
		var angle := clampf(delta * angle_step, -PI / 2.0, PI / 2.0)
		var depth := cos(angle)

		var pos := Vector2(
			center.x + sin(angle) * cylinder_radius - card_size / 2.0,
			center.y - card_size / 2.0
		)
		var scl := Vector2(lerpf(min_scale_x, 1.0, depth), 1.0)
		var alpha := lerpf(min_alpha, 1.0, pow(depth, alpha_falloff_power))

		if _selection_amount > 0.0:
			if i == current_index:
				var selected_pos := screen_center - Vector2(card_size, card_size) / 2.0
				pos = pos.lerp(selected_pos, _selection_amount)
				scl = scl.lerp(Vector2.ONE * selected_zoom, _selection_amount)
			else:
				var side := signf(wrapf(i - current_index, -n / 2.0, n / 2.0))
				pos.x += side * others_slide_distance * _selection_amount
				alpha *= 1.0 - _selection_amount

		card.position = pos
		card.scale = scl
		card.modulate.a = alpha
		card.z_index = int(depth * 100.0)

func _gui_input(event: InputEvent) -> void:
	if not _intro_done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_start_drag(event.position.x)
		elif _dragging:
			_end_drag()
	elif event is InputEventScreenDrag and _dragging:
		_update_drag(event.position.x)
	elif event is InputEventMouseMotion and _dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_update_drag(event.position.x)

func _start_drag(x: float) -> void:
	if _tween:
		_tween.kill()
	_dragging = true
	_drag_start_x = x
	_drag_start_offset = _scroll_offset

func _update_drag(x: float) -> void:
	var delta_x := x - _drag_start_x
	_scroll_offset = fposmod(_drag_start_offset - delta_x / _px_per_card, float(_cards.size()))
	_update_cards()

func _end_drag() -> void:
	_dragging = false
	current_index = roundi(_scroll_offset) % _cards.size()
	_settle_to_current()

func _go_to_index(index: int) -> void:
	var n := _cards.size()
	current_index = ((index % n) + n) % n
	_settle_to_current()

## Anime _scroll_offset vers current_index en empruntant le chemin le
## plus court sur le cylindre (defilement infini : peut continuer au-dela
## de 0 ou de n-1 plutot que de revenir en arriere en traversant l'ecran).
func _settle_to_current() -> void:
	if _tween:
		_tween.kill()
	var n := _cards.size()
	var shortest_diff := wrapf(float(current_index) - _scroll_offset, -n / 2.0, n / 2.0)
	var target := _scroll_offset + shortest_diff
	_tween = create_tween()
	_tween.tween_method(_set_scroll_offset, _scroll_offset, target, settle_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(func(): _scroll_offset = fposmod(_scroll_offset, float(n)))

func _set_scroll_offset(value: float) -> void:
	_scroll_offset = value
	_update_cards()

## Prepare le bouton texture "start_button" : centre le pivot pour que
## l'enfoncement se fasse depuis son centre, et branche l'animation de
## pression sur button_down/button_up (independants de "pressed", qui
## ne se declenche qu'au relachement a l'interieur du bouton).
func _setup_play_button() -> void:
	play_button.pivot_offset = play_button.size / 2.0
	_play_button_base_position = play_button.position
	play_button.button_down.connect(_on_play_button_down)
	play_button.button_up.connect(_on_play_button_up)
	play_button.pressed.connect(_on_play_pressed)

func _on_play_button_down() -> void:
	if _button_tween:
		_button_tween.kill()
	_button_tween = create_tween()
	_button_tween.set_parallel(true)
	_button_tween.tween_property(play_button, "scale", Vector2.ONE * button_press_scale, button_press_duration)
	_button_tween.tween_property(play_button, "position:y", _play_button_base_position.y + button_press_offset, button_press_duration)

func _on_play_button_up() -> void:
	if _button_tween:
		_button_tween.kill()
	_button_tween = create_tween()
	_button_tween.set_parallel(true)
	_button_tween.tween_property(play_button, "scale", Vector2.ONE, button_press_duration)
	_button_tween.tween_property(play_button, "position:y", _play_button_base_position.y, button_press_duration)

func _on_play_pressed() -> void:
	if _selecting:
		return
	_selecting = true
	_intro_done = false
	play_button.disabled = true

	var selected_game: Dictionary = GAMES[current_index]
	print("Jeu selectionne : ", selected_game["id"])
	_configure_panels_for(selected_game)
	_animate_selection(1.0).finished.connect(setup_panel.show_panel)

## Anime _selection_amount (0 = carrousel, 1 = jeu selectionne) : le logo
## choisi zoome legerement et se centre au milieu de l'ecran, les autres
## logos disparaissent en fondu en glissant lateralement (vers la gauche ou
## la droite selon leur position d'origine) et le bouton s'efface en fondu.
## Anime dans les deux sens : 0 revient au carrousel (bouton Back).
func _animate_selection(target: float) -> Tween:
	if _tween:
		_tween.kill()
	_scroll_offset = float(current_index)

	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_selection_amount, _selection_amount, target, select_duration) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(play_button, "modulate:a", 1.0 - target, select_duration)
	return _tween

func _set_selection_amount(value: float) -> void:
	_selection_amount = value
	_update_cards()

## Branche les panneaux de configuration : Players / Options s'ouvrent
## au-dessus du panneau de boutons (un seul a la fois), Back ferme tout et
## revient au carrousel, Start lance la partie.
func _setup_panels() -> void:
	setup_panel.back_pressed.connect(_on_back_pressed)
	setup_panel.players_pressed.connect(_toggle_sub_panel.bind(players_panel))
	setup_panel.options_pressed.connect(_toggle_sub_panel.bind(options_panel))
	setup_panel.start_pressed.connect(_on_start_pressed)

## Adapte les panneaux au jeu choisi : nombre max de joueurs, options (le
## bouton Options est desactive si le jeu n'en a pas).
func _configure_panels_for(game: Dictionary) -> void:
	var options: Array = game.get("options", [])
	players_panel.set_max_players(game.get("max_players", DEFAULT_MAX_PLAYERS))
	options_panel.set_options(options)
	setup_panel.set_options_enabled(not options.is_empty())

func _toggle_sub_panel(panel: SlidePanel) -> void:
	var other: SlidePanel = options_panel if panel == players_panel else players_panel
	other.hide_panel()
	if panel.is_open:
		panel.hide_panel()
	else:
		panel.show_panel()

func _on_back_pressed() -> void:
	players_panel.hide_panel()
	options_panel.hide_panel()
	setup_panel.hide_panel()
	_animate_selection(0.0).finished.connect(_on_selection_cancelled)

func _on_selection_cancelled() -> void:
	_selecting = false
	_intro_done = true
	play_button.disabled = false

func _on_start_pressed() -> void:
	var player_names := players_panel.get_player_names()
	if player_names.is_empty():
		if not players_panel.is_open:
			_toggle_sub_panel(players_panel)
		return

	var config := {
		"game": GAMES[current_index]["id"],
		"players": player_names,
		"options": options_panel.get_values(),
	}
	print("Start : ", config)
	# TODO: lancer la scene de jeu avec cette configuration
