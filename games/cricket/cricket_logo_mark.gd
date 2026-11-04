extends Node3D

## Marque du logo Cricket (cricket_logo_mark.tscn), entre la cible et le nom :
## eteinte un moment, puis la premiere barre s'allume en jaune, la seconde,
## l'anneau ; toute la marque passe au rouge dans un gros flash, puis s'eteint
## dans un autre, et on recommence. Ses maillages restent tels quels dans le
## logo (groupe GameLogo3D.UNMERGED_GROUP), pour que CricketMark3D en change
## les materiaux. Elle demande le glow de l'environnement tant que le logo se
## voit (voir EnvironmentGlow).

## Etapes du cycle : eteinte, 1 a 3 parties jaunes, rouge.
enum Step { DARK, ONE, TWO, THREE, RED }

## Duree de la marque eteinte, au debut de chaque cycle (le flash
## d'extinction compris).
@export var dark_duration: float = 1.2
## Duree de chaque etape de l'allumage (une barre, les deux, l'anneau).
@export var step_duration: float = 0.6
## Duree de la marque rouge, avant son extinction.
@export var red_duration: float = 1.2

@onready var mark: CricketMark3D = $Mark

var _opacity := 1.0
var _time := 0.0
## Etape affichee : la marque n'est modifiee qu'a son changement.
var _step := Step.DARK

## Opacite du logo (appelee par GameLogo3D.set_opacity()).
func set_logo_opacity(alpha: float) -> void:
	_opacity = alpha

func _exit_tree() -> void:
	EnvironmentGlow.release(self)

func _process(delta: float) -> void:
	_time += delta
	EnvironmentGlow.request(self, _opacity if is_visible_in_tree() else 0.0)
	var step := _step_at(fmod(_time, dark_duration + 3 * step_duration + red_duration))
	if step == _step:
		return
	_step = step
	match step:
		Step.DARK:
			mark.switch_off()
		Step.RED:
			mark.set_red(true, CricketMark3D.BIG_FLASH_GAIN, CricketMark3D.BIG_FLASH_DURATION)
		_:
			mark.set_marks(step)

## Etape a l'instant `t` du cycle.
func _step_at(t: float) -> Step:
	t -= dark_duration
	if t < 0.0:
		return Step.DARK
	if t < 3 * step_duration:
		return (floori(t / step_duration) + 1) as Step
	return Step.RED
