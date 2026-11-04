class_name LogoFloat
extends Node3D

## Fait flotter le noeud autour de sa position de repos, comme en apesanteur :
## un balancement lent de quelques millimetres et de quelques degres, sans
## periode apparente (chaque composante a sa propre frequence). Sert aux decors
## mobiles des logos du carrousel, comme les flechettes de X01
## (GameDefinition.logo_decoration) : GameLogo3D fusionne les maillages de
## chacun de ces noeuds a part, dans son repere, pour qu'ils continuent a
## bouger (voir GameLogo3D._merge_meshes()). La position de repos est la
## transformation du noeud a son entree dans l'arbre ; il y revient en le
## quittant.

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

var _rest: Transform3D
var _time := 0.0

func _enter_tree() -> void:
	_rest = transform
	_time = phase * period

func _exit_tree() -> void:
	transform = _rest

func _process(delta: float) -> void:
	_time += delta
	if not is_visible_in_tree():
		return
	var move := Vector3(drift.x * _wave(0), drift.y * _wave(1), drift.z * _wave(2))
	var turn := Vector3(sway_degrees.x * _wave(3), sway_degrees.y * _wave(4), sway_degrees.z * _wave(5))
	transform = Transform3D(_rest.basis * Basis.from_euler(turn * PI / 180.0), _rest.origin + move)

## Composante `index` du mouvement, entre -1 et 1, a l'instant courant.
func _wave(index: int) -> float:
	return sin(TAU / period * RATIOS[index] * _time + index * 1.7)
