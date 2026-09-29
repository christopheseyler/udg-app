class_name Zap321Screen
extends GameScreen

## Ecran de jeu du 321 Zap, base sur le template GameScreen (regles
## detaillees : voir "321 zap rules.txt"). Chaque joueur part de 0 et doit
## atteindre exactement 321 (ou, en mode Both Ways, part de 321 et doit
## atteindre 0 selon la parite du segment de sa fleche d'entree).
##
## - Entree : tant qu'un joueur n'est pas entre (in_condition), il est "Out"
##   et ses fleches ne comptent pas ; la fleche d'entree compte, un rate
##   n'entre jamais. Auto Entering : un joueur pas entre a la fin de son tour
##   entre sur un jet fictif tire au hasard (animation "Auto Enter!"), garde
##   pour ce tour si Cancel hit le rejoue.
## - Rebond : depasser la cible fait rebondir (321 + 20 de trop -> 301) ; par
##   defaut, le tour s'arrete (option continue_after_bounce).
## - Zap : atteindre exactement le score d'un autre joueur en jeu le renvoie
##   "Out" (il doit rentrer a nouveau) et rapporte un zap. Auto-Zap : revenir
##   par rebond sur le score d'avant la fleche zappe le joueur lui-meme.
## - Sortie : la fleche qui atteint la cible doit respecter out_condition et,
##   en Master Zap, le joueur doit avoir au moins un zap ; sinon il est "Zop"
##   (zop_behavior : Bust, Nothing ou Auto-Zap).
## - Fin : comme en X01 (end_at_first_finish, max_rounds) ; les joueurs non
##   arrives sont classes par distance a leur cible.
##
## Comme en X01, l'etat n'est jamais modifie fleche par fleche : il est
## recalcule a chaque changement en rejouant les fleches du tour depuis
## l'instantane pris a son debut (voir _replay_turn), et chaque tour termine
## garde son instantane dans _turn_history : Cancel hit est donc toujours
## exact, zaps sur les autres joueurs compris.

const TARGET := 321

## Tous les jets possibles d'une fleche (hors rate) : 1 a 20 en simple,
## double, triple, et le bull en simple et double. Sert au tirage de l'entree
## automatique et a savoir si un joueur peut terminer en une fleche.
static var ALL_DARTS: Array[DartHit] = _build_all_darts()

## Animation "Auto Enter!" (voir _show_auto_entry) : le texte arrive comme le
## "Bust!" du X01 (SpinBanner), une fleche traverse la zone de score derriere
## lui et la medaille du jet fictif apparait dessous. "Remove your darts"
## suit apres AUTO_ENTER_DISPLAY_DURATION.
const AUTO_ENTER_TEXTURE := preload("res://assets/games/321_zap/auto_enter.png")
const AUTO_ENTER_SIZE := Vector2(1000, 500)
const AUTO_ENTER_OFFSET := Vector2(0, -110)
const AUTO_ENTER_DART_SIZE := Vector2(260, 390)
const AUTO_ENTER_DART_DURATION := 0.7
const AUTO_ENTER_BADGE_SIZE := Vector2(320, 267)
const AUTO_ENTER_BADGE_OFFSET := Vector2(0, 250)
const AUTO_ENTER_BADGE_DELAY := 0.45
const AUTO_ENTER_DISPLAY_DURATION := 2.2

## Animation de zap (voir _show_zap) : le nom du ou des joueurs zappes
## apparait au centre de la zone de score et tremble de plus en plus fort,
## puis "Zap!" tombe du haut et vient le frapper (flash blanc, le nom
## s'ecrase et rebondit). Jets ignores pendant l'animation ; "Remove your
## darts" attend sa fin si la fleche termine le tour.
const ZAP_TEXTURE := preload("res://assets/games/321_zap/zap.png")
const ZAP_SIZE := Vector2(1000, 500)
## Centre de "Zap!" une fois pose, par rapport au centre de la zone de
## score : juste au-dessus du nom, la pointe de l'eclair touchant le nom.
const ZAP_OFFSET := Vector2(0, -60)
const ZAP_NAME_OFFSET := Vector2(0, 180)
const ZAP_NAME_SIZE := Vector2(1400, 170)
const ZAP_NAME_FONT_SIZE := 120
const ZAP_NAME_APPEAR_DURATION := 0.25
const ZAP_NAME_SHAKE_DURATION := 0.7
const ZAP_NAME_SHAKE_AMPLITUDE := 18.0
const ZAP_FALL_DURATION := 0.18
const ZAP_FLASH_ALPHA := 0.7
const ZAP_FLASH_DURATION := 0.3
const ZAP_SQUASH_SCALE := Vector2(1.25, 0.6)
const ZAP_SQUASH_DURATION := 0.5
const ZAP_HOLD_DURATION := 1.5
const ZAP_DISPLAY_DURATION := ZAP_NAME_APPEAR_DURATION + ZAP_NAME_SHAKE_DURATION + ZAP_FALL_DURATION + ZAP_HOLD_DURATION

