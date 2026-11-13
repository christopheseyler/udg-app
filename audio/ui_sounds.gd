extends Node

## Sons de l'interface (autoload UiSounds).
##
## Boutons : chaque bouton (BaseButton) joue CLICK_SOUND quand il est
## actionne (signal pressed, donc pas pendant un defilement ni sur un bouton
## desactive), sans rien a ajouter dans les ecrans. Exceptions, posees par
## les ecrans : use_select_sound() pour les boutons qui lancent une etape
## (Select de l'ecran de selection, Start de la configuration de partie :
## SELECT_SOUND), exclude() pour ceux qui ne sont pas des boutons
## d'interface (simulateur de jets : ses boutons remplacent des fleches).
##
## play_window() joue WINDOW_SOUND, a l'apparition d'un ecran de la
## configuration de partie (panneaux Setup, Players, Options, vues du panneau
## Players, aide d'une option, ordre de passage).

const CLICK_SOUND := preload("res://assets/sounds/sfx/ui-button-soft.mp3")
const SELECT_SOUND := preload("res://assets/sounds/sfx/sfx-select1.mp3")
const WINDOW_SOUND := preload("res://assets/sounds/sfx/ui-window-move.mp3")
## Son choisi pour un bouton ou pour tous ceux d'un noeud (voir exclude et
## use_select_sound) : &"none" ou &"select".
const SOUND_META := &"ui_button_sound"
const HOOKED_META := &"ui_button_sound_hooked"

var _click_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer
var _window_player: AudioStreamPlayer

func _ready() -> void:
	# Appuis rapproches : chaque clic va au bout plutot que de couper le
	# precedent.
	_click_player = _add_player(CLICK_SOUND, 4)
	_select_player = _add_player(SELECT_SOUND, 1)
	_window_player = _add_player(WINDOW_SOUND, 1)
	get_tree().node_added.connect(_on_node_added)

func play_window() -> void:
	_window_player.play()

## Retire node du son des boutons : le bouton lui-meme, ou tous les boutons
## qu'il contient (ex. un panneau entier).
func exclude(node: Node) -> void:
	node.set_meta(SOUND_META, &"none")

## Le bouton joue SELECT_SOUND au lieu de CLICK_SOUND.
func use_select_sound(button: BaseButton) -> void:
	button.set_meta(SOUND_META, &"select")

func _add_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.max_polyphony = polyphony
	add_child(player)
	return player

func _on_node_added(node: Node) -> void:
	# node_added est aussi emis quand un noeud deja branche revient dans
	# l'arbre (ecran retire puis remis) : une seule connexion par bouton.
	var button := node as BaseButton
	if button and not button.has_meta(HOOKED_META):
		button.set_meta(HOOKED_META, true)
		button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_pressed(button: BaseButton) -> void:
	# Choix lu a l'appui : exclude() / use_select_sound() sont souvent
	# appeles dans le _ready() de l'ecran, apres l'entree du bouton dans
	# l'arbre. Le reglage le plus proche du bouton l'emporte.
	var node: Node = button
	while node:
		if node.has_meta(SOUND_META):
			if node.get_meta(SOUND_META) == &"select":
				_select_player.play()
			return
		node = node.get_parent()
	_click_player.play()
