extends GameDefinition

## Bob's 27 (voir l'issue #3). Regles dans Bobs27Rules.

## Regles affichees par le panneau Rules (syntaxe : voir MarkdownView).
const RULES := """
# Bob's 27
Go around the numbers **1 to 20** in the chosen zone without letting your score drop below zero.

## Round
1. Everyone starts with **27 points**.
2. The first round aims at the **1** in the chosen zone (the double by default), then 2, 3... up to **20**.
3. Every player still in the game throws **3 darts** at the round's target, even after hitting it with the first one.

## Scoring
Let **V** be the value of the target (the double 5 is worth 10, the triple 5 is worth 15, a single 5 is worth 5):
- every dart in the target scores **+V**;
- if **none** of the 3 darts hits it, lose **V once**, at the end of the volley.

Only the exact zone counts: with *Single Outer*, a dart in the inner single (between the bull and the triple) is a miss, and the other way round.

## Elimination
- A score **below zero** eliminates the player; zero is allowed.
- As soon as only **one player** is left, they win right away.
- Otherwise, after the 20, the **highest score** wins. Players with the same score share the place.

## Solo
The game ends when your score drops below zero, or after the 20. Try to beat your best final score, or to go further.

## Teams (option)
Players are split into teams in playing order (1st player in team 1, 2nd in team 2...). Each team shares one score of 27 points and its members take turns: one member throws at the 1, the next at the 2, and so on. A score below zero eliminates the whole team.
"""

func _init() -> void:
	id = "bobs_27"
	name = "Bob's 27"
	rules = RULES
	# Pas d'apostrophe dans la police 3D HemiHead.
	logo_text = "Bobs 27"
	screen_scene = preload("res://games/bobs_27/bobs_27_screen.tscn")
	max_players = 8
	options = [
		{
			"id": "target", "type": "enum", "name": "Target",
			"items": Bobs27Rules.TARGETS, "default": "Double",
			"info": "Zone to hit on each number, the same for everyone during the whole game.\n- **Double**: the outer ring, worth 2 x the number.\n- **Triple**: the treble ring, worth 3 x the number.\n- **Single Outer**: the single between the triple and the double, worth the number.\n- **Single Inner**: the single between the bull and the triple, worth the number.\n\nOnly the chosen zone counts: the other single, another ring or another number is a miss.",
		},
		{
			"id": "teams", "type": "enum", "name": "Teams",
			"items": ["Off", "2 Teams", "3 Teams", "4 Teams"], "default": "Off",
			"info": "**Off**: everyone plays for themselves.\n\nOtherwise, players are split into teams in playing order (1st player in team 1, 2nd in team 2...). Each team shares one score of 27 points, its members take turns (one member per number), and a score below zero eliminates the whole team.",
		},
	]
