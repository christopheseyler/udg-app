class_name X01Screen
extends GameScreen

## Ecran de jeu du X01, base sur le template GameScreen. Le panneau de score
## (X01ScorePanel) liste les joueurs avec leur score et ce qu'ils doivent
## faire ; le joueur en cours est en surbrillance et passe au suivant avec
## le bouton Next player. Options lues : start_value, in_condition,
## out_condition, same_score_hit (voir x01_game.gd).
##
## Decompte : tant que le joueur n'est pas entre (condition in_condition),
## ses jets ne comptent pas. Un bust (score negatif, score a 0 sans
## satisfaire out_condition, ou score a 1 alors que out_condition exige un
## double/triple) annule tout le tour, y compris ses effets same_score_hit
## sur d'autres joueurs (voir plus bas) : tout revient a ce que c'etait au
## debut du tour, qui se termine aussitot. Un score exactement a 0 en
## respectant out_condition termine la partie pour ce joueur : avec
## end_at_first_finish (par defaut), il gagne et la partie s'arrete ; sinon
## il sort du jeu avec son rang (ordre d'arrivee, voir _finished) et les
## autres continuent, jusqu'a ce qu'il ne reste qu'un joueur. Au-dela de
## max_rounds, la partie s'arrete aussi. Dans tous les cas, l'ecran de
## classement suit (voir _standings).
##
## same_score_hit : quand un jet amene le joueur courant exactement au score
## d'un autre joueur, applique un effet a cet autre joueur (Wipe-Out ou
## Give-me your darts, voir _replay_turn). Cumulatif : plusieurs jets peuvent
## amener plusieurs joueurs sur le meme score qu'un meme joueur B avant que B
## ne rejoue.
##
## L'etat courant (scores, entree, dette de fleches, nombre de fleches du
## tour) n'est jamais modifie au coup par coup : il est entierement recalcule
## par _replay_turn() a partir d'un instantane pris au debut du tour en
## cours et de la liste des jets de ce tour (_turn_hits). Chaque tour termine
## garde son propre instantane de depart dans _turn_history (voir
## _capture_turn_history_entry), donc Cancel hit peut remonter tour par tour
## sans limite jusqu'au tout debut de la partie, en annulant a chaque fois
## les jets un a un puis en restaurant l'instantane exact du tour precedent
## (scores, entree et dette de TOUS les joueurs) : les effets same_score_hit
## sur d'autres joueurs (Wipe-Out, fleches donnees) sont annules tout aussi
## correctement que le score du joueur courant, quel que soit le nombre de
## tours ecoules depuis.

## Score maximal terminable en une fleche selon la condition de sortie : en
## dessous, le joueur voit ce qu'il doit faire pour finir.
const MAX_FINISH := {"None": 60, "Double": 40, "Triple": 60, "Master": 60}

## Image "Bust!" affichee au centre de la zone de score quand le joueur fait
## un bust (SpinBanner : elle arrive en tourbillonnant et en grossissant tres
## vite, et finit par un rebond). "Remove your darts" suit apres
## BUST_DISPLAY_DURATION ; les jets sont ignores entre-temps.
const BUST_TEXTURE := preload("res://assets/games/x01/bust.png")
const BUST_SIZE := Vector2(1000, 500)
const BUST_DISPLAY_DURATION := 1.6

## Nombre de rounds (cycles complets de tous les joueurs) au-dela duquel la
## partie s'arrete, pour eviter une partie infinie (option max_rounds).
@export var max_rounds: int = 50

@onready var score_panel: X01ScorePanel = $ScoreArea/ScorePanel

var _bust_image: SpinBanner

var _players: Array[String] = []
var _scores: Array[int] = []
var _entered: Array[bool] = []
var _current_player := 0
var _in_condition := "None"
var _out_condition := "Double"
var _same_score_hit := "Nothing"
var _end_at_first_finish := true

