class_name DoBetterLogoCrown
extends LogoMover

## Couronne du logo de Beat the King : s'ecarte de la flechette qui la
## vise, puis revient a sa place (voir DoBetterLogoTiming). Penche un peu du
## cote ou elle part, comme si elle esquivait.

## Inclinaison maximale pendant un ecart, en degres par metre et par seconde
## de vitesse laterale.
@export var lean_per_speed: float = 18.0

func _moved(rest: Transform3D, time: float) -> Transform3D:
	var t := DoBetterLogoTiming.cycle_time(time)
	var offset := DoBetterLogoTiming.crown_offset(t)
	var speed := (DoBetterLogoTiming.crown_offset(t + 0.02).x - offset.x) / 0.02
	var lean := Basis(Vector3.BACK, deg_to_rad(clampf(-speed * lean_per_speed, -20.0, 20.0)))
	return Transform3D(lean * rest.basis, rest.origin + offset)
