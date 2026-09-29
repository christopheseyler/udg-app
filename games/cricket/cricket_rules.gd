class_name CricketRules
extends RefCounted

## Regles du Cricket (voir "cricket rules.txt"), separees de l'ecran : elles
## s'appliquent a un etat de partie (Dictionary, voir new_state) que l'ecran
## duplique a chaque debut de tour et rejoue fleche par fleche (Cancel hit
## exact, comme au 321 Zap).
##
## Etat :
## - "values" : valeur des 7 cibles (les 6 numeros puis le bull, 25) ;
## - "marks" : pour chaque joueur, ses marques sur les 7 cibles (3 = fermee ;
##   jamais plus de 3, les marques en trop scorent ou penalisent) ;
## - "scores" : score de chaque joueur ;
## - "finished" : joueurs ayant gagne, dans l'ordre d'arrivee ;
## - "eliminations" : groupes de joueurs elimines par Score or Die, dans
##   l'ordre des eliminations ;
## - suivi du tour en cours (voir begin_turn) : "turn_marked" (cibles marquees
##   pendant le tour, Elite), "turn_closed" (cibles fermees pendant le tour,
##   Only in closing turn), "turn_valid" (au moins un hit valide : une marque
##   ou des points, Elite), "turn_over" (le joueur a gagne : ses fleches
##   suivantes sont ignorees) et "counted" (la derniere fleche a marque ou
##   score : medaille doree).
##
## Les joueurs ayant gagne ou elimines "disparaissent virtuellement" : ils ne
## comptent plus pour savoir si une cible est fermee par tout le monde, ne
## peuvent plus etre scores et leur score n'est plus a battre.

const TARGET_COUNT := 7
const BULL_INDEX := 6
const MARKS_TO_CLOSE := 3
const CLASSIC_VALUES: Array[int] = [15, 16, 17, 18, 19, 20]
const WILD_RANGE := Vector2i(12, 20)
const ULTRA_WILD_RANGE := Vector2i(1, 20)
## Score Maniac : facteur selon les marques du joueur score sur la cible.
const MANIAC_FACTORS: Array[int] = [3, 2, 1]
const SCORE_OR_DIE_PERIOD := 4
## Score or Die s'arrete quand il ne reste que ce nombre de joueurs en jeu.
const SCORE_OR_DIE_MIN_PLAYERS := 2

var cut_throat := true
var target_selection := "Classic"
var locked_bull := false
var score_maniac := false
var protect_the_weaks := false
var only_in_closing_turn := false
var elite := "None"
var all_closed_penalty := "None"
var ending_rank := "Score"
var score_or_die := false

## Options choisies dans l'ecran de selection (voir cricket_game.gd). Score
## Maniac et Protect the Weaks n'existent qu'en Cut-Throat.
func configure(options: Dictionary) -> void:
	cut_throat = options.get("mode", "Cut-Throat") == "Cut-Throat"
	target_selection = options.get("targets", "Classic")
	locked_bull = options.get("locked_bull", false)
	score_maniac = cut_throat and options.get("score_maniac", false)
	protect_the_weaks = cut_throat and options.get("protect_the_weaks", false)
	only_in_closing_turn = options.get("only_in_closing_turn", false)
	elite = options.get("elite", "None")
	all_closed_penalty = options.get("all_closed_penalty", "None")
	ending_rank = options.get("ending_rank", "Score")
	score_or_die = options.get("score_or_die", false)

func is_wild() -> bool:
	return target_selection != "Classic"

func is_crazy() -> bool:
	return target_selection.ends_with("Crazy")

func new_state(player_count: int) -> Dictionary:
	var marks := []
	var scores := []
	for _player in player_count:
		var player_marks := []
		player_marks.resize(TARGET_COUNT)
		player_marks.fill(0)
		marks.append(player_marks)
		scores.append(0)
	var state := {
		"values": _initial_values(), "marks": marks, "scores": scores,
		"finished": [], "eliminations": [],
	}
	begin_turn(state)
	return state