## Joueurs ayant termine (score a 0), dans l'ordre d'arrivee : leur rang est
## leur position + 1. Ils ne jouent plus (voir _advance_and_start_turn).
## Recalcule comme le reste de l'etat (voir _apply_turn_state), depuis
## l'instantane _turn_start_finished : annuler le jet gagnant remet le
## joueur en jeu.
var _finished: Array[int] = []
## Vrai entre l'annonce du rang d'un joueur qui vient de terminer (partie qui
## continue) et sa fermeture, qui enchaine sur "Remove your darts".
var _awaiting_rank_close := false

## Nombre de fleches par tour "normal" (avant application d'une dette de
## fleches donnees ou d'un bonus). Capture la valeur de darts_per_turn au
## demarrage, plutot que de la dupliquer en dur.
var _base_darts_per_turn := 3
## Fleches dues par chaque joueur (mode "Give-me your darts"), retirees de
## son prochain tour (jusqu'a _base_darts_per_turn a la fois, voir
## _advance_and_start_turn).
var _dart_debt: Array[int] = []

## Jets du tour en cours (parallele a GameScreen._throws, mais avec les
## DartHit complets necessaires au calcul du score).
var _turn_hits: Array[DartHit] = []
## Instantane complet pris au debut du tour en cours : point de depart que
## _replay_turn() rejoue avec _turn_hits pour obtenir l'etat courant.
var _turn_start_scores: Array[int] = []
var _turn_start_entered: Array[bool] = []
var _turn_start_dart_debt: Array[int] = []
var _turn_start_darts_per_turn := 3
var _turn_start_finished: Array[int] = []
## Tours termines, dans l'ordre (parallele a GameScreen._history) : permet a
## Cancel hit de revenir au tour precedent avec son instantane de depart
## exact. Les tours entierement sautes (dette de fleches) n'y figurent pas,
## de meme qu'ils ne figurent pas dans GameScreen._history.
var _turn_history: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_base_darts_per_turn = darts_per_turn
	next_player_requested.connect(_on_next_player_requested)
	previous_player_requested.connect(_on_previous_player_requested)
	throw_cancelled.connect(_on_throw_cancelled)
	rank_announcement_closed.connect(_on_rank_announcement_closed)
	_create_bust_image()

func setup(players: Array[String], options: Dictionary) -> void:
	_players = players.duplicate()
	_in_condition = _condition_type(options.get("in_condition", "Open In"))
	_out_condition = _condition_type(options.get("out_condition", "Double Out"))
	_same_score_hit = options.get("same_score_hit", "Nothing")
	_end_at_first_finish = options.get("end_at_first_finish", true)
	max_rounds = int(options.get("max_rounds", str(max_rounds)))
	var start_value := int(options.get("start_value", "501"))

	_scores.clear()
	_entered.clear()
	_dart_debt.clear()
	_finished.clear()
	_awaiting_rank_close = false
	for _player in _players:
		_scores.append(start_value)
		_entered.append(_in_condition == "None")
		_dart_debt.append(0)
	_current_player = 0
	darts_per_turn = _base_darts_per_turn
	set_round(1)
	reset_turn()
	clear_history()

	_turn_history.clear()
	_turn_hits.clear()
	_start_turn_snapshot()

	score_panel.set_players(_players)
	for i in _players.size():
		_refresh_row(i)
	score_panel.set_current_player(_current_player)

## Jet detecte : ajoute le jet au tour en cours, recalcule l'etat complet
## (voir _apply_turn_state) puis affiche le jet comme d'habitude. Termine le
## tour aussitot sur un bust ; declare la victoire aussitot sur un score a 0
## valide.
func _on_dart_hit(hit: DartHit) -> void:
	if _game_over or confirm_overlay.visible or remove_darts_screen.visible or _bust_image.visible:
		return
	# Joueur qui vient de terminer : ses fleches restantes ne comptent plus.
	if get_remaining_darts() <= 0 or _finished.has(_current_player):
		return

	_turn_hits.append(hit)
	var result := _apply_turn_state()
	# Pas de notion de cible en X01 : chaque jet compte toujours pour le
	# score (badge toujours dore).
	add_throw(hit, true)

	if result.finished:
		var finisher: Array[String] = [_players[_current_player]]
		announce_rank(finisher, _finished.size())
		if _end_at_first_finish or _players.size() - _finished.size() <= 1:
			finish_game(_standings())
		else:
			_awaiting_rank_close = true
	elif result.busted:
		_show_bust()
		start_remove_darts_after_throw(BUST_DISPLAY_DURATION)

