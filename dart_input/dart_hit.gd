class_name DartHit
extends RefCounted

## Impact d'une fleche sur la cible, tel que fourni par une source de jets
## (DartInput) : segment (1 a 20, 25 pour le bull, 0 pour un jet manque) et
## multiplicateur (1 simple, 2 double, 3 triple ; le bull ne va que jusqu'a
## 2, le double bull valant 50).

const BULL := 25
const MISS_SEGMENT := 0

var segment := MISS_SEGMENT
var multiplier := 0

## Cree un impact. Un segment 0, un multiplicateur 0 ou un segment invalide
## donnent un jet manque ; le multiplicateur est borne a ce que le segment
## permet (2 au bull, 3 ailleurs).
static func create(p_segment: int, p_multiplier: int) -> DartHit:
	var hit := DartHit.new()
	if p_segment == MISS_SEGMENT or p_multiplier <= 0:
		return hit
	if not ((p_segment >= 1 and p_segment <= 20) or p_segment == BULL):
		push_warning("DartHit: segment invalide %d, jet considere manque" % p_segment)
		return hit
	hit.segment = p_segment
	hit.multiplier = clampi(p_multiplier, 1, 2 if p_segment == BULL else 3)
	return hit

static func miss() -> DartHit:
	return DartHit.new()

func is_miss() -> bool:
	return multiplier == 0

func is_double() -> bool:
	return multiplier == 2

func is_triple() -> bool:
	return multiplier == 3

## Un "master" est un double ou un triple (le double bull compte).
func is_master() -> bool:
	return multiplier >= 2

func get_score() -> int:
	return segment * multiplier

## Libelle affiche dans le panneau des jets : "20", "D20", "T20", "25",
## "Bull" (double bull) ou "Miss".
func get_label() -> String:
	if is_miss():
		return "Miss"
	if segment == BULL:
		return "Bull" if multiplier == 2 else str(BULL)
	return ["", "", "D", "T"][multiplier] + str(segment)
