class_name Bobs27Rules
extends RefCounted

## Regles de Bob's 27, sans affichage. Les participants (joueurs, ou equipes
## en variante) commencent a 27 points et parcourent les numeros 1 a 20 dans
## la zone choisie (option Target : double, triple, simple exterieur ou simple
## interieur). A chaque numero, chaque participant encore en jeu joue une
## volee de 3 flechettes (une equipe fait jouer ses membres a tour de role,
## un membre par numero). Avec H flechettes dans la zone exacte du numero, de
## valeur V : +H x V si H > 0, -V si H = 0 (une seule fois, en fin de volee).
## Un score strictement negatif elimine le participant (0 est permis). Des
## qu'il n'en reste qu'un en jeu, il gagne aussitot ; sinon, apres le 20, le
## meilleur score gagne (les egalites partagent la place : aucun departage
## n'est defini). En solo, la partie s'arrete a l'elimination ou apres le 20.

const TARGETS := ["Double", "Triple", "Single Outer", "Single Inner"]
const LAST_NUMBER := 20
const START_SCORE := 27

## Etat d'une nouvelle partie. `teams` : listes d'index de joueurs, une par
## participant (une liste d'un joueur hors variante en equipe) ; `names` :
## nom de chaque participant.
static func new_state(teams: Array, names: Array[String], target: String) -> Dictionary:
	var entities: Array[Dictionary] = []
	for i in teams.size():
		entities.append({"name": names[i], "members": teams[i], "score": START_SCORE,
			"alive": true, "out_at": 0, "hits": 0})
	return {"entities": entities, "target": target, "number": 1, "turn": 0,
		"over": false, "last_result": ""}

static func current(state: Dictionary) -> Dictionary:
	return state.entities[state.turn]

## Joueur (index dans l'ordre de passage) qui lance la volee en cours : pour
## une equipe, ses membres a tour de role, un par numero.
static func current_thrower(state: Dictionary) -> int:
	var members: Array = current(state).members
	return members[(state.number - 1) % members.size()]

## Valeur d'une reussite sur le numero `number`.
static func value(target: String, number: int) -> int:
	match target:
		"Double":
			return number * 2
		"Triple":
			return number * 3
	return number

## Vrai si `hit` est dans la zone exacte demandee du numero `number`. Un
## simple dont la source ne donne pas la zone ne compte pour aucune des deux.
static func is_hit(hit: DartHit, target: String, number: int) -> bool:
	if hit.is_miss() or hit.segment != number:
		return false
	match target:
		"Double":
			return hit.is_double()
		"Triple":
			return hit.is_triple()
		"Single Outer":
			return hit.multiplier == 1 and hit.zone == DartHit.Zone.OUTER
		"Single Inner":
			return hit.multiplier == 1 and hit.zone == DartHit.Zone.INNER
	return false

static func count_hits(hits: Array[DartHit], target: String, number: int) -> int:
	var count := 0
	for hit in hits:
		if is_hit(hit, target, number):
			count += 1
	return count

## Libelle de la cible du numero `number` : "D7", "T7", "7 outer", "7 inner".
static func target_label(target: String, number: int) -> String:
	match target:
		"Double":
			return "D%d" % number
		"Triple":
			return "T%d" % number
		"Single Outer":
			return "%d outer" % number
		"Single Inner":
			return "%d inner" % number
	return str(number)

static func alive_count(state: Dictionary) -> int:
	var count := 0
	for entity in state.entities:
		if entity.alive:
			count += 1
	return count

## Applique la volee `hits` du participant en cours.
static func apply_volley(state: Dictionary, hits: Array[DartHit]) -> void:
	var entity := current(state)
	var v := value(state.target, state.number)
	var h := count_hits(hits, state.target, state.number)
	entity.hits += h
	entity.score += h * v if h > 0 else -v
	var label := target_label(state.target, state.number)
	if h > 0:
		state.last_result = "%s: %d x %s, +%d" % [entity.name, h, label, h * v]
	else:
		state.last_result = "%s: no %s, -%d" % [entity.name, label, v]
	if entity.score < 0:
		entity.alive = false
		entity.out_at = state.number
		state.last_result += ", eliminated"
	var left := alive_count(state)
	if left == 0 or (left == 1 and state.entities.size() > 1):
		state.over = true

## Passe au participant suivant encore en jeu, ou au numero suivant ; la
## partie se termine apres le 20.
static func advance(state: Dictionary) -> void:
	if state.over:
		return
	for j in range(state.turn + 1, state.entities.size()):
		if state.entities[j].alive:
			state.turn = j
			return
	state.number += 1
	if state.number > LAST_NUMBER:
		state.over = true
		return
	for j in state.entities.size():
		if state.entities[j].alive:
			state.turn = j
			return

## Classement final : en jeu par score decroissant, puis elimines du plus
## tardif au plus precoce ; egalites a la meme place.
static func standings_entries(state: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entity in state.entities:
		entries.append({"name": entity.name, "score": entity.score, "alive": entity.alive,
			"out_at": entity.out_at,
			"stats": "" if entity.alive else "Eliminated on %s" % target_label(state.target, entity.out_at)})
	return entries

static func better(a: Dictionary, b: Dictionary) -> bool:
	if a.alive != b.alive:
		return a.alive
	if a.alive:
		return a.score > b.score
	return a.out_at > b.out_at

static func copy(state: Dictionary) -> Dictionary:
	return state.duplicate(true)
