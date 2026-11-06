class_name GameCarousel3D
extends Node3D

## Carrousel 3D de l'ecran de selection de jeu : un logo 3D par jeu
## (GameLogo3D), disposes sur un cylindre vertical vu de l'exterieur, le
## logo courant en face de la camera. Les autres logos tournent avec le
## cylindre et s'estompent progressivement selon leur angle. Le defilement
## et l'animation de selection sont pilotes par l'ecran de selection, qui
## appelle update_layout() a chaque changement.

const LOGO_SCENE := preload("res://main_screens/game_selection/game_logo_3d.tscn")

@export var ring_radius: float = 1.3
@export var angle_step_degrees: float = 30.0
@export var min_alpha: float = 0.0
@export var alpha_falloff_power: float = 4.0
## Opacite ramenee a 0 : l'opacite des logos est recalee pour s'annuler ici
## plutot qu'a +-90 deg, et les logos plus estompes ne sont plus dessines (voir
## GameLogo3D.set_opacity()). Les deux logos a +-60 deg, a 6 % d'opacite et
## presque invisibles, faisaient rater des images au carrousel sur la carte
## quand le glow tourne (3-2-1 Zap ou Cricket au centre).
@export var fade_cutoff: float = 0.1

@export_group("Selection")
@export var selected_zoom: float = 1.15
## Glissement lateral des autres logos quand un jeu est choisi, en metres.
@export var others_slide_distance: float = 0.65

@onready var camera: Camera3D = $Camera3D
@onready var logos_root: Node3D = $Logos

var _logos: Array[GameLogo3D] = []

func set_games(games: Array[GameDefinition]) -> void:
	for game in games:
		var logo: GameLogo3D = LOGO_SCENE.instantiate()
		logos_root.add_child(logo)
		logo.set_text(game.logo_text if game.logo_text else game.name, game.logo_decoration, game.logo_text_offset)
		_logos.append(logo)

## Deplacement a l'ecran, en pixels du SubViewport, du logo central quand le
## carrousel avance d'un jeu (a la tangente du cylindre) : le glissement du
## doigt qui fait passer d'un jeu au suivant, pour que le logo suive le doigt.
func pixels_per_game() -> float:
	var step := Vector3(ring_radius * deg_to_rad(angle_step_degrees), 0.0, 0.0)
	return camera.unproject_position(step).x - camera.unproject_position(Vector3.ZERO).x

## Place, tourne et estompe chaque logo selon son angle sur le cylindre pour
## le defilement `scroll_offset` (en nombre de jeux). Le delta angulaire
## passe par wrapf pour un defilement infini : un logo peut se rapprocher du
## centre par la gauche ou par la droite selon le chemin le plus court sur le
## cylindre. Chaque logo reste tangent au cylindre : de face au centre, de
## profil a +-90 deg.
## `selection_amount` (0 = carrousel, 1 = jeu choisi) amene le logo
## `selected_index` au centre de l'ecran en le grossissant legerement, et
## fait glisser les autres vers l'exterieur en les effacant.
func update_layout(scroll_offset: float, selection_amount: float, selected_index: int) -> void:
	var angle_step := deg_to_rad(angle_step_degrees)
	var screen_center := Vector3(camera.position.x, camera.position.y, 0.0)
	var n := _logos.size()

	for i in n:
		var logo := _logos[i]
		var delta := wrapf(i - scroll_offset, -n / 2.0, n / 2.0)
		var angle := clampf(delta * angle_step, -PI / 2.0, PI / 2.0)
		var depth := cos(angle)

		var pos := Vector3(sin(angle) * ring_radius, 0.0, (depth - 1.0) * ring_radius)
		var zoom := 1.0
		var alpha := lerpf(min_alpha, 1.0, pow(depth, alpha_falloff_power))
		alpha = clampf((alpha - fade_cutoff) / (1.0 - fade_cutoff), 0.0, 1.0)

		if selection_amount > 0.0:
			if i == selected_index:
				pos = pos.lerp(screen_center, selection_amount)
				zoom = lerpf(1.0, selected_zoom, selection_amount)
			else:
				var side := signf(wrapf(i - selected_index, -n / 2.0, n / 2.0))
				pos.x += side * others_slide_distance * selection_amount
				alpha *= 1.0 - selection_amount

		logo.position = pos
		logo.rotation.y = angle
		logo.scale = Vector3.ONE * zoom
		logo.set_opacity(alpha)
