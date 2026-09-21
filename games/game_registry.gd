class_name GameRegistry
extends RefCounted

## Liste ordonnee des jeux proposes dans le carrousel. Pour ajouter un jeu :
## creer games/<nom_du_jeu>/<nom>_game.gd (extends GameDefinition) et
## l'ajouter ici.

const GAME_SCRIPTS: Array[GDScript] = [
	preload("res://games/x01/x01_game.gd"),
	preload("res://games/321_zap/zap_321_game.gd"),
	preload("res://games/halve_it/halve_it_game.gd"),
	preload("res://games/shanghai/shanghai_game.gd"),
	preload("res://games/cricket/cricket_game.gd"),
	preload("res://games/around_the_clock/around_the_clock_game.gd"),
]

static func create_all() -> Array[GameDefinition]:
	var games: Array[GameDefinition] = []
	for script in GAME_SCRIPTS:
		games.append(script.new())
	return games
