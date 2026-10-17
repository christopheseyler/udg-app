class_name AroundTheClockScreen
extends GameScreen

## Ecran de jeu de l'Around the Clock, base sur le template GameScreen (voir
## around_the_clock_rules.txt). Chaque joueur a sa cible courante, qui
## avance le long du parcours du mode de jeu (_path : 1 a 20, puis le Bull en
## Classic Extended et en The Irish Way) ; le panneau de score
## (AroundTheClockScorePanel) affiche la cible courante de chaque joueur.
## Options lues : game_mode, max_rounds, end_at_first_finish (voir
## around_the_clock_game.gd).
##
## Classic / Classic Extended : toute fleche sur la cible courante (simple,
## double ou triple ; simple ou double Bull) la valide et fait passer a la
## suivante, plusieurs fois par tour si besoin.
## The Irish Way : de 1 a 9, un double avance de 2 et un triple de 3 ; sur
## le 10, un double 10 envoie directement au Bull (raccourci), simple et
## triple 10 avancent de 1 ; de 11 a 20, toute touche avance de 1. Sur le
## Bull, il faut deux Bulls dans le meme tour (un double Bull compte pour
## deux) ; les Bulls d'un tour ne se cumulent pas avec le suivant.
##
## Un joueur qui valide la derniere cible a termine ; ses fleches restantes
## ne comptent plus. Avec end_at_first_finish (par defaut), il gagne et la
## partie s'arrete ; sinon il sort du jeu avec son rang (ordre d'arrivee,
## voir _finished) et les autres continuent, jusqu'a ce que tous aient
## termine. En The Irish Way, un joueur qui termine apres avoir pris le
## raccourci du 10 arrete toujours la partie. Au-dela de max_rounds, la
## partie s'arrete aussi ; dans tous les cas, l'ecran de classement suit
## (voir _standings).
##
## Comme dans X01, l'etat courant n'est jamais modifie fleche par fleche : il
## est recalcule par _replay_turn() a partir de l'instantane pris au debut
## du tour et des jets de ce tour (_turn_hits). Chaque tour termine garde son
## instantane dans _turn_history, ce qui permet a Cancel hit de remonter tour
## par tour jusqu'au debut de la partie.

const CLASSIC := "Classic"
const EXTENDED := "Classic Extended"
const IRISH := "The Irish Way"
## The Irish Way : derniere cible ou doubles et triples font avancer plus
## vite, cible du raccourci vers le Bull, et nombre de Bulls a toucher dans
## le meme tour pour gagner.
const IRISH_BONUS_LAST_TARGET := 9
const IRISH_SHORTCUT_TARGET := 10
const IRISH_BULLS_TO_WIN := 2

## Nombre de rounds (cycles complets de tous les joueurs) au-dela duquel la
## partie s'arrete (option max_rounds).
@export var max_rounds: int = 10

@onready var score_panel: AroundTheClockScorePanel = $ScoreArea/ScorePanel

var _players: Array[String] = []
var _game_mode := CLASSIC
var _end_at_first_finish := true
## Parcours du mode de jeu : valeurs des cibles dans l'ordre (25 = Bull).
var _path: Array[int] = []
var _current_player := 0

## Etat de chaque joueur : nombre de cibles validees (sa cible courante est
## _path[_progress[i]] ; _path.size() = termine), raccourci du 10 pris
## (The Irish Way) et nombre de fleches lancees depuis le debut de la
## partie (statistique du classement).
var _progress: Array[int] = []
var _shortcut: Array[bool] = []
var _darts: Array[int] = []
## Joueurs ayant termine, dans l'ordre d'arrivee : leur rang est leur
## position + 1. Ils ne jouent plus (voir _advance_and_start_turn).
var _finished: Array[int] = []
## Bulls touches ce tour par le joueur courant (The Irish Way).
var _turn_bulls := 0
## Vrai entre l'annonce du rang d'un joueur qui vient de terminer (partie qui
## continue) et sa fermeture, qui enchaine sur "Remove your darts".
var _awaiting_rank_close := false

