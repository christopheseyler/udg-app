class_name DoBetterLogoTiming
extends RefCounted

## Horloge commune de l'animation du logo de Beat the King
## (do_better_logo.tscn) : trois flechettes visent tour a tour la couronne,
## qui s'ecarte juste avant chaque impact ; la flechette se plante la ou etait
## la couronne. Une fois les trois plantees, elles s'effacent en fondu et la
## couronne revient a sa place, puis l'animation recommence. La couronne
## (DoBetterLogoCrown) et chaque flechette (DoBetterLogoDart) calculent leur
## etat a partir du meme temps : GameLogo3D les detache et les rattache
## ensemble au logo, leurs temps repartent donc ensemble (voir LogoMover).

## Duree d'un cycle complet, en secondes.
const PERIOD := 6.0
## Lancer de la premiere flechette, puis ecart entre deux lancers.
const FIRST_THROW := 0.5
const THROW_INTERVAL := 1.1
## Duree du vol d'une flechette.
const FLIGHT := 0.45
## Debut de l'ecart de la couronne apres le lancer, et sa duree : elle a fini
## de s'ecarter avant l'arrivee de la flechette.
const DODGE_DELAY := 0.15
const DODGE := 0.25
## Fondu des flechettes plantees, et retour de la couronne.
const FADE_START := 4.1
const FADE := 0.6
const RETURN_START := 4.3
const RETURN := 0.8
## Positions successives de la couronne, depuis sa position de repos (en
## metres, dans le repere du logo) : les flechettes se plantent dans les trois
## premieres, la couronne finit sur la quatrieme avant de revenir.
const SPOTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(-0.085, 0.012, 0.0),
	Vector3(0.085, -0.004, 0.0),
	Vector3(0.0, 0.04, 0.0),
]

## Temps dans le cycle.
static func cycle_time(time: float) -> float:
	return fposmod(time, PERIOD)

## Decalage de la couronne depuis sa position de repos a l'instant `t` du
## cycle.
static func crown_offset(t: float) -> Vector3:
	var offset := SPOTS[0]
	for i in 3:
		var k := _ease_out(t, FIRST_THROW + i * THROW_INTERVAL + DODGE_DELAY, DODGE)
		if k > 0.0:
			offset = SPOTS[i].lerp(SPOTS[i + 1], k)
	var back := _smooth(t, RETURN_START, RETURN)
	if back > 0.0:
		offset = SPOTS[3].lerp(SPOTS[0], back)
	return offset

## Avancement (0 a 1) du vol de la flechette `index`, negatif avant son lancer.
static func flight_progress(t: float, index: int) -> float:
	var launch := FIRST_THROW + index * THROW_INTERVAL
	if t < launch:
		return -1.0
	return minf((t - launch) / FLIGHT, 1.0)

## Transparence des flechettes (0 opaques, 1 effacees).
static func dart_fade(t: float) -> float:
	return clampf((t - FADE_START) / FADE, 0.0, 1.0)

static func _ease_out(t: float, start: float, duration: float) -> float:
	var x := clampf((t - start) / duration, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func _smooth(t: float, start: float, duration: float) -> float:
	return smoothstep(0.0, 1.0, (t - start) / duration)
