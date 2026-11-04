class_name LogoMover
extends Node3D

## Partie mobile d'un decor de logo du carrousel (GameDefinition.logo_decoration),
## comme les flechettes de X01 (LogoFloat) ou les rouages de Around the Clock
## (LogoSpin) : GameLogo3D fusionne les maillages de chacun de ces noeuds a
## part, dans son repere, pour qu'ils continuent a bouger (voir
## GameLogo3D._merge_meshes()). Le noeud bouge autour de sa position de repos,
## sa transformation a son entree dans l'arbre, et y revient en le quittant.
## Son temps part de _start_time() a son entree dans l'arbre : les parties d'un
## meme decor y entrent ensemble, et restent en phase.

var _rest: Transform3D
var _time := 0.0

func _enter_tree() -> void:
	_rest = transform
	_time = _start_time()

func _exit_tree() -> void:
	transform = _rest

func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		transform = _moved(_rest, _time)

## Transformation du noeud a l'instant `time`, depuis sa position de repos.
func _moved(rest: Transform3D, _t: float) -> Transform3D:
	return rest

## Instant de depart du mouvement, en secondes.
func _start_time() -> float:
	return 0.0