@export var max_rounds: int = 10

@onready var score_panel: Zap321ScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _in_condition := "None"
var _out_condition := "None"
var _auto_entering := false
var _master_zap := false
var _both_ways := false
var _continue_after_bounce := false
var _auto_zap := false
var _zop_behavior := "Bust"
var _end_at_first_finish := true

## Etat courant de chaque joueur. _entered faux = "Out". _directions : +1
## (0 -> 321) ou -1 (321 -> 0), valable seulement une fois entre. _zaps :
## nombre de zaps obtenus (Master Zap), acquis jusqu'a la fin de la partie.
var _scores: Array[int] = []
var _entered: Array[bool] = []
var _directions: Array[int] = []
var _zaps: Array[int] = []
## Joueurs ayant termine, dans l'ordre d'arrivee (rang = position + 1).
var _finished: Array[int] = []
var _current_player := 0

## Fleches du tour en cours et jet fictif de l'entree automatique de ce tour
## (tire une seule fois, reutilise si Cancel hit puis nouvelle fin de tour
## sans entrer), applique ou non.
var _turn_hits: Array[DartHit] = []
var _turn_auto_dart: DartHit
var _turn_auto_applied := false
## Vrai quand le tour est termine avant ses 3 fleches (rebond, zop,
## arrivee) : les fleches suivantes sont ignorees.
var _turn_over := false
## Instantane de debut de tour, que _replay_turn rejoue.
var _turn_start: Dictionary = {}
## Tours termines (parallele a GameScreen._history), pour Cancel hit.
var _turn_history: Array[Dictionary] = []
## Vrai entre l'annonce du rang d'un joueur qui vient de terminer (partie qui
## continue) et sa fermeture, qui enchaine sur "Remove your darts".
var _awaiting_rank_close := false

var _auto_overlay: Control
var _auto_banner: SpinBanner
var _auto_dart: TextureRect
var _auto_badge: TargetValueBadge
var _auto_dart_tween: Tween

var _zap_overlay: Control
var _zap_name: Label
var _zap_image: TextureRect
var _zap_flash: ColorRect
var _zap_tween: Tween
## Incremente a chaque affichage ou masquage de l'animation de zap : un
## affichage ou un masquage differe (timer) devenu obsolete est abandonne.
var _zap_token := 0

static func _build_all_darts() -> Array[DartHit]:
	var darts: Array[DartHit] = []
	for segment in range(1, 21):
		for multiplier in range(1, 4):
			darts.append(DartHit.create(segment, multiplier))
	darts.append(DartHit.create(DartHit.BULL, 1))
	darts.append(DartHit.create(DartHit.BULL, 2))
	return darts

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)
	rank_announcement_closed.connect(_on_rank_announcement_closed)
	_create_auto_entry_overlay()
	_create_zap_overlay()

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_in_condition = _condition_type(options.get("in_condition", "Open In"))
	_out_condition = _condition_type(options.get("out_condition", "Open Out"))
	_auto_entering = options.get("auto_entering", false)
	_master_zap = options.get("master_zap", false)
	_both_ways = options.get("both_ways", false)
	_continue_after_bounce = options.get("continue_after_bounce", false)
	_auto_zap = options.get("auto_zap", false)
	_zop_behavior = options.get("zop_behavior", "Bust")
	_end_at_first_finish = options.get("end_at_first_finish", true)
	max_rounds = int(options.get("max_rounds", str(max_rounds)))

	_scores.clear()
	_entered.clear()
	_directions.clear()
	_zaps.clear()
	for _player in _players:
		_scores.append(0)
		_entered.append(false)
		_directions.append(1)
		_zaps.append(0)
	_finished.clear()
	_current_player = 0
	_awaiting_rank_close = false
	darts_per_turn = 3
	set_round(1)
	reset_turn()
	clear_history()
	_turn_history.clear()
	_start_turn()

	score_panel.set_players(_players, _both_ways)
	_refresh_rows()
	score_panel.set_current_player(_current_player)