## Valeurs de depart : 15 a 20 en Classic, sinon 6 valeurs differentes tirees
## dans la plage du mode (affichees dans l'ordre croissant), puis le bull.
func _initial_values() -> Array:
	var values: Array = []
	if is_wild():
		var pool := value_pool()
		pool.shuffle()
		values = pool.slice(0, CLASSIC_VALUES.size())
		values.sort()
	else:
		values = CLASSIC_VALUES.duplicate()
	values.append(DartHit.BULL)
	return values

## Valeurs que peuvent prendre les cibles numerotees en Wild (plage du mode).
func value_pool() -> Array:
	var value_range := ULTRA_WILD_RANGE if target_selection.begins_with("Ultra") else WILD_RANGE
	return range(value_range.x, value_range.y + 1)

## Remet a zero le suivi du tour (debut du tour d'un joueur).
func begin_turn(state: Dictionary) -> void:
	var flags := []
	flags.resize(TARGET_COUNT)
	flags.fill(false)
	state.turn_marked = flags.duplicate()
	state.turn_closed = flags.duplicate()
	state.turn_valid = false
	state.turn_over = false
	state.counted = false

func is_finished(state: Dictionary, player: int) -> bool:
	return state.finished.has(player)

func is_eliminated(state: Dictionary, player: int) -> bool:
	for group in state.eliminations:
		if group.has(player):
			return true
	return false

func is_active(state: Dictionary, player: int) -> bool:
	return not is_finished(state, player) and not is_eliminated(state, player)

func active_players(state: Dictionary) -> Array[int]:
	var players: Array[int] = []
	for player in state.scores.size():
		if is_active(state, player):
			players.append(player)
	return players

func is_closed(state: Dictionary, player: int, target: int) -> bool:
	return state.marks[player][target] >= MARKS_TO_CLOSE

func has_closed_all(state: Dictionary, player: int) -> bool:
	for target in TARGET_COUNT:
		if not is_closed(state, player, target):
			return false
	return true

## Cible fermee par tous les joueurs encore en jeu.
func is_closed_by_all(state: Dictionary, target: int) -> bool:
	for player in active_players(state):
		if not is_closed(state, player, target):
			return false
	return true

## Locked Bull : le bull d'un joueur reste verrouille tant qu'il n'a pas
## ferme ses 6 autres cibles (evalue par joueur).
func is_bull_locked(state: Dictionary, player: int) -> bool:
	if not locked_bull:
		return false
	for target in BULL_INDEX:
		if not is_closed(state, player, target):
			return true
	return false

## Protect the Weaks : other est protege de player s'il a un score plus eleve
## (player ne peut scorer que les joueurs a score inferieur ou egal).
func is_protected(state: Dictionary, player: int, other: int) -> bool:
	return protect_the_weaks and other != player and state.scores[other] > state.scores[player]

## Vrai si score a est strictement meilleur que b (plus haut en Straight,
## plus bas en Cut-Throat).
func is_better_score(a: int, b: int) -> bool:
	return a < b if cut_throat else a > b

## Joue une fleche de player puis cherche les nouveaux gagnants (voir
## check_winners, chain : plusieurs gagnants a la suite, partie qui continue
## apres le premier). Renvoie ces gagnants ; si player en fait partie, son
## tour est termine.
func play_dart(state: Dictionary, player: int, hit: DartHit, chain: bool) -> Array[int]:
	_apply_dart(state, player, hit)
	var winners := check_winners(state, chain)
	if winners.has(player):
		state.turn_over = true
	return winners

func _apply_dart(state: Dictionary, player: int, hit: DartHit) -> void:
	state.counted = false
	if hit.is_miss():
		return
	var target: int = state.values.find(hit.segment)
	if target < 0:
		return
	# Bull verrouille : ni marque, ni score, ni penalite.
	if target == BULL_INDEX and is_bull_locked(state, player):
		return
	var marks: Array = state.marks[player]
	var added := mini(hit.multiplier, maxi(MARKS_TO_CLOSE - marks[target], 0))
	if added > 0:
		marks[target] += added
		state.turn_marked[target] = true
		state.turn_valid = true
		state.counted = true
		if marks[target] >= MARKS_TO_CLOSE:
			state.turn_closed[target] = true
	var extra: int = hit.multiplier - added
	if extra > 0:
		_apply_extra_marks(state, player, target, extra)

