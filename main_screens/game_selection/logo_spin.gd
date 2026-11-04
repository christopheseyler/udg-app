class_name LogoSpin
extends LogoMover

## Fait tourner le noeud sur son axe Z (vers la camera dans le repere du
## logo), a vitesse constante, comme les aiguilles et les roues de Around the
## Clock (voir LogoMover). Deux roues qui engrenent tournent en sens contraires,
## a des vitesses dans le rapport inverse de leurs nombres de dents.

## Vitesse de rotation, en degres par seconde : positive dans le sens
## anti-horaire vu de face, negative dans le sens horaire.
@export var degrees_per_second: float = 10.0

func _moved(rest: Transform3D, time: float) -> Transform3D:
	return Transform3D(rest.basis * Basis(Vector3.BACK, deg_to_rad(degrees_per_second * time)), rest.origin)