## Jets du tour en cours (parallele a GameScreen._throws, mais avec les
## DartHit complets necessaires au calcul).
var _turn_hits: Array[DartHit] = []
## Instantane pris au debut du tour en cours : point de depart que
## _replay_turn() rejoue avec _turn_hits pour obtenir l'etat courant.
var _turn_start_progress: Array[int] = []
var _turn_start_shortcut: Array[bool] = []
var _turn_start_darts: Array[int] = []
var _turn_start_finished: Array[int] = []
## Tours termines, dans l'ordre (parallele a GameScreen._history) : permet a
## Cancel hit de revenir au tour precedent avec son instantane de depart.
var _turn_history: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)
	rank_announcement_closed.connect(_on_rank_announcement_closed)

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_game_mode = options.get("game_mode", CLASSIC)
	_end_at_first_finish = options.get("end_at_first_finish", true)
	max_rounds = int(options.get("max_rounds", str(max_rounds)))

	_path.clear()
	for value in range(1, 21):
		_path.append(value)
	if _game_mode != CLASSIC:
		_path.append(DartHit.BULL)

	_progress.clear()
	_shortcut.clear()
	_darts.clear()
	_finished.clear()
	_awaiting_rank_close = false
	for _player in _players:
		_progress.append(0)
		_shortcut.append(false)
		_darts.append(0)
	_current_player = 0
	darts_per_turn = 3
	set_round(1)
	reset_turn()
	clear_history()

	_turn_history.clear()
	_turn_hits.clear()
	_turn_bulls = 0
	_start_turn_snapshot()

	score_panel.set_players(_players)
	score_panel.set_title(_title())
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)
	announce_player(_current_player)

## Jet detecte : ajoute le jet au tour en cours, recalcule l'etat (voir
## _apply_turn_state) puis l'affiche, dore s'il a fait avancer le joueur.
## Annonce aussitot le rang d'un joueur qui vient de terminer.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible:
		return
	# Joueur qui vient de terminer : ses fleches restantes ne comptent plus.
	if get_remaining_darts() <= 0 or _finished.has(_current_player):
		return

	_turn_hits.append(hit)
	var result := _apply_turn_state()
	add_throw(hit, result.last_counted)

	if result.finished:
		var finisher: Array[String] = [_players[_current_player]]
		announce_rank(finisher, _finished.size())
		var shortcut_win := _game_mode == IRISH and _shortcut[_current_player]
		if _end_at_first_finish or shortcut_win or _finished.size() == _players.size():
			finish_game(_standings())
		else:
			_awaiting_rank_close = true

## Annonce du rang d'un joueur qui vient de terminer fermee, la partie
## continue : son tour se termine.
func _on_rank_announcement_closed() -> void:
	if _awaiting_rank_close:
		_awaiting_rank_close = false
		_start_remove_darts()

func _on_next_player_requested() -> void:
	if _players.is_empty():
		return
	_turn_history.append(_capture_turn_history_entry())
	_advance_and_start_turn()

## Avance au prochain joueur encore en jeu (et gere le nombre de rounds),
## puis prepare son tour. Il en reste toujours au moins un ici (sinon la
## partie est finie, voir _on_dart_hit).
func _advance_and_start_turn() -> void:
	_current_player = (_current_player + 1) % _players.size()
	if _current_player == 0:
		set_round(round_number + 1)
		if round_number > max_rounds:
			finish_game(_standings())
			for i in _players.size():
				_refresh_row(i)
			return

	if _finished.has(_current_player):
		_advance_and_start_turn()
		return

	_turn_hits = []
	_turn_bulls = 0
	_start_turn_snapshot()
	score_panel.set_current_player(_current_player)
	announce_player(_current_player)
	for i in _players.size():
		_refresh_row(i)

## Revient au tour du joueur precedent (Cancel hit avec le tour courant
## vide) : restaure son instantane de depart et ses jets, qui seront retires
## un a un par les appels suivants a throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	# Round restaure tel qu'enregistre : les joueurs ayant termine sont
	# sautes, on ne peut pas le deduire du joueur courant.
	set_round(entry.round)

	_current_player = entry.player
	_turn_start_progress = entry.start_progress.duplicate()
	_turn_start_shortcut = entry.start_shortcut.duplicate()
	_turn_start_darts = entry.start_darts.duplicate()
	_turn_start_finished = entry.start_finished.duplicate()
	_turn_hits = entry.hits.duplicate()
	_apply_turn_state()
	score_panel.set_current_player(_current_player)

func _on_throw_cancelled() -> void:
	if _turn_hits.is_empty():
		return
	_turn_hits.pop_back()
	_apply_turn_state()

func _start_turn_snapshot() -> void:
	_turn_start_progress = _progress.duplicate()
	_turn_start_shortcut = _shortcut.duplicate()
	_turn_start_darts = _darts.duplicate()
	_turn_start_finished = _finished.duplicate()

func _capture_turn_history_entry() -> Dictionary:
	return {
		"player": _current_player,
		"round": round_number,
		"hits": _turn_hits.duplicate(),
		"start_progress": _turn_start_progress.duplicate(),
		"start_shortcut": _turn_start_shortcut.duplicate(),
		"start_darts": _turn_start_darts.duplicate(),
		"start_finished": _turn_start_finished.duplicate(),
	}