## Annonce du rang d'un joueur qui vient de terminer fermee, la partie
## continue : son tour se termine.
func _on_rank_announcement_closed() -> void:
	if _awaiting_rank_close:
		_awaiting_rank_close = false
		_start_remove_darts()

func _on_next_player_requested() -> void:
	_hide_bust()
	if _players.is_empty():
		return
	_turn_history.append(_capture_turn_history_entry())
	_advance_and_start_turn()

## Avance au joueur suivant (et gere le nombre de rounds), applique sa dette
## de fleches eventuelle, puis prepare son tour. S'il n'a aucune fleche a
## jouer (dette >= darts_per_turn normal), passe silencieusement au joueur
## suivant sans repasser par l'historique : ce tour n'a jamais vraiment eu
## lieu. Termine forcement (la dette totale du systeme ne peut que diminuer
## ici, aucun jet n'etant lance pendant un saut).
## Note : darts_per_turn (GameScreen) est borne a 1 minimum par son setter,
## donc on ne le met jamais a jour a une valeur <= 0 ; un tour entierement
## saute court-circuite avant de le toucher.
## Les joueurs ayant termine (_finished) sont sautes de la meme facon ; il
## en reste toujours au moins deux en jeu ici (sinon la partie est finie).
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

	var debt := _dart_debt[_current_player]
	if debt >= _base_darts_per_turn:
		_dart_debt[_current_player] -= _base_darts_per_turn
		_advance_and_start_turn()
		return

	_dart_debt[_current_player] = 0
	darts_per_turn = _base_darts_per_turn - debt

	_turn_hits = []
	_start_turn_snapshot()
	score_panel.set_current_player(_current_player)
	# La dette vient de changer (remboursee ou reduite par un saut) sans
	# passer par _apply_turn_state() : rafraichir explicitement, sinon les
	# gommettes restent affichees avec l'ancienne valeur jusqu'au prochain
	# jet lance.
	for i in _players.size():
		_refresh_row(i)

## Revient au tour du joueur precedent (Cancel hit avec le tour courant
## vide) : restaure son instantane de depart et ses jets, qui seront retires
## un a un par les appels suivants a throw_cancelled.
func _on_previous_player_requested() -> void:
	if _players.is_empty() or _turn_history.is_empty():
		return
	var entry: Dictionary = _turn_history.pop_back()
	# Round du tour restaure tel qu'enregistre : des tours saute (dette,
	# joueurs ayant termine) empechent de le deduire du joueur courant.
	set_round(entry.round)

	_current_player = entry.player
	_turn_start_scores = entry.start_scores.duplicate()
	_turn_start_entered = entry.start_entered.duplicate()
	_turn_start_dart_debt = entry.start_dart_debt.duplicate()
	_turn_start_darts_per_turn = entry.start_darts_per_turn
	_turn_start_finished = entry.start_finished.duplicate()
	_turn_hits = entry.hits.duplicate()
	_apply_turn_state()
	score_panel.set_current_player(_current_player)

func _on_throw_cancelled() -> void:
	# Le jet annule est forcement celui du bust (plus aucun jet n'est accepte
	# ensuite) : le bust n'a plus lieu d'etre.
	_hide_bust()
	if _turn_hits.is_empty():
		return
	_turn_hits.pop_back()
	_apply_turn_state()

