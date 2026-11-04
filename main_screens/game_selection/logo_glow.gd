class_name LogoGlow
extends OmniLight3D

## Lueur d'un decor de logo, comme l'eclair de 3-2-1 Zap : une lumiere qui
## eclaire la cible autour de lui, et qui scintille legerement avec
## l'emission de son materiau (le glow de l'environnement du carrousel fait
## briller l'emission au-dessus de son seuil). Le glow suit l'opacite du logo
## le plus visible qui en porte une, et s'eteint sous MIN_OPACITY : sur la
## carte, il fait perdre quelques images par seconde au carrousel, qui ne le
## paie donc que quand une lueur se voit. Le scintillement est une somme
## de sinus de frequences sans multiple commun : un lent souffle et un
## tremblement plus rapide. GameLogo3D garde la lumiere telle quelle lors de
## la fusion des maillages du logo (voir GameLogo3D._merge_into()) ; le
## materiau, lui, reste celui du maillage fusionne.

## Materiau dont l'emission scintille avec la lumiere.
@export var emissive: BaseMaterial3D
## Ecart relatif maximal de l'energie autour de sa valeur de repos.
@export var flicker: float = 0.15

## [frequence en Hz, poids] des composantes du scintillement (poids de somme 1).
const WAVES: Array[Vector2] = [Vector2(0.7, 0.5), Vector2(5.3, 0.3), Vector2(11.9, 0.2)]

## Opacite sous laquelle le glow de l'environnement s'eteint.
const MIN_OPACITY := 0.1

## Opacite du logo, donnee par GameLogo3D.set_opacity().
var opacity := 1.0

## Par environnement : intensite du glow a pleine opacite, et opacite de
## chacune de ses lueurs ({LogoGlow: opacite}).
static var _intensities: Dictionary = {}
static var _opacities: Dictionary = {}

var _energy: float
var _emission: float
var _time := 0.0
var _environment: Environment

func _ready() -> void:
	_energy = light_energy
	if emissive:
		_emission = emissive.emission_energy_multiplier

func _exit_tree() -> void:
	if _environment:
		_opacities[_environment].erase(self)
		_update_glow()
		_environment = null

func _process(delta: float) -> void:
	_time += delta
	if not _environment:
		_environment = get_world_3d().environment
		if not _environment:
			return
		_intensities.get_or_add(_environment, _environment.glow_intensity)
	_opacities.get_or_add(_environment, {})[self] = opacity if is_visible_in_tree() else 0.0
	_update_glow()
	if not is_visible_in_tree():
		return
	var wave := 0.0
	for k in WAVES.size():
		wave += WAVES[k].y * sin(TAU * WAVES[k].x * _time + k * 1.3)
	var f := 1.0 + flicker * wave
	light_energy = _energy * f
	if emissive:
		emissive.emission_energy_multiplier = _emission * f

## Glow de l'environnement a l'intensite de la plus opaque de ses lueurs,
## eteint sous MIN_OPACITY.
func _update_glow() -> void:
	var glows: Dictionary = _opacities[_environment]
	var top: float = glows.values().max() if glows else 0.0
	if _environment.glow_enabled != (top > MIN_OPACITY):
		_environment.glow_enabled = top > MIN_OPACITY
	_environment.glow_intensity = _intensities[_environment] * top