## Jet detecte : ajoute le jet au tour, recalcule l'etat (voir
## _apply_turn_state) et l'affiche. Un rebond (sauf option), un zop ou une
## arrivee terminent le tour.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible \
			or _auto_overlay.visible or _zap_overlay.visible:
		return
	if get_remaining_darts() <= 0 or _turn_over:
		return

	_turn_hits.append(hit)
	var result := _apply_turn_state()
	add_throw(hit, result.counted)

	match result.event:
		"finish":
			# L'annonce du rang recouvre tout : pas d'animation de zap.
			var finisher: Array[String] = [_players[_current_player]]
			announce_rank(finisher, _finished.size())
			if _end_at_first_finish or _players.size() - _finished.size() <= 1:
				finish_game(_standings())
			else:
				_awaiting_rank_close = true
		_:
			if not result.zapped.is_empty():
				_show_zap(result.zapped)
				# "Remove your darts" (fin de tour ou 3e fleche) attend la fin
				# de l'animation.
				if _turn_over or get_remaining_darts() == 0:
					start_remove_darts_after_throw(ZAP_DISPLAY_DURATION)
			elif _turn_over:
				start_remove_darts_after_throw()

## Fin du tour ("Remove your darts") : un joueur toujours pas entre entre
## d'abord automatiquement (option Auto Entering), avec son animation, suivie
## de celle du zap si le jet fictif zappe quelqu'un.
func _start_remove_darts() -> void:
	if remove_darts_screen.visible:
		return
	if _needs_auto_entry():
		if _turn_auto_dart == null:
			_turn_auto_dart = _random_entry_dart()
		_turn_auto_applied = true
		var result := _apply_turn_state()
		_show_auto_entry(_turn_auto_dart)
		var delay := AUTO_ENTER_DISPLAY_DURATION
		if not result.zapped.is_empty():
			_show_zap_later(result.zapped, AUTO_ENTER_DISPLAY_DURATION)
			delay += ZAP_DISPLAY_DURATION
		start_remove_darts_after_throw(delay)
		return
	super._start_remove_darts()

func _needs_auto_entry() -> bool:
	return _auto_entering and not _game_over and not _turn_auto_applied \
		and not _entered[_current_player] and not _finished.has(_current_player)

## Jet fictif d'entree : tire uniformement parmi les jets qui satisfont
## in_condition (un rate n'entre jamais).
func _random_entry_dart() -> DartHit:
	return ALL_DARTS.filter(_satisfies_in).pick_random()

func _on_rank_announcement_closed() -> void:
	if _awaiting_rank_close:
		_awaiting_rank_close = false
		_start_remove_darts()

func _on_next_player_requested() -> void:
	_hide_auto_entry()
	_hide_zap()
	if _players.is_empty():
		return
	_turn_history.append(_capture_turn_history_entry())
	_advance_and_start_turn()

## Joueur suivant (les joueurs ayant termine sont sautes ; il en reste
## toujours au moins deux en jeu ici). Termine la partie au-dela de
## max_rounds.
func _advance_and_start_turn() -> void:
	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)
		if round_number > max_rounds:
			finish_game(_standings())
			return
	if _finished.has(_current_player):
		_advance_and_start_turn()
		return
	_start_turn()
	score_panel.set_current_player(_current_player)
	_refresh_rows()

## Cancel hit avec le tour courant vide : rouvre le tour precedent tel qu'il
## etait a sa fin (sans son entree automatique, annulee avec lui) ; ses
## fleches sont ensuite retirees une a une par throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	set_round(entry.round)
	_current_player = entry.player
	_turn_start = entry.start
	_turn_hits = entry.hits.duplicate()
	_turn_auto_dart = entry.auto_dart
	_turn_auto_applied = false
	_apply_turn_state()
	score_panel.set_current_player(_current_player)

