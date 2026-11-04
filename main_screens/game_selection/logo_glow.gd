class_name LogoGlow
extends OmniLight3D

## Lueur d'un decor de logo, comme l'eclair de 3-2-1 Zap : une lumiere qui
## eclaire la cible autour de lui, et qui scintille legerement avec
## l'emission de son materiau (le glow de l'environnement du carrousel fait
## briller l'emission au-dessus de son seuil). Elle demande le glow tant que
## son logo se voit, avec l'opacite du logo pour poids (voir EnvironmentGlow).
## Le scintillement est une somme de sinus de frequences sans multiple
## commun : un lent souffle et un tremblement plus rapide. GameLogo3D garde la
## lumiere telle quelle lors de la fusion des maillages du logo (voir
## GameLogo3D._merge_into()) ; le materiau, lui, reste celui du maillage
## fusionne.

## Materiau dont l'emission scintille avec la lumiere.
@export var emissive: BaseMaterial3D
## Ecart relatif maximal de l'energie autour de sa valeur de repos.
@export var flicker: float = 0.15

## [frequence en Hz, poids] des composantes du scintillement (poids de somme 1).
const WAVES: Array[Vector2] = [Vector2(0.7, 0.5), Vector2(5.3, 0.3), Vector2(11.9, 0.2)]

var _opacity := 1.0
var _energy: float
var _emission: float
var _time := 0.0

func _ready() -> void:
	_energy = light_energy
	if emissive:
		_emission = emissive.emission_energy_multiplier

## Opacite du logo (appelee par GameLogo3D.set_opacity()).
func set_logo_opacity(alpha: float) -> void:
	_opacity = alpha

func _exit_tree() -> void:
	EnvironmentGlow.release(self)

func _process(delta: float) -> void:
	_time += delta
	EnvironmentGlow.request(self, _opacity if is_visible_in_tree() else 0.0)
	if not is_visible_in_tree():
		return
	var wave := 0.0
	for k in WAVES.size():
		wave += WAVES[k].y * sin(TAU * WAVES[k].x * _time + k * 1.3)
	var f := 1.0 + flicker * wave
	light_energy = _energy * f
	if emissive:
		emissive.emission_energy_multiplier = _emission * f