## Marques au-dela de la fermeture : elles scorent tant que d'autres joueurs
## en jeu ont la cible ouverte (et, en Only in closing turn, seulement pendant
## le tour ou le joueur l'a fermee) ; sinon c'est un hit sur une cible fermee
## par tout le monde (All Closed Hit Penalty), une penalite par marque.
func _apply_extra_marks(state: Dictionary, player: int, target: int, count: int) -> void:
	var value: int = state.values[target]
	var opponents: Array[int] = []
	for other in active_players(state):
		if other != player and not is_closed(state, other, target):
			opponents.append(other)
	if opponents.is_empty() or (only_in_closing_turn and not state.turn_closed[target]):
		_apply_penalty(state, player, target, count, value)
		return

	state.turn_valid = true
	if not cut_throat:
		state.scores[player] += value * count
		state.counted = true
		return
	# Protection evaluee sur les scores d'avant la fleche.
	var targets := opponents.filter(func(other: int) -> bool: return not is_protected(state, player, other))
	for other in targets:
		var factor: int = MANIAC_FACTORS[state.marks[other][target]] if score_maniac else 1
		state.scores[other] += value * count * factor
		state.counted = true

func _apply_penalty(state: Dictionary, player: int, target: int, count: int, value: int) -> void:
	match all_closed_penalty:
		"Score":
			if cut_throat:
				state.scores[player] += value * count
			else:
				state.scores[player] = maxi(state.scores[player] - value * count, 0)
		"Mark":
			var marks: Array = state.marks[player]
			marks[target] = maxi(marks[target] - count, 0)
			# Refermee plus tard dans ce tour, elle compterait comme fermee
			# pendant ce tour (Only in closing turn).
			state.turn_closed[target] = false

## Cherche parmi les joueurs en jeu celui qui a tout ferme avec un score
## strictement meilleur que tous les autres joueurs en jeu, l'ajoute a
## "finished" et, si chain, recommence (le gagnant ne compte plus : le
## suivant peut gagner a son tour). Il faut au moins deux joueurs en jeu.
## Renvoie les nouveaux gagnants dans l'ordre.
func check_winners(state: Dictionary, chain: bool) -> Array[int]:
	var winners: Array[int] = []
	while true:
		var active := active_players(state)
		if active.size() < 2:
			break
		var winner := -1
		for player in active:
			if not has_closed_all(state, player):
				continue
			var best := true
			for other in active:
				if other != player and not is_better_score(state.scores[player], state.scores[other]):
					best = false
					break
			if best:
				winner = player
				break
		if winner < 0:
			break
		state.finished.append(winner)
		winners.append(winner)
		if not chain:
			break
	return winners

## Fin du tour de player : penalite Elite (voir "cricket rules.txt"). Les
## cibles ouvertes non marquees pendant le tour perdent une marque ; un joueur
## qui a tout ferme (sans avoir gagne) et n'a fait aucun hit valide rouvre
## une cible au hasard (Mark) ou toutes (Mega Mark) d'une marque.
func end_turn(state: Dictionary, player: int) -> void:
	if elite == "None" or not is_active(state, player):
		return
	var marks: Array = state.marks[player]
	var open_targets := range(TARGET_COUNT).filter(func(target: int) -> bool: return not is_closed(state, player, target))
	if not open_targets.is_empty():
		for target in open_targets:
			if not state.turn_marked[target] and marks[target] > 0:
				marks[target] -= 1
		return
	if state.turn_valid:
		return
	if elite == "Mega Mark":
		for target in TARGET_COUNT:
			marks[target] -= 1
	else:
		marks[randi() % TARGET_COUNT] -= 1

## Debut de tour en mode Crazy : chaque cible numerotee ayant au moins une
## marque (d'un joueur en jeu) mais fermee par aucun joueur en jeu prend une
## nouvelle valeur, differente de toutes les cibles en cours (marques
## conservees). Renvoie les cibles changees.
func reroll_crazy_values(state: Dictionary) -> Array[int]:
	var changed: Array[int] = []
	if not is_crazy():
		return changed
	var active := active_players(state)
	for target in BULL_INDEX:
		var marked := false
		var closed := false
		for player in active:
			marked = marked or state.marks[player][target] > 0
			closed = closed or is_closed(state, player, target)
		if not marked or closed:
			continue
		var candidates := value_pool().filter(func(value: int) -> bool: return not state.values.has(value))
		if candidates.is_empty():
			continue
		state.values[target] = candidates.pick_random()
		changed.append(target)
	return changed