## Recalcule l'etat courant en rejouant _turn_hits depuis l'instantane de
## debut de tour, et met a jour l'affichage.
func _apply_turn_state() -> Dictionary:
	var result := _replay_turn(_turn_hits)
	_progress = _turn_start_progress.duplicate()
	_progress[_current_player] = result.progress
	_shortcut = _turn_start_shortcut.duplicate()
	_shortcut[_current_player] = result.shortcut
	_darts = _turn_start_darts.duplicate()
	_darts[_current_player] = result.darts
	_turn_bulls = result.bulls
	_finished = _turn_start_finished.duplicate()
	if result.finished:
		_finished.append(_current_player)

	for i in _players.size():
		_refresh_row(i)
	return result

## Rejoue une suite de jets du joueur courant depuis l'instantane de debut de
## tour. S'arrete des que le joueur termine. last_counted : le dernier jet a
## fait avancer le joueur (ou compte comme Bull en The Irish Way).
func _replay_turn(hits: Array[DartHit]) -> Dictionary:
	var player := _current_player
	var progress: int = _turn_start_progress[player]
	var shortcut: bool = _turn_start_shortcut[player]
	var darts: int = _turn_start_darts[player]
	var bulls := 0
	var finished := false
	var last_counted := false

	for hit in hits:
		if finished:
			break
		darts += 1
		last_counted = false
		var target := _path[progress]
		if hit.is_miss() or hit.segment != target:
			continue
		last_counted = true

		if _game_mode != IRISH:
			progress += 1
		elif target == DartHit.BULL:
			# Un double Bull compte pour deux Bulls.
			bulls += hit.multiplier
			if bulls >= IRISH_BULLS_TO_WIN:
				progress += 1
		elif target <= IRISH_BONUS_LAST_TARGET:
			progress += hit.multiplier
		elif target == IRISH_SHORTCUT_TARGET and hit.is_double():
			progress = _path.size() - 1
			shortcut = true
		else:
			progress += 1

		finished = progress >= _path.size()

	return {
		"progress": progress, "shortcut": shortcut, "darts": darts,
		"bulls": bulls, "finished": finished, "last_counted": last_counted,
	}

func _title() -> String:
	match _game_mode:
		EXTENDED: return "1 to 20, then Bull"
		IRISH: return "The Irish Way"
		_: return "1 to 20"

func _target_label(value: int) -> String:
	return "Bull" if value == DartHit.BULL else str(value)

## Cible affichee pour un joueur : sa cible courante, ou "Done" s'il a
## termine.
func _target_text(index: int) -> String:
	if _progress[index] >= _path.size():
		return "Done"
	return _target_label(_path[_progress[index]])

## Texte d'aide du joueur : son rang s'il a termine, sinon sa progression,
## avec pour le joueur courant en The Irish Way un rappel des bonus de sa
## cible (doubles et triples, raccourci du 10, Bulls deja touches ce tour).
func _hint_for(index: int) -> String:
	var arrival := _finished.find(index)
	if arrival >= 0:
		return "Rank #%d" % (arrival + 1)
	var hint := "%d / %d" % [_progress[index], _path.size()]
	if _game_mode != IRISH or index != _current_player or _game_over:
		return hint
	var target := _path[_progress[index]]
	if target == DartHit.BULL:
		return "%s  -  Bulls %d / %d" % [hint, _turn_bulls, IRISH_BULLS_TO_WIN]
	if target <= IRISH_BONUS_LAST_TARGET:
		return "%s  -  Double +2, Triple +3" % hint
	if target == IRISH_SHORTCUT_TARGET:
		return "%s  -  D10 = Bull" % hint
	return hint

func _refresh_row(index: int) -> void:
	score_panel.set_row(index, _target_text(index), _hint_for(index))

## Classement final : les joueurs ayant termine dans leur ordre d'arrivee
## (voir _finished), puis ceux encore en jeu par cible atteinte, la plus
## avancee en premier (ex aequo sur la meme cible). Statistique : nombre de
## fleches lancees.
func _standings() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({
			"name": _players[i], "score": _target_text(i), "progress": _progress[i],
			"arrival": _finished.find(i), "stats": "%d darts" % _darts[i],
		})
	return rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		if a.arrival >= 0 and b.arrival >= 0:
			return a.arrival < b.arrival
		if (a.arrival >= 0) != (b.arrival >= 0):
			return a.arrival >= 0
		return a.progress > b.progress)
