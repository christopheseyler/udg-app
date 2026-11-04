extends Node3D

## Marque du logo Cricket (cricket_logo_mark.tscn), entre la cible et le nom :
## eteinte un moment, puis la premiere barre s'allume en jaune, la seconde,
## l'anneau, et toute la marque clignote en rouge avant de s'eteindre, et on
## recommence. Ses maillages restent tels quels dans le logo (groupe
## GameLogo3D.UNMERGED_GROUP), pour que CricketMark3D en change les materiaux.
## Elle demande le glow de l'environnement tant que le logo se voit (voir
## EnvironmentGlow).

## Duree de chaque etape de l'allumage (une barre, les deux, l'anneau).
@export var step_duration: float = 0.6
## Clignotements rouges, puis duree de chaque allumage et de chaque extinction.
@export var blinks: int = 3
@export var blink_on: float = 0.22
@export var blink_off: float = 0.18
## Duree de la marque eteinte, au debut de chaque cycle.
@export var dark_duration: float = 1.0

@onready var mark: CricketMark3D = $Mark

var _opacity := 1.0
var _time := 0.0
## Etat affiche, [nombre de parties jaunes, rouge] : la marque n'est modifiee
## qu'a son changement.
var _state := [0, false]

## Opacite du logo (appelee par GameLogo3D.set_opacity()).
func set_logo_opacity(alpha: float) -> void:
	_opacity = alpha

func _exit_tree() -> void:
	EnvironmentGlow.release(self)

func _process(delta: float) -> void:
	_time += delta
	EnvironmentGlow.request(self, _opacity if is_visible_in_tree() else 0.0)
	var state := _state_at(fmod(_time, _cycle()))
	if state != _state:
		_state = state
		mark.set_marks(state[0])
		mark.set_red(state[1])

func _cycle() -> float:
	return dark_duration + 3 * step_duration + blinks * (blink_on + blink_off)

## [parties jaunes, rouge] a l'instant `t` du cycle.
func _state_at(t: float) -> Array:
	t -= dark_duration
	if t < 0.0:
		return [0, false]
	if t < 3 * step_duration:
		return [floori(t / step_duration) + 1, false]
	t = fmod(t - 3 * step_duration, blink_on + blink_off)
	return [0, t < blink_on]