## Cancel hit : retire la derniere vraie fleche, et avec elle l'entree
## automatique qu'elle avait declenchee (le jet fictif est garde).
func _on_throw_cancelled() -> void:
	_hide_auto_entry()
	_hide_zap()
	_turn_auto_applied = false
	if not _turn_hits.is_empty():
		_turn_hits.pop_back()
	_apply_turn_state()

func _start_turn() -> void:
	_turn_hits = []
	_turn_auto_dart = null
	_turn_auto_applied = false
	_turn_start = {
		"scores": _scores.duplicate(), "entered": _entered.duplicate(),
		"directions": _directions.duplicate(), "zaps": _zaps.duplicate(),
		"finished": _finished.duplicate(),
	}
	_turn_over = false

func _capture_turn_history_entry() -> Dictionary:
	return {
		"player": _current_player, "round": round_number, "start": _turn_start,
		"hits": _turn_hits.duplicate(), "auto_dart": _turn_auto_dart,
	}

## Recalcule l'etat courant en rejouant le tour (voir _replay_turn) et met a
## jour l'affichage. Renvoie le resultat de la derniere fleche rejouee.
func _apply_turn_state() -> Dictionary:
	var state := _replay_turn()
	_scores = state.scores
	_entered = state.entered
	_directions = state.directions
	_zaps = state.zaps
	_finished = state.finished
	_turn_over = state.turn_over
	_refresh_rows()
	return state

## Rejoue les fleches du tour (plus le jet fictif s'il est applique) depuis
## l'instantane de debut de tour. Renvoie le nouvel etat, avec "event",
## "counted" et "zapped" pour la derniere fleche (voir _play_dart).
func _replay_turn() -> Dictionary:
	var state := _turn_start.duplicate(true)
	state.turn_over = false
	state.event = ""
	state.counted = false
	state.zapped = []
	var hits := _turn_hits.duplicate()
	if _turn_auto_applied and _turn_auto_dart != null:
		hits.append(_turn_auto_dart)
	for hit in hits:
		if state.turn_over:
			break
		_play_dart(state, hit)
	return state

## Applique une fleche du joueur courant a state. Renseigne state.event
## ("", "zap", "bounce", "autozap", "zop" ou "finish"), state.counted (la
## fleche a compte : medaille doree), state.zapped (joueurs zappes par cette
## fleche, le joueur lui-meme pour un auto-zap) et state.turn_over.
func _play_dart(state: Dictionary, hit: DartHit) -> void:
	var player := _current_player
	var before := state.duplicate(true)
	state.event = ""
	state.counted = false
	state.zapped = []
	if hit.is_miss():
		return

	# Entree : la fleche d'entree compte ; en Both Ways, la parite du segment
	# (sans le multiplicateur, bull = 25 impair) choisit le sens.
	if not state.entered[player]:
		if not _satisfies_in(hit):
			return
		state.entered[player] = true
		state.directions[player] = -1 if _both_ways and hit.segment % 2 == 1 else 1
		state.scores[player] = 0 if state.directions[player] > 0 else TARGET

	state.counted = true
	var direction: int = state.directions[player]
	var target := TARGET if direction > 0 else 0
	var previous: int = state.scores[player]
	var score := previous + direction * hit.get_score()
	var bounced := false
	if score > TARGET:
		score = 2 * TARGET - score
		bounced = true
	elif score < 0:
		score = -score
		bounced = true
	state.scores[player] = score

	if bounced and _auto_zap and score == previous:
		state.entered[player] = false
		state.zaps[player] += 1
		state.zapped = [player]
		state.event = "autozap"
		state.turn_over = true
		return

	# Zap de tous les joueurs en jeu au meme score (avant d'evaluer une
	# arrivee : un zap sur la cible compte deja pour Master Zap).
	for other in _players.size():
		if other != player and state.entered[other] and not state.finished.has(other) \
				and state.scores[other] == score:
			state.entered[other] = false
			state.zaps[player] += 1
			state.zapped.append(other)
			state.event = "zap"

	if score == target:
		state.turn_over = true
		if _satisfies_out(hit) and (not _master_zap or state.zaps[player] > 0):
			state.finished.append(player)
			state.event = "finish"
			return
		state.event = "zop"
		match _zop_behavior:
			"Bust":
				# Seule cette fleche est annulee (ses zaps compris).
				for key in ["scores", "entered", "directions", "zaps", "finished"]:
					state[key] = before[key]
				state.counted = false
				state.zapped = []
			"Auto-Zap":
				# Le joueur s'auto-zappe (en plus d'eventuels zaps de la fleche).
				state.entered[player] = false
				state.zaps[player] += 1
				state.zapped.append(player)
		return

	if bounced:
		if state.event == "":
			state.event = "bounce"
		state.turn_over = not _continue_after_bounce

