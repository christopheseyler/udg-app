class_name EnvironmentGlow
extends RefCounted

## Glow de l'environnement d'un monde 3D, partage entre les noeuds qui le
## demandent, comme la lueur de l'eclair de 3-2-1 Zap (LogoGlow) ou la marque
## du logo Cricket, avec pour poids l'opacite de leur logo. Sur la carte, le
## glow fait passer le carrousel de 60 a une cinquantaine d'images par seconde,
## et alourdit tout le reste de la scene (les autres logos estompes, leurs
## decors) : il ne tourne que tant qu'un noeud le demande avec un poids d'au
## moins MIN_WEIGHT, soit pour un logo au centre de l'ecran ou presque (a moins
## de 13 degres sur le carrousel). Son intensite y monte de 0 a celle de
## l'environnement entre MIN_WEIGHT et un poids de 1 : il apparait et disparait
## en fondu pendant le defilement.

const MIN_WEIGHT := 0.9

## Par environnement : intensite du glow a poids 1, et poids de chacun des
## noeuds qui le demandent ({Node3D: poids}).
static var _intensities: Dictionary = {}
static var _weights: Dictionary = {}
## Environnement de chaque noeud qui demande le glow.
static var _environments: Dictionary = {}

## Demande le glow de l'environnement du monde de `node` avec ce poids (0 : ne
## le demande plus, mais reste compte). A rappeler a chaque changement de poids.
static func request(node: Node3D, weight: float) -> void:
	var environment: Environment = _environments.get(node)
	if not environment:
		environment = node.get_world_3d().environment if node.is_inside_tree() else null
		if not environment:
			return
		_environments[node] = environment
		_intensities.get_or_add(environment, environment.glow_intensity)
	_weights.get_or_add(environment, {})[node] = weight
	_update(environment)

## Retire la demande de `node` (a sa sortie de l'arbre).
static func release(node: Node3D) -> void:
	var environment: Environment = _environments.get(node)
	if environment:
		_environments.erase(node)
		_weights[environment].erase(node)
		_update(environment)

static func _update(environment: Environment) -> void:
	var weights: Dictionary = _weights[environment]
	var top: float = weights.values().max() if weights else 0.0
	if environment.glow_enabled != (top >= MIN_WEIGHT):
		environment.glow_enabled = top >= MIN_WEIGHT
	environment.glow_intensity = _intensities[environment] * clampf((top - MIN_WEIGHT) / (1.0 - MIN_WEIGHT), 0.0, 1.0)
