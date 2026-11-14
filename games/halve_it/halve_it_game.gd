extends GameDefinition

## Regles affichees par le panneau Rules (syntaxe : voir MarkdownView).
const RULES := """
# Halve It
Score as much as you can on each round's target, or see your score **cut in half**.

## Targets
Each round has its own target:
- **9 Rounds**: 15, 16, 17, *any double*, 18, 19, 20, *any triple*, bull.
- **Extended**: 12, 13, 14, *any double*, 15, 16, 17, *any triple*, 18, 19, 20, bull.

## Turn
1. Throw your **3 darts** at the round's target.
2. Every dart on the target adds its value (number x multiplier) to your score.
3. If **none** of your 3 darts hit the target, your score is **halved** (rounded down).

## End of game
After the last round, the player with the **highest score** wins.
"""

func _init() -> void:
	id = "halve_it"
	name = "Halve It"
	rules = RULES
	image = "res://assets/game_selector/game_selector_halve_it.png"
	logo_decoration = preload("res://games/halve_it/halve_it_logo_cleaver.tscn")
	screen_scene = preload("res://games/halve_it/halve_it_screen.tscn")
	max_players = 8
	uses_players_order = false
	options = [
		{
			"id": "game_mode", "type": "enum", "name": "Game Mode",
			"items": ["9 Rounds", "Extended"], "default": "9 Rounds",
			"info": "9 Rounds (15 to Bullseye): 15, 16, 17, Any Double, 18, 19, 20, Any Triple, Bullseye. Extended (12 to Bullseye): 12, 13, 14, Any Double, 15, 16, 17, Any Triple, 18, 19, 20, Bullseye.",
		},
		{
			"id": "starting_score", "type": "enum", "name": "Starting Score",
			"items": ["0", "40", "80"], "default": "0",
			"info": "Score every player begins the game with.",
		},
	]
