class_name DoBetterScreen
extends GameScreen

## Ecran de jeu de Beat the King, if you can (ex Do Better If You Can ; fichiers et
## classes gardent l'ancien nom), base sur le template GameScreen. Les regles sont dans DoBetterRules ; le panneau de
## score (HeaderScorePanel) affiche la cible du round, le score a battre, le
## resultat du dernier tour et les points de chaque joueur.
##
## Comme dans Halve It, rien n'est modifie fleche par fleche : l'etat de la
## partie est recalcule a la fin du tour (DoBetterRules.apply_turn) a partir
## de l'instantane pris a son debut (_turn_start_state), et chaque tour termine
## garde son instantane et ses fleches dans _turn_history, ce qui permet a
## Cancel hit de remonter tour par tour jusqu'au debut de la partie. Pendant
## le tour du master initial, sa premiere fleche fixe la cible affichee.

const LEADER_CROWN_SCENE := preload("res://games/do_better/leader_crown.tscn")

@onready var score_panel: HeaderScorePanel = $ScoreArea/ScorePanel

## Couronne posee sur la ligne du master ; elle saute sur le nouveau master
## quand le titre change de main. Ajoutee juste apres ScoreArea, donc sous le
## panneau lateral et les ecrans superposes (Remove your darts, etc.).
var leader_crown: LeaderCrown
## Joueur qui doit porter la couronne (-1 : aucun).
var _crown_player := -1

var _players: Array[String] = []
## Etat de la partie (voir DoBetterRules.new_state()), resultat du tour en
## cours compris une fois celui-ci termine (_turn_finalized).
var _state: Dictionary = {}
## Etat au debut du tour en cours.
var _turn_start_state: Dictionary = {}
var _turn_hits: Array[DartHit] = []
## Tours termines, dans l'ordre (parallele a GameScreen._history) :
## {"state": instantane de debut de tour, "hits": fleches du tour}.
var _turn_history: Array[Dictionary] = []
var _turn_finalized := false

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)
	leader_crown = LEADER_CROWN_SCENE.instantiate()
	leader_crown.row_rect = score_panel.row_rect
	score_area.add_sibling(leader_crown)
	remove_darts_screen.visibility_changed.connect(_sync_crown)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	var rounds := _players.size() * int(options.get("rounds_per_player", "2"))
	_state = DoBetterRules.new_state(_players.size(), rounds, options.get("get_the_lead", false),
		options.get("keep_the_crown", false))
	darts_per_turn = 3
	reset_turn()
	clear_history()
	_turn_history.clear()
	score_panel.name_indent_ratio = LeaderCrown.NAME_INDENT_RATIO
	score_panel.set_players(_players)
	_start_turn()

## Prepare le tour du joueur courant de _state.
func _start_turn() -> void:
	_turn_start_state = DoBetterRules.copy(_state)
	_turn_hits = []
	_turn_finalized = false
	set_round(_state.round)
	announce_player(DoBetterRules.current_player(_state))
	_refresh_panel()

func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	if get_remaining_darts() <= 0:
		return
	_turn_hits.append(hit)
	var target := DoBetterRules.turn_target(_state, _turn_hits)
	add_throw(hit, DoBetterRules.marks(hit, target) > 0)
	_refresh_panel()

## Fin du tour (3e fleche ou Next) : applique son resultat avant "Remove your
## darts", pour que les points soient deja a jour pendant que le joueur
## retire ses fleches.
func _start_remove_darts() -> void:
	var finalize := not _turn_finalized
	if finalize:
		_state = DoBetterRules.copy(_turn_start_state)
		DoBetterRules.apply_turn(_state, _turn_hits, _players)
		_turn_finalized = true
	# Ecran affiche avant la mise a jour du panneau : la couronne attend sa
	# fermeture pour sauter sur le nouveau porteur (voir _sync_crown).
	super._start_remove_darts()
	if finalize:
		_refresh_panel()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append({"state": _turn_start_state, "hits": _turn_hits.duplicate()})
	DoBetterRules.advance(_state)
	if _state.over:
		_announce_result()
		return
	_start_turn()

## Revient au tour precedent (Cancel hit avec le tour courant vide) : ses
## fleches sont ensuite retirees une a une par throw_cancelled.
func _on_previous_player_requested() -> void:
	if _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	_turn_start_state = entry.state
	_state = DoBetterRules.copy(_turn_start_state)
	_turn_hits = entry.hits.duplicate()
	_turn_finalized = false
	set_round(_state.round)
	_refresh_panel()

func _on_throw_cancelled() -> void:
	if not _turn_hits.is_empty():
		_turn_hits.pop_back()
	if _turn_finalized:
		_state = DoBetterRules.copy(_turn_start_state)
		_turn_finalized = false
	_refresh_panel()

func _refresh_panel() -> void:
	var player := DoBetterRules.current_player(_state)
	var view := _state if _turn_finalized else _turn_start_state
	var target := DoBetterRules.turn_target(_turn_start_state, _turn_hits)
	var to_beat := ""
	if not DoBetterRules.is_setting_target(_turn_start_state) or _turn_finalized:
		to_beat = "To beat: %d mark%s (%s)" % [view.best, "" if view.best == 1 else "s", _players[view.master]]
	score_panel.set_header("Target: %s" % (DoBetterRules.target_label(target) if not target.is_empty() else "first dart"),
		to_beat, view.last_result)

	var live := DoBetterRules.total_marks(_turn_hits, target)
	for i in _players.size():
		score_panel.set_row(i, str(view.points[i]), _hint_for(i, view, player, live), i == view.master and not _game_over)
	score_panel.set_current_player(player if not _game_over else -1)
	_crown_player = view.crown if not _game_over else -1
	_sync_crown()

## Pose la couronne sur _crown_player, sauf pendant "Remove your darts" qui
## cacherait son deplacement : elle part a la fermeture de cet ecran.
func _sync_crown() -> void:
	if not remove_darts_screen.visible:
		leader_crown.show_on(_crown_player)

## Etat d'un joueur dans le round : il lance (marques en cours), master,
## marques deja faites, ou rien.
func _hint_for(index: int, view: Dictionary, player: int, live: int) -> String:
	if _game_over:
		return ""
	var hint := ""
	if index == player and not _turn_finalized:
		hint = "Throwing: %d" % live
		if DoBetterRules.is_setting_target(view):
			hint = "Sets the target: %d" % live
		elif view.comeback:
			hint = "Comeback: %d" % live
	elif view.played.has(index):
		hint = "%d mark%s" % [view.played[index], "" if view.played[index] == 1 else "s"]
	if index == view.initial and index != view.master and not view.comeback:
		hint += " (first king)" if hint else "First king"
	elif index == view.master:
		hint = ("King · " + hint) if hint else "King"
	return hint

## Fin de partie : classement par points decroissants, les egalites partagent
## la place.
func _announce_result() -> void:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({"name": _players[i], "score": _state.points[i]})
	var standings := rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score)
	var winners: Array[String] = []
	for entry in standings:
		if entry.rank == 1:
			winners.append(entry.name)
	announce_rank(winners, 1)
	finish_game(standings)
	_refresh_panel()