## Classement final : les joueurs arrives dans leur ordre d'arrivee, puis les
## autres par distance a leur cible (321, ou 0 en chemin inverse ; un joueur
## "Out" est a 321), ex aequo a distance egale.
func _standings() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({
			"name": _players[i], "score": _score_text(i),
			"arrival": _finished.find(i), "distance": _distance(i),
		})
	return rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		if a.arrival >= 0 and b.arrival >= 0:
			return a.arrival < b.arrival
		if (a.arrival >= 0) != (b.arrival >= 0):
			return a.arrival >= 0
		return a.distance < b.distance)

func _distance(index: int) -> int:
	if not _entered[index]:
		return TARGET
	return absi(_target(index) - _scores[index])

func _target(index: int) -> int:
	return TARGET if _directions[index] > 0 else 0

func _score_text(index: int) -> String:
	return str(_scores[index]) if _entered[index] or _finished.has(index) else "Out"

## Vrai si une seule fleche respectant out_condition peut amener le joueur
## sur sa cible.
func _can_finish_in_one(index: int) -> bool:
	if not _entered[index] or _finished.has(index):
		return false
	var distance := _distance(index)
	if distance == 0:
		return false
	for dart in ALL_DARTS:
		if dart.get_score() == distance and _satisfies_out(dart):
			return true
	return false

func _refresh_rows() -> void:
	for i in _players.size():
		var direction := _directions[i] if _both_ways and _entered[i] and not _finished.has(i) else 0
		var zap_state := ZapBolt.State.ON if _zaps[i] > 0 else ZapBolt.State.OFF
		if _zaps[i] == 0 and _master_zap and _can_finish_in_one(i):
			zap_state = ZapBolt.State.WARNING
		score_panel.set_row(i, _score_text(i), direction, zap_state, _hint_for(i))

## Texte d'aide d'un joueur : son rang s'il a termine, la condition d'entree
## s'il est "Out", "Zop" s'il est reste sur sa cible, puis ce qu'il lui faut
## pour terminer quand c'est possible en une fleche.
func _hint_for(index: int) -> String:
	var arrival := _finished.find(index)
	if arrival >= 0:
		return "Rank #%d" % (arrival + 1)
	if not _entered[index]:
		return "" if _in_condition == "None" else "Need a %s to enter" % _in_condition.to_lower()
	if _scores[index] == _target(index):
		return "Zop! Score to bounce"
	if not _can_finish_in_one(index):
		return ""
	if _master_zap and _zaps[index] == 0:
		return "Need a zap to finish"
	if _out_condition == "None":
		return "Need %d to finish" % _distance(index)
	return "Need a %s to finish" % _out_condition.to_lower()

## Type de condition d'une option In/Out telle qu'affichee ("Open In",
## "Double Out"...) : "None" pour Open, sinon "Double", "Triple" ou
## "Master".
func _condition_type(option_value: String) -> String:
	var kind := option_value.get_slice(" ", 0)
	return "None" if kind == "Open" else kind

func _satisfies_in(hit: DartHit) -> bool:
	return _satisfies(_in_condition, hit)

func _satisfies_out(hit: DartHit) -> bool:
	return _satisfies(_out_condition, hit)

func _satisfies(condition: String, hit: DartHit) -> bool:
	match condition:
		"Double": return hit.is_double()
		"Triple": return hit.is_triple()
		"Master": return hit.is_master()
		_: return true

