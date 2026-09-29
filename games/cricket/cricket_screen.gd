class_name CricketScreen
extends GameScreen

## Ecran de jeu du Cricket, base sur le template GameScreen (regles
## detaillees : voir "cricket rules.txt" ; leur application est dans
## CricketRules). Chaque joueur ferme les 7 cibles (3 marques chacune) ; les
## marques en trop scorent (Straight : pour soi ; Cut-Throat : pour les
## adversaires qui ont la cible ouverte). Gagne celui qui a tout ferme avec
## un score strictement meilleur que tous les joueurs encore en jeu.
##
## - Fin de tour : penalite Elite (CricketRules.end_turn).
## - Debut de tour : nouvelles valeurs des cibles en Crazy (animees dans
##   l'en-tete du panneau).
## - Fin de round : elimination Score or Die (tampon "ELIMINATED") ; la tete
##   de mort au-dessus du numero de round annonce un round Score or Die.
## - Fin : comme au 321 Zap (end_at_first_finish, max_rounds) ; les joueurs
##   qui n'ont pas gagne sont classes selon Ending Rank, les elimines en
##   dernier.
##
## Comme au 321 Zap, l'etat n'est jamais modifie fleche par fleche : il est
## recalcule a chaque changement en rejouant les fleches du tour depuis
## l'instantane pris a son debut (voir _replay_turn), et chaque tour termine
## garde son instantane dans _turn_history : Cancel hit est donc toujours
## exact, fin de tour (Elite), nouvelles valeurs et eliminations comprises.

## Tete de mort d'un round Score or Die, au-dessus de "Round #x" : elle
## apparait en rebondissant puis bat doucement tant que le round dure.
const SCORE_OR_DIE_TEXTURE := preload("res://assets/games/cricket/score_or_die.png")
const SKULL_HEIGHT := 150.0
const SKULL_APPEAR_DURATION := 0.8
const SKULL_BEAT_SCALE := 1.08
const SKULL_BEAT_DURATION := 0.45

@export var max_rounds: int = 10

@onready var score_panel: CricketScorePanel = $ScoreArea/ScorePanel

var _rules := CricketRules.new()
var _players: Array[String] = []
var _end_at_first_finish := true

## Etat courant de la partie (voir CricketRules).
var _state: Dictionary = {}
var _current_player := 0
var _turn_hits: Array[DartHit] = []
## Instantane de debut de tour, que _replay_turn rejoue.
var _turn_start: Dictionary = {}
## Tours termines (parallele a GameScreen._history), pour Cancel hit.
var _turn_history: Array[Dictionary] = []
## Gagnants a annoncer l'un apres l'autre (partie qui continue apres le
## premier gagnant : un gagnant peut en faire gagner d'autres, voir
## CricketRules.check_winners).
var _pending_ranks: Array[int] = []
## Jets ignores jusqu'a cet instant (Time.get_ticks_msec) : tampon
## "ELIMINATED" en cours.
var _blocked_until := 0

var _skull_holder: Control
var _skull: TextureRect
var _skull_tween: Tween

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)
	rank_announcement_closed.connect(_on_rank_announcement_closed)
	_create_skull()

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_rules.configure(options)
	_end_at_first_finish = options.get("end_at_first_finish", true)
	max_rounds = int(options.get("max_rounds", str(max_rounds)))

	_state = _rules.new_state(_players.size())
	_current_player = 0
	_pending_ranks.clear()
	_blocked_until = 0
	darts_per_turn = 3
	reset_turn()
	clear_history()
	_turn_history.clear()
	_start_turn()
	set_round(1)

	score_panel.set_players(_players, _rules.value_pool())
	var drawn: Array = range(CricketRules.BULL_INDEX) if _rules.is_wild() else []
	score_panel.set_values(_state.values, drawn)
	_refresh_rows()
	score_panel.set_current_player(_current_player)

func set_round(number: int) -> void:
	super.set_round(number)
	_update_skull()

## Jet detecte : ajoute le jet au tour, recalcule l'etat et l'affiche. Un
## joueur qui gagne termine son tour.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible \
			or Time.get_ticks_msec() < _blocked_until:
		return
	if get_remaining_darts() <= 0 or _state.turn_over:
		return

	_turn_hits.append(hit)
	var winners := _apply_turn_state()
	add_throw(hit, _state.counted)
	if not winners.is_empty():
		_announce_winners(winners)

## Annonce les nouveaux gagnants. La partie se termine au premier gagnant
## (end_at_first_finish) ou quand il ne reste qu'un joueur en jeu ; sinon
## les gagnants sont annonces l'un apres l'autre et la partie reprend.
func _announce_winners(winners: Array[int]) -> void:
	if _end_at_first_finish or _rules.active_players(_state).size() <= 1:
		var first: Array[String] = [_players[winners[0]]]
		announce_rank(first, _state.finished.find(winners[0]) + 1)
		finish_game(_standings())
		return
	_pending_ranks = winners.duplicate()
	_announce_next_rank()

func _announce_next_rank() -> void:
	var player: int = _pending_ranks.pop_front()
	var names: Array[String] = [_players[player]]
	announce_rank(names, _state.finished.find(player) + 1)

## Annonce fermee : gagnant suivant, puis "Remove your darts" si le tour du
## joueur est termine (il a gagne, ou c'etait sa derniere fleche).
func _on_rank_announcement_closed() -> void:
	if not _pending_ranks.is_empty():
		_announce_next_rank()
		return
	if _state.turn_over or get_remaining_darts() == 0:
		_start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_rules.end_turn(_state, _current_player)
	_turn_history.append({
		"player": _current_player, "round": round_number, "start": _turn_start,
		"hits": _turn_hits.duplicate(),
	})
	_advance_and_start_turn()

