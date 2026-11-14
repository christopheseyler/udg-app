class_name OneTwentyOneScreen
extends GameScreen

## Ecran de jeu du 121, base sur le template GameScreen. Regles dans
## OneTwentyOneRules ; chaque joueur joue une volee de 3 flechettes a tour de
## role, avec sa propre progression. Le panneau (HeaderScorePanel) montre pour
## le joueur en cours son objectif, son score restant, ses flechettes
## disponibles pour l'objectif et son palier, et une ligne par joueur.
##
## Comme dans Halve It, l'etat d'un joueur n'est jamais modifie fleche par
## fleche : la volee en cours est rejouee a chaque jet depuis l'instantane du
## debut de volee, et chaque volee terminee garde son instantane dans
## _turn_history pour Cancel hit. Une reussite ou un bust termine la volee
## avant sa 3e flechette.
##
## Max Rounds (ajout a la specification, qui ne prevoit pas de fin) :
## Unlimited par defaut, la partie s'arrete alors par Back ; sinon, apres ce
## nombre de rounds, les joueurs sont classes par plus haut objectif reussi.

const RESULT_TEXTS := {"success": "Checkout! Next target: %d", "bust": "Bust!", "fail": "Target missed: back to %d"}

@onready var score_panel: HeaderScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _settings: Dictionary = {}
var _max_rounds := 0
var _states: Array[Dictionary] = []
var _current := 0
var _turn_start: Dictionary = {}
var _turn_hits: Array[DartHit] = []
var _turn_history: Array[Dictionary] = []
var _turn_finalized := false
var _last_result := ""

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	var start := int(options.get("start", "121"))
	_settings = {
		"start": start,
		"darts_per_target": int(options.get("darts_per_target", "9")),
		"out_condition": options.get("out_condition", "Double Out"),
		"safety": options.get("safety", true),
		"fail_rule": options.get("fail_rule", "Back to Start"),
	}
	var rounds: String = options.get("max_rounds", "Unlimited")
	_max_rounds = 0 if rounds == "Unlimited" else int(rounds)
	_states.clear()
	for _player in _players:
		_states.append(OneTwentyOneRules.new_player(start))
	_current = 0
	darts_per_turn = 3
	set_round(1)
	reset_turn()
	clear_history()
	_turn_history.clear()
	_last_result = ""
	score_panel.set_players(_players)
	_start_turn()

func _start_turn() -> void:
	_turn_start = _states[_current].duplicate()
	_turn_hits = []
	_turn_finalized = false
	announce_player(_current)
	_refresh_panel()

func _volley(end_of_volley: bool) -> Dictionary:
	return OneTwentyOneRules.play_volley(_turn_start, _turn_hits, _settings, end_of_volley)

func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0 or _volley(false).volley_over:
		return
	var before: int = _volley(false).remaining
	_turn_hits.append(hit)
	var result := _volley(false)
	add_throw(hit, result.outcome == "success" or (result.outcome != "bust" and result.remaining < before))
	if result.volley_over and get_remaining_darts() > 0:
		start_remove_darts_after_throw()
	_refresh_panel()

## Fin de volee : applique son resultat avant "Remove your darts".
func _start_remove_darts() -> void:
	if not _turn_finalized:
		var result := _volley(true)
		_last_result = "%s: %s" % [_players[_current], _result_text(result)] if result.outcome != "" else ""
		result.erase("outcome")
		result.erase("volley_over")
		_states[_current] = result
		_turn_finalized = true
		_refresh_panel()
	super._start_remove_darts()

func _result_text(result: Dictionary) -> String:
	match result.outcome:
		"success":
			return RESULT_TEXTS.success % result.target
		"fail":
			return RESULT_TEXTS.fail % result.target
	return RESULT_TEXTS.get(result.outcome, "")

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append({"player": _current, "start": _turn_start, "hits": _turn_hits.duplicate(),
		"round": round_number, "result": _last_result})
	_current = (_current + 1) % _players.size()
	if _current == 0:
		if _max_rounds > 0 and round_number >= _max_rounds:
			_announce_result()
			return
		set_round(round_number + 1)
	_start_turn()

func _on_previous_player_requested() -> void:
	if _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	_current = entry.player
	_turn_start = entry.start
	_states[_current] = _turn_start.duplicate()
	_turn_hits = entry.hits.duplicate()
	_turn_finalized = false
	set_round(entry.round)
	_last_result = ""
	_refresh_panel()

func _on_throw_cancelled() -> void:
	if not _turn_hits.is_empty():
		_turn_hits.pop_back()
	if _turn_finalized:
		_states[_current] = _turn_start.duplicate()
		_turn_finalized = false
	_refresh_panel()

## Etat affiche d'un joueur : la volee en cours pour le joueur courant.
func _view(index: int) -> Dictionary:
	if index == _current and not _turn_finalized and not _game_over:
		return _volley(false)
	return _states[index]

func _refresh_panel() -> void:
	var view := _view(_current)
	var floor_value := OneTwentyOneRules.floor_of(view, _settings.start)
	var darts_left: int = _settings.darts_per_target - view.used
	var subtitle := "Remaining: %d · Darts left: %d" % [view.remaining, darts_left]
	if _settings.safety:
		subtitle += " · Safe: %s" % (str(view.safe) if view.safe > 0 else "none")
	var result := _last_result
	if not _turn_finalized and view.get("outcome", "") in ["success", "bust"]:
		result = _result_text(view)
	score_panel.set_header("%s · Target: %d" % [_players[_current], view.target] if not _game_over else "Game over",
		subtitle if not _game_over else "", result)
	for i in _players.size():
		var row := _view(i)
		var hint := "Target %d · %d darts left" % [row.target, _settings.darts_per_target - row.used]
		if _settings.safety and row.safe > 0:
			hint += " · Safe %d" % row.safe
		if _game_over:
			hint = "Best: %s" % (str(row.best) if row.best > 0 else "-")
		score_panel.set_row(i, str(row.remaining), hint, _settings.safety and row.safe > 0)
	score_panel.set_current_player(_current if not _game_over else -1)

## Fin de partie (Max Rounds) : classement par plus haut objectif reussi,
## puis par nombre d'objectifs reussis ; egalites a la meme place.
func _announce_result() -> void:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({"name": _players[i], "score": _states[i].best, "successes": _states[i].successes})
	var standings := rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score or (a.score == b.score and a.successes > b.successes))
	var winners: Array[String] = []
	for entry in standings:
		if entry.rank == 1:
			winners.append(entry.name)
	announce_rank(winners, 1)
	finish_game(standings)
	_refresh_panel()