## Overlay "Auto Enter!" sur la zone de score : fleche (derriere), texte,
## puis medaille du jet fictif en dessous. Masque par defaut.
func _create_auto_entry_overlay() -> void:
	_auto_overlay = Control.new()
	_auto_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La fleche entre et sort par les bords de la zone de score.
	_auto_overlay.clip_contents = true
	_auto_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auto_overlay.visible = false
	score_area.add_child(_auto_overlay)

	_auto_dart = TextureRect.new()
	_auto_dart.texture = DART_TEXTURE
	_auto_dart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_auto_dart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_auto_dart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_dart.size = AUTO_ENTER_DART_SIZE
	_auto_dart.pivot_offset = AUTO_ENTER_DART_SIZE / 2.0
	# dart.png a la pointe en bas : -90 degres la tourne vers la droite, la
	# fleche traversant de gauche a droite.
	_auto_dart.rotation_degrees = -90.0
	_auto_overlay.add_child(_auto_dart)

	_auto_banner = SpinBanner.new()
	_auto_banner.texture = AUTO_ENTER_TEXTURE
	_auto_banner.place_centered(AUTO_ENTER_SIZE, AUTO_ENTER_OFFSET)
	_auto_overlay.add_child(_auto_banner)

	_auto_badge = THROW_BADGE.instantiate()
	_auto_badge.set_anchors_preset(Control.PRESET_CENTER)
	_auto_badge.offset_left = -AUTO_ENTER_BADGE_SIZE.x / 2.0 + AUTO_ENTER_BADGE_OFFSET.x
	_auto_badge.offset_right = AUTO_ENTER_BADGE_SIZE.x / 2.0 + AUTO_ENTER_BADGE_OFFSET.x
	_auto_badge.offset_top = -AUTO_ENTER_BADGE_SIZE.y / 2.0 + AUTO_ENTER_BADGE_OFFSET.y
	_auto_badge.offset_bottom = AUTO_ENTER_BADGE_SIZE.y / 2.0 + AUTO_ENTER_BADGE_OFFSET.y
	_auto_overlay.add_child(_auto_badge)