## Joueur suivant en jeu (les joueurs ayant gagne ou elimines sont sautes ;
## il en reste toujours au moins deux ici). En fin de round : elimination
## Score or Die, puis fin de la partie au-dela de max_rounds.
func _advance_and_start_turn() -> void:
	var eliminated: Array[int] = []
	while true:
		_current_player = (_current_player + 1) % _players.size()
		if _current_player == 0:
			eliminated.append_array(_rules.apply_score_or_die(_state, round_number))
			set_round(round_number + 1)
			if round_number > max_rounds:
				_refresh_rows()
				_play_eliminated(eliminated)
				finish_game(_standings())
				return
		if _rules.is_active(_state, _current_player):
			break
	var changed := _start_turn()
	score_panel.set_values(_state.values, changed)
	score_panel.set_current_player(_current_player)
	_refresh_rows()
	_play_eliminated(eliminated)

func _play_eliminated(eliminated: Array[int]) -> void:
	if eliminated.is_empty():
		return
	score_panel.play_eliminated(eliminated)
	_blocked_until = Time.get_ticks_msec() + int(CricketScorePanel.STAMP_DISPLAY_DURATION * 1000.0)

## Cancel hit avec le tour courant vide : rouvre le tour precedent tel qu'il
## etait a sa fin (avant sa penalite Elite, et avec les valeurs et les
## joueurs en jeu d'alors) ; ses fleches sont ensuite retirees une a une par
## throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	_current_player = entry.player
	_turn_start = entry.start
	_turn_hits = entry.hits.duplicate()
	_apply_turn_state()
	set_round(entry.round)
	score_panel.set_values(_state.values)
	score_panel.set_current_player(_current_player)

func _on_throw_cancelled() -> void:
	if not _turn_hits.is_empty():
		_turn_hits.pop_back()
	_apply_turn_state()

## Debut du tour du joueur courant : nouvelles valeurs en Crazy, puis
## instantane. Renvoie les cibles dont la valeur a change.
func _start_turn() -> Array[int]:
	var changed := _rules.reroll_crazy_values(_state)
	_rules.begin_turn(_state)
	_turn_hits = []
	_turn_start = _state.duplicate(true)
	return changed

## Recalcule l'etat courant en rejouant le tour (voir _replay_turn) et met a
## jour l'affichage. Renvoie les gagnants de la derniere fleche rejouee.
func _apply_turn_state() -> Array[int]:
	var winners: Array[int] = []
	_state = _turn_start.duplicate(true)
	_rules.begin_turn(_state)
	for hit in _turn_hits:
		if _state.turn_over:
			break
		winners = _rules.play_dart(_state, _current_player, hit, not _end_at_first_finish)
	_refresh_rows()
	return winners

func _refresh_rows() -> void:
	for player in _players.size():
		var slots := []
		for target in CricketRules.TARGET_COUNT:
			var marks: int = mini(_state.marks[player][target], CricketRules.MARKS_TO_CLOSE)
			if marks == CricketRules.MARKS_TO_CLOSE and _rules.is_closed_by_all(_state, target):
				slots.append(CricketScorePanel.Slot.CLOSED_BY_ALL)
			else:
				slots.append(marks)
		score_panel.set_row(player, _state.scores[player], slots,
			_rules.is_bull_locked(_state, player), _state.finished.find(player) + 1,
			_rules.is_eliminated(_state, player), _rules.is_protected(_state, _current_player, player))

## Tete de mort Score or Die, au-dessus du numero de round dans le panneau
## lateral. L'image est dans un controle simple : le conteneur du panneau
## remettrait son echelle a 1 a chaque mise en page.
func _create_skull() -> void:
	_skull_holder = Control.new()
	_skull_holder.custom_minimum_size.y = SKULL_HEIGHT
	_skull_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skull_holder.visible = false
	var content := round_label.get_parent()
	content.add_child(_skull_holder)
	content.move_child(_skull_holder, round_label.get_index())

	_skull = TextureRect.new()
	_skull.texture = SCORE_OR_DIE_TEXTURE
	_skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skull.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skull.resized.connect(func(): _skull.pivot_offset = _skull.size / 2.0)
	_skull_holder.add_child(_skull)

## Montre la tete de mort pendant un round Score or Die (apparition en
## rebondissant puis battement), la masque sinon.
func _update_skull() -> void:
	if _skull_holder == null or _state.is_empty():
		return
	var shown := _rules.is_score_or_die_round(_state, round_number)
	if shown == _skull_holder.visible:
		return
	_skull_holder.visible = shown
	if _skull_tween:
		_skull_tween.kill()
		_skull_tween = null
	_skull.scale = Vector2.ONE
	if not shown:
		return
	_skull.scale = Vector2.ONE * 0.1
	_skull_tween = create_tween()
	_skull_tween.tween_property(_skull, "scale", Vector2.ONE, SKULL_APPEAR_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_skull_tween.tween_callback(_start_skull_beat)

func _start_skull_beat() -> void:
	_skull_tween = create_tween().set_loops()
	_skull_tween.tween_property(_skull, "scale", Vector2.ONE * SKULL_BEAT_SCALE, SKULL_BEAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_skull_tween.tween_property(_skull, "scale", Vector2.ONE, SKULL_BEAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Classement final de tous les joueurs (voir CricketRules.is_better_standing).
func _standings() -> Array[Dictionary]:
	return rank_standings(_rules.standing_entries(_state, _players), _rules.is_better_standing)
