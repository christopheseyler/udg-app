class_name CricketMark3D
extends Node3D

## Marque de fermeture d'une valeur au Cricket, en 3D : deux barres croisees
## par-dessus un anneau (assets/udg-3d-assets/cricket_mark), 1 unite de large,
## face avant vers +Z. Chaque partie est une ampoule : eteinte, elle est
## sombre, brillante et un peu transparente ; allumee, elle brille en jaune,
## chacune a part (set_lit(), set_marks()). Les trois peuvent aussi s'allumer
## ensemble en rouge (set_red()), par-dessus les jaunes. Une partie qui
## s'allume (ou passe du jaune au rouge) flashe : son emission part de
## `flash_gain` fois sa valeur normale et y revient avec un petit rebond.
## L'emission des parties allumees depasse le seuil du glow de
## l'environnement : elles rayonnent quand il est actif.

enum Part { FIRST_BAR, SECOND_BAR, RING }

## Ampoule eteinte : verre fonce, un peu transparent.
const OFF_COLOR := Color(0.03, 0.03, 0.04, 0.78)
const YELLOW := Color(1.0, 0.82, 0.1)
const RED := Color(1.0, 0.1, 0.06)

## Energie de l'emission d'une partie allumee.
@export var emission_energy: float = 1.3
## Emission au debut du flash d'allumage, par rapport a la normale, et duree du
## retour a la normale.
@export var flash_gain: float = 2.5
@export var flash_duration: float = 0.35

var _materials: Array[StandardMaterial3D] = []
var _lit: Array[bool] = [false, false, false]
var _red := false
## Couleur affichee de chaque partie (transparente : eteinte), et flash en cours.
var _shown: Array[Color] = [Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT]
var _flashes: Array[Tween] = [null, null, null]

## Chaque partie a son materiau, que set_lit() et set_red() modifient. La
## pre-passe de profondeur de la transparence ne laisse voir que la surface la
## plus proche : ni les faces internes, ni l'anneau sous les barres.
func _ready() -> void:
	for node: Node3D in [$FirstBar, $SecondBar, $Ring]:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.roughness = 0.08
		material.metallic_specular = 0.7
		material.emission_enabled = true
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = material
		_materials.append(material)
	for part in Part.values():
		_update(part)

## Allume (ou eteint) une partie en jaune.
func set_lit(part: Part, lit: bool) -> void:
	_lit[part] = lit
	_update(part)

## Allume en jaune les `count` premieres parties (premiere barre, seconde
## barre, anneau) et eteint les autres : la marque d'une valeur touchee
## `count` fois.
func set_marks(count: int) -> void:
	for part in Part.values():
		set_lit(part, part < count)

## Allume les trois parties en rouge, ou les rend a leur etat jaune ou eteint.
func set_red(red: bool) -> void:
	_red = red
	for part in Part.values():
		_update(part)

func _update(part: Part) -> void:
	var material := _materials[part]
	var on := _red or _lit[part]
	var colour := (RED if _red else YELLOW) if on else Color.TRANSPARENT
	if colour == _shown[part]:
		return
	_shown[part] = colour
	if _flashes[part]:
		_flashes[part].kill()
	material.albedo_color = colour if on else OFF_COLOR
	material.emission = colour
	material.emission_energy_multiplier = emission_energy if on else 0.0
	if on and is_inside_tree():
		material.emission_energy_multiplier = emission_energy * flash_gain
		_flashes[part] = create_tween()
		_flashes[part].tween_property(material, "emission_energy_multiplier", emission_energy,
				flash_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