func _show_auto_entry(hit: DartHit) -> void:
	_hide_auto_entry()
	_auto_overlay.visible = true
	_auto_banner.play()
	_auto_badge.show_hit(hit, true)
	_auto_badge.play_appear(AUTO_ENTER_BADGE_DELAY)

	var area := _auto_overlay.size
	var y := area.y / 2.0 + AUTO_ENTER_OFFSET.y - AUTO_ENTER_DART_SIZE.y / 2.0
	_auto_dart.position = Vector2(-AUTO_ENTER_DART_SIZE.x * 1.5, y)
	_auto_dart_tween = create_tween()
	_auto_dart_tween.tween_property(_auto_dart, "position:x", area.x + AUTO_ENTER_DART_SIZE.x * 0.5, AUTO_ENTER_DART_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Overlay de zap sur la zone de score : nom du ou des joueurs zappes,
## image "Zap!" (au-dessus du nom) et flash blanc. Masque par defaut.
func _create_zap_overlay() -> void:
	_zap_overlay = Control.new()
	_zap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zap_overlay.visible = false
	score_area.add_child(_zap_overlay)

	_zap_name = Label.new()
	_zap_name.add_theme_font_size_override("font_size", ZAP_NAME_FONT_SIZE)
	_zap_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_zap_name.add_theme_constant_override("outline_size", 24)
	_zap_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zap_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zap_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zap_name.size = ZAP_NAME_SIZE
	_zap_name.pivot_offset = ZAP_NAME_SIZE / 2.0
	_zap_overlay.add_child(_zap_name)

	_zap_image = TextureRect.new()
	_zap_image.texture = ZAP_TEXTURE
	_zap_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zap_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_zap_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zap_image.size = ZAP_SIZE
	_zap_image.pivot_offset = ZAP_SIZE / 2.0
	_zap_overlay.add_child(_zap_image)

	_zap_flash = ColorRect.new()
	_zap_flash.color = Color(1, 1, 1, 0)
	_zap_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zap_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zap_overlay.add_child(_zap_flash)

## Anime le zap des joueurs zapped (indices) : le nom apparait et tremble de
## plus en plus fort, "Zap!" tombe du haut et le frappe (flash, le nom
## s'ecrase puis rebondit), puis le tout disparait apres ZAP_HOLD_DURATION.
func _show_zap(zapped: Array) -> void:
	_hide_zap()
	var names := PackedStringArray()
	for index in zapped:
		names.append(_players[index])
	_zap_name.text = " & ".join(names)
	_zap_name.add_theme_font_size_override("font_size", _fit_zap_name_font_size(_zap_name.text))
	_zap_overlay.visible = true

	var center := _zap_overlay.size / 2.0
	var name_position := center + ZAP_NAME_OFFSET - ZAP_NAME_SIZE / 2.0
	var zap_position := center + ZAP_OFFSET - ZAP_SIZE / 2.0
	_zap_name.position = name_position
	_zap_name.scale = Vector2.ONE * 0.3
	_zap_name.modulate.a = 0.0
	_zap_image.position = Vector2(zap_position.x, -ZAP_SIZE.y - _zap_overlay.global_position.y)
	_zap_image.scale = Vector2.ONE * 1.3
	_zap_image.visible = false
	_zap_flash.color.a = 0.0

	_zap_tween = create_tween()
	# 1. Le nom apparait...
	_zap_tween.tween_property(_zap_name, "modulate:a", 1.0, ZAP_NAME_APPEAR_DURATION)
	_zap_tween.parallel().tween_property(_zap_name, "scale", Vector2.ONE, ZAP_NAME_APPEAR_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2. ... et tremble de plus en plus fort.
	_zap_tween.tween_method(func(strength: float):
		_zap_name.position = name_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* ZAP_NAME_SHAKE_AMPLITUDE * strength, 0.0, 1.0, ZAP_NAME_SHAKE_DURATION)
	# 3. "Zap!" tombe du haut...
	_zap_tween.tween_callback(func(): _zap_image.visible = true)
	_zap_tween.tween_property(_zap_image, "position:y", zap_position.y, ZAP_FALL_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_zap_tween.parallel().tween_method(func(strength: float):
		_zap_name.position = name_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* ZAP_NAME_SHAKE_AMPLITUDE * strength, 1.0, 1.0, ZAP_FALL_DURATION)
	# 4. ... et frappe le nom : flash, le nom s'ecrase puis rebondit.
	_zap_tween.tween_callback(func():
		_zap_name.position = name_position
		_zap_name.scale = ZAP_SQUASH_SCALE
		_zap_flash.color.a = ZAP_FLASH_ALPHA)
	_zap_tween.tween_property(_zap_name, "scale", Vector2.ONE, ZAP_SQUASH_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_zap_tween.parallel().tween_property(_zap_image, "scale", Vector2.ONE, ZAP_SQUASH_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_zap_tween.parallel().tween_property(_zap_flash, "color:a", 0.0, ZAP_FLASH_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 5. Le tout reste affiche puis disparait. (Methodes plutot que lambdas
	# pour les timers : deconnectees automatiquement si l'ecran est libere.)
	get_tree().create_timer(ZAP_DISPLAY_DURATION).timeout.connect(_on_zap_display_elapsed.bind(_zap_token))

func _on_zap_display_elapsed(token: int) -> void:
	if token == _zap_token:
		_hide_zap()

## Lance l'animation de zap apres delay secondes (ex. apres "Auto Enter!"),
## sauf si entre-temps elle a ete masquee (Cancel hit, joueur suivant).
func _show_zap_later(zapped: Array, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(_on_zap_delay_elapsed.bind(zapped, _zap_token))

func _on_zap_delay_elapsed(zapped: Array, token: int) -> void:
	if token == _zap_token and _turn_auto_applied:
		_hide_auto_entry()
		_show_zap(zapped)

func _hide_zap() -> void:
	_zap_token += 1
	if _zap_tween:
		_zap_tween.kill()
		_zap_tween = null
	_zap_overlay.visible = false

## Taille de police du ou des noms zappes : ZAP_NAME_FONT_SIZE, reduite pour
## que le texte tienne dans ZAP_NAME_SIZE.
func _fit_zap_name_font_size(text: String) -> int:
	var font := _zap_name.get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ZAP_NAME_FONT_SIZE).x \
		+ _zap_name.get_theme_constant("outline_size")
	if width <= ZAP_NAME_SIZE.x:
		return ZAP_NAME_FONT_SIZE
	return maxi(floori(ZAP_NAME_FONT_SIZE * ZAP_NAME_SIZE.x / width), 1)

func _hide_auto_entry() -> void:
	if _auto_dart_tween:
		_auto_dart_tween.kill()
		_auto_dart_tween = null
	_auto_banner.stop()
	_auto_badge.clear()
	_auto_overlay.visible = false
