class_name Bobs27Screen
extends GameScreen

## Ecran de jeu de Bob's 27, base sur le template GameScreen. Regles dans
## Bobs27Rules ; le panneau (HeaderScorePanel) affiche la cible du numero en
## cours et sa valeur, le resultat de la derniere volee et une ligne par
## participant (joueur, ou equipe en variante), les elimines etant signales.
##
## Variante en equipe (option Teams) : les joueurs sont repartis dans
## l'ordre de passage, le 1er dans l'equipe 1, le 2e dans l'equipe 2, etc. ;
## chaque equipe fait jouer ses membres a tour de role, un membre par numero.
##
## Comme dans Halve It, la volee en cours est recalculee a chaque jet depuis
## l'instantane de son debut, et chaque volee terminee garde le sien dans
## _turn_history pour Cancel hit.

@onready var score_panel: HeaderScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _state: Dictionary = {}
var _turn_start_state: Dictionary = {}
var _turn_hits: Array[DartHit] = []
var _turn_history: Array[Dictionary] = []
var _turn_finalized := false

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	var team_count := 0
	var teams_option: String = options.get("teams", "Off")
	if teams_option != "Off":
		team_count = mini(int(teams_option.get_slice(" ", 0)), _players.size())
	var teams: Array = []
	var names: Array[String] = []
	if team_count >= 2:
		for t in team_count:
			var members: Array[int] = []
			var member_names: PackedStringArray = []
			for i in range(t, _players.size(), team_count):
				members.append(i)
				member_names.append(_players[i])
			teams.append(members)
			names.append(" & ".join(member_names))
	else:
		for i in _players.size():
			teams.append([i])
			names.append(_players[i])
	_state = Bobs27Rules.new_state(teams, names, options.get("target", "Double"))
	darts_per_turn = 3
	reset_turn()
	clear_history()
	_turn_history.clear()
	score_panel.set_players(names)
	_start_turn()

func _start_turn() -> void:
	_turn_start_state = Bobs27Rules.copy(_state)
	_turn_hits = []
	_turn_finalized = false
	set_round(_state.number)
	announce_player(Bobs27Rules.current_thrower(_state))
	_refresh_panel()

func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0:
		return
	_turn_hits.append(hit)
	add_throw(hit, Bobs27Rules.is_hit(hit, _state.target, _state.number))
	_refresh_panel()

## Fin de volee : applique son resultat (penalite comprise) avant "Remove
## your darts".
func _start_remove_darts() -> void:
	if not _turn_finalized:
		_state = Bobs27Rules.copy(_turn_start_state)
		Bobs27Rules.apply_volley(_state, _turn_hits)
		_turn_finalized = true
		_refresh_panel()
	super._start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append({"state": _turn_start_state, "hits": _turn_hits.duplicate()})
	Bobs27Rules.advance(_state)
	if _state.over:
		_announce_result()
		return
	_start_turn()

func _on_previous_player_requested() -> void:
	if _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	_turn_start_state = entry.state
	_state = Bobs27Rules.copy(_turn_start_state)
	_turn_hits = entry.hits.duplicate()
	_turn_finalized = false
	set_round(_state.number)
	_refresh_panel()

func _on_throw_cancelled() -> void:
	if not _turn_hits.is_empty():
		_turn_hits.pop_back()
	if _turn_finalized:
		_state = Bobs27Rules.copy(_turn_start_state)
		_turn_finalized = false
	_refresh_panel()

func _refresh_panel() -> void:
	var view := _state if _turn_finalized or _game_over else _turn_start_state
	var number: int = mini(view.number, Bobs27Rules.LAST_NUMBER)
	var v := Bobs27Rules.value(view.target, number)
	var h := Bobs27Rules.count_hits(_turn_hits, view.target, number)
	var title := "Game over" if _game_over else "Target: %s" % Bobs27Rules.target_label(view.target, number)
	var subtitle := "" if _game_over else "Hit: +%d each · All missed: -%d" % [v, v]
	score_panel.set_header(title, subtitle, view.last_result)

	for i in view.entities.size():
		var entity: Dictionary = view.entities[i]
		var hint := ""
		var score: int = entity.score
		if not entity.alive:
			hint = "Eliminated on %s" % Bobs27Rules.target_label(view.target, entity.out_at)
		elif i == view.turn and not _turn_finalized and not _game_over:
			var thrower := _players[Bobs27Rules.current_thrower(view)]
			hint = "%d hit%s" % [h, "" if h == 1 else "s"]
			if entity.members.size() > 1:
				hint = "%s throws · %s" % [thrower, hint]
			score += h * v
		score_panel.set_row(i, str(score), hint, false)
	score_panel.set_current_player(view.turn if not _game_over else -1)

func _announce_result() -> void:
	var standings := rank_standings(Bobs27Rules.standings_entries(_state), Bobs27Rules.better)
	var winners: Array[String] = []
	for entry in standings:
		if entry.rank == 1:
			winners.append(entry.name)
	announce_rank(winners, 1)
	finish_game(standings)
	_refresh_panel()
