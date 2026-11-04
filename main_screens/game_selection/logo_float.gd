class_name LogoFloat
extends LogoMover

## Fait flotter le noeud autour de sa position de repos, comme en apesanteur :
## un balancement lent de quelques millimetres et de quelques degres, sans
## periode apparente (chaque composante a sa propre frequence), comme les
## flechettes de X01 (voir LogoMover).

## Rapports de frequence des composantes du mouvement (deplacement x, y, z,
## puis rotation x, y, z), sans multiple commun simple : le mouvement ne se
## repete pas de facon visible.
const RATIOS: Array[float] = [0.83, 1.0, 0.71, 0.92, 0.61, 1.13]

## Amplitude du deplacement, en metres, dans le repere du parent.
@export var drift := Vector3(0.003, 0.006, 0.001)
## Amplitude de la rotation, en degres, autour des axes propres du noeud.
@export var sway_degrees := Vector3(0.6, 2.0, 2.0)
## Periode moyenne du mouvement, en secondes.
@export var period: float = 4.0
## Avance dans le mouvement, en fraction de periode : deux noeuds d'avances
## differentes ne bougent pas ensemble.
@export var phase: float = 0.0

func _moved(rest: Transform3D, time: float) -> Transform3D:
	var move := Vector3(drift.x * _wave(0, time), drift.y * _wave(1, time), drift.z * _wave(2, time))
	var turn := Vector3(sway_degrees.x * _wave(3, time), sway_degrees.y * _wave(4, time),
			sway_degrees.z * _wave(5, time))
	return Transform3D(rest.basis * Basis.from_euler(turn * PI / 180.0), rest.origin + move)

func _start_time() -> float:
	return phase * period

## Composante `index` du mouvement, entre -1 et 1, a l'instant `time`.
func _wave(index: int, time: float) -> float:
	return sin(TAU / period * RATIOS[index] * time + index * 1.7)