## Round "Score or Die" : tous les SCORE_OR_DIE_PERIOD rounds, tant qu'une
## elimination reste possible (plus de SCORE_OR_DIE_MIN_PLAYERS en jeu).
func is_score_or_die_round(state: Dictionary, round_number: int) -> bool:
	return score_or_die and round_number % SCORE_OR_DIE_PERIOD == 0 \
		and active_players(state).size() > SCORE_OR_DIE_MIN_PLAYERS

## Fin du round round_number : si c'est un round Score or Die, elimine le ou
## les joueurs en jeu au score le plus desavantageux, sauf si ca laisserait
## moins de SCORE_OR_DIE_MIN_PLAYERS joueurs. Renvoie les elimines.
func apply_score_or_die(state: Dictionary, round_number: int) -> Array[int]:
	var eliminated: Array[int] = []
	if not is_score_or_die_round(state, round_number):
		return eliminated
	var active := active_players(state)
	var worst: int = state.scores[active[0]]
	for player in active:
		if is_better_score(worst, state.scores[player]):
			worst = state.scores[player]
	for player in active:
		if state.scores[player] == worst:
			eliminated.append(player)
	if active.size() - eliminated.size() < SCORE_OR_DIE_MIN_PLAYERS:
		eliminated.clear()
		return eliminated
	state.eliminations.append(eliminated.duplicate())
	return eliminated

## Score servant au classement d'un joueur qui n'a pas termine : son score,
## ajuste en Score & Marks de la valeur des marques manquantes sur ses cibles
## ouvertes (retiree en Straight, ajoutee en Cut-Throat ; peut etre negatif).
func ranking_score(state: Dictionary, player: int) -> int:
	var score: int = state.scores[player]
	if ending_rank != "Score & Marks":
		return score
	var missing := 0
	for target in TARGET_COUNT:
		missing += maxi(MARKS_TO_CLOSE - state.marks[player][target], 0) * state.values[target]
	return score + missing if cut_throat else score - missing

func closed_count(state: Dictionary, player: int) -> int:
	return range(TARGET_COUNT).filter(func(target: int) -> bool: return is_closed(state, player, target)).size()

## Entrees du classement final, a trier avec is_better_standing (voir
## GameScreen.rank_standings) : "group" 0 pour les gagnants, 1 pour les
## joueurs encore en jeu, 2 pour les elimines, et "key" pour les departager.
func standing_entries(state: Dictionary, names: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for player in names.size():
		var entry := {"name": names[player], "score": state.scores[player]}
		var closed := "Closed %d/%d" % [closed_count(state, player), TARGET_COUNT]
		if is_finished(state, player):
			entry.group = 0
			entry.key = state.finished.find(player)
			entry.stats = closed
		elif is_eliminated(state, player):
			entry.group = 2
			entry.key = -1
			for index in state.eliminations.size():
				if state.eliminations[index].has(player):
					entry.key = index
			entry.stats = "Eliminated"
		else:
			entry.group = 1
			entry.key = ranking_score(state, player)
			entry.stats = closed
			if ending_rank == "Score & Marks":
				entry.stats += " (ranked on %d)" % entry.key
		entries.append(entry)
	return entries

## Ordre du classement final : les gagnants dans leur ordre d'arrivee, puis
## les joueurs encore en jeu par ranking_score (ex aequo a score egal), puis
## les elimines dans l'ordre inverse de leur elimination (elimines ensemble
## ex aequo).
func is_better_standing(a: Dictionary, b: Dictionary) -> bool:
	if a.group != b.group:
		return a.group < b.group
	if a.group == 0:
		return a.key < b.key
	if a.group == 1:
		return is_better_score(a.key, b.key)
	return a.key > b.key