## Prend l'instantane de depart du tour qui commence pour _current_player :
## scores, entree et dette de TOUS les joueurs, plus le nombre de fleches du
## tour. _replay_turn() rejouera toujours depuis cet instantane, jamais a
## partir de l'etat courant : c'est ce qui rend Cancel hit correct, y
## compris pour les effets same_score_hit sur d'autres joueurs.
func _start_turn_snapshot() -> void:
	_turn_start_scores = _scores.duplicate()
	_turn_start_entered = _entered.duplicate()
	_turn_start_dart_debt = _dart_debt.duplicate()
	_turn_start_darts_per_turn = darts_per_turn
	_turn_start_finished = _finished.duplicate()

func _capture_turn_history_entry() -> Dictionary:
	return {
		"player": _current_player,
		"round": round_number,
		"hits": _turn_hits.duplicate(),
		"start_scores": _turn_start_scores.duplicate(),
		"start_entered": _turn_start_entered.duplicate(),
		"start_dart_debt": _turn_start_dart_debt.duplicate(),
		"start_darts_per_turn": _turn_start_darts_per_turn,
		"start_finished": _turn_start_finished.duplicate(),
	}

## Recalcule integralement l'etat courant (scores et entree de tous les
## joueurs, dette de fleches, nombre de fleches du tour) en rejouant
## _turn_hits depuis l'instantane de debut de tour, et met a jour
## l'affichage. Rejouer entierement a chaque jet (plutot que d'ajuster l'etat
## au coup par coup) rend Cancel hit correct par construction : annuler un
## jet annule aussi tout ce qu'il avait declenche, y compris sur un autre
## joueur (Wipe-Out, fleches donnees).
func _apply_turn_state() -> Dictionary:
	var result := _replay_turn(_turn_hits)
	if result.busted:
		# Bust : le tour entier est annule, effets same_score_hit compris,
		# comme s'il n'avait jamais eu lieu.
		_scores = _turn_start_scores.duplicate()
		_entered = _turn_start_entered.duplicate()
		_dart_debt = _turn_start_dart_debt.duplicate()
		darts_per_turn = _turn_start_darts_per_turn
	else:
		_scores = result.scores
		_entered = result.entered
		_dart_debt = result.dart_debt
		darts_per_turn = result.darts_per_turn
	_finished = _turn_start_finished.duplicate()
	if result.finished:
		_finished.append(_current_player)

	for i in _players.size():
		_refresh_row(i)
	return result

## Rejoue une suite de jets du joueur courant depuis l'instantane de debut de
## tour. S'arrete des qu'un jet gagne la partie (score a 0 valide) ou fait un
## bust. Une egalite de score avec un autre joueur (autre que par un jet
## rate) applique l'effet same_score_hit configure a cet autre joueur : voir
## la doc en tete de fichier.
func _replay_turn(hits: Array[DartHit]) -> Dictionary:
	var scores := _turn_start_scores.duplicate()
	var entered := _turn_start_entered.duplicate()
	var dart_debt := _turn_start_dart_debt.duplicate()
	var turn_darts := _turn_start_darts_per_turn
	var busted := false
	var finished := false
	var player := _current_player

	for hit in hits:
		if not entered[player]:
			if not _satisfies_in(hit):
				continue
			entered[player] = true

		var new_score: int = scores[player] - hit.get_score()
		if _is_bust(new_score, hit):
			busted = true
			break

		scores[player] = new_score
		if new_score == 0:
			finished = true
			break

		if _same_score_hit != "Nothing" and not hit.is_miss():
			for i in _players.size():
				# Les joueurs ayant termine ne sont plus concernes.
				if i != player and scores[i] == new_score and not _turn_start_finished.has(i):
					turn_darts = _apply_same_score_hit(i, hit, scores, dart_debt, turn_darts)

	return {
		"scores": scores, "entered": entered, "dart_debt": dart_debt,
		"darts_per_turn": turn_darts, "busted": busted, "finished": finished,
	}

## Applique l'effet "meme score" au joueur other_index (jamais le joueur
## courant), sur les copies de travail de _replay_turn, et renvoie le nombre
## de fleches du tour a jour. Wipe-Out : son score retombe a 0, sans avoir a
## re-satisfaire in_condition (il reste "dans la partie"). Give-me your
## darts : il donne au joueur courant autant de fleches que le
## multiplicateur du jet qui a provoque l'egalite (simple = 1, double = 2,
## triple = 3), a lancer tout de suite dans le meme tour ; ces fleches seront
## retirees de son prochain tour (voir _advance_and_start_turn).
func _apply_same_score_hit(other_index: int, hit: DartHit, scores: Array[int], dart_debt: Array[int], turn_darts: int) -> int:
	match _same_score_hit:
		"Wipe-Out":
			scores[other_index] = 0
		"Give-me your darts":
			var count := hit.multiplier
			dart_debt[other_index] += count
			turn_darts += count
	return turn_darts

## Type de condition d'une option In/Out telle qu'affichee (voir
## x01_game.gd : "Open In", "Double Out"...) : "None" pour Open, sinon
## "Double", "Triple" ou "Master".
func _condition_type(option_value: String) -> String:
	var kind := option_value.get_slice(" ", 0)
	return "None" if kind == "Open" else kind

func _satisfies_in(hit: DartHit) -> bool:
	match _in_condition:
		"Double": return hit.is_double()
		"Triple": return hit.is_triple()
		"Master": return hit.is_master()
		_: return true

func _satisfies_out(hit: DartHit) -> bool:
	match _out_condition:
		"Double": return hit.is_double()
		"Triple": return hit.is_triple()
		"Master": return hit.is_master()
		_: return true

## Un score negatif, un score a 0 sans respecter out_condition, ou un score a
## 1 alors que out_condition exige un double ou un triple (aucun ne vaut 1)
## sont des bust.
func _is_bust(new_score: int, hit: DartHit) -> bool:
	if new_score < 0:
		return true
	if new_score == 0:
		return not _satisfies_out(hit)
	if new_score == 1 and _out_condition != "None":
		return true
	return false

## Image "Bust!" centree sur la zone de score, au-dessus du panneau de score
## (et sous le panneau lateral et les ecrans d'overlay), masquee par defaut.
func _create_bust_image() -> void:
	_bust_image = SpinBanner.new()
	_bust_image.texture = BUST_TEXTURE
	_bust_image.place_centered(BUST_SIZE)
	score_area.add_child(_bust_image)

func _show_bust() -> void:
	_bust_image.play()

func _hide_bust() -> void:
	_bust_image.stop()

## Classement final : les joueurs ayant termine dans leur ordre d'arrivee
## (voir _finished), puis ceux encore en jeu par points restants croissants
## (ex aequo a points egaux).
func _standings() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in _players.size():
		entries.append({"name": _players[i], "score": _scores[i], "arrival": _finished.find(i)})
	return rank_standings(entries, func(a: Dictionary, b: Dictionary) -> bool:
		if a.arrival >= 0 and b.arrival >= 0:
			return a.arrival < b.arrival
		if (a.arrival >= 0) != (b.arrival >= 0):
			return a.arrival >= 0
		return a.score < b.score)

func _refresh_row(index: int) -> void:
	score_panel.set_row(index, _scores[index], _hint_for(index))
	score_panel.set_debt(index, _dart_debt[index])

## Texte d'aide du joueur : son rang s'il a termine, sinon condition
## d'entree tant qu'il n'est pas entre dans la partie, puis condition de
## sortie quand son score devient terminable.
func _hint_for(index: int) -> String:
	var arrival := _finished.find(index)
	if arrival >= 0:
		return "Rank #%d" % (arrival + 1)
	if not _entered[index]:
		return "Need a %s to enter" % _in_condition.to_lower()
	if _scores[index] > MAX_FINISH[_out_condition]:
		return ""
	if _out_condition == "None":
		return "Need %d to finish" % _scores[index]
	return "Need a %s to finish" % _out_condition.to_lower()
