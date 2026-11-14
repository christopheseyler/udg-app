extends GameDefinition

## 121 : jeu d'entrainement a la finition (voir l'issue #5). Regles dans
## OneTwentyOneRules.

## Regles affichees par le panneau Rules (syntaxe : voir MarkdownView).
const RULES := """
# 121
A checkout practice game: finish each target at **exactly zero**, then aim for the next one, one point higher.

## Attempt
1. An attempt starts with the current target as remaining score (121 by default).
2. Every dart's value is subtracted from the remaining score. Darts are thrown in **volleys of 3**, players taking turns.
3. The target is completed when the score reaches **exactly zero** within the darts allowed for the target (9 by default), with the **Out** condition.
4. **Success**: the next target is **one point higher** (121, 122, 123...).
5. Every new attempt, after a success or a failure, gets all its darts back.

## Bust
A dart that takes the score below zero, to zero without the Out condition, or to 1 when the Out condition needs a double or a triple is a **bust**: the volley ends and the score goes back to what it was at its start. Its darts still count.

## Out conditions
- **Double Out**: a double or the bull (50).
- **Triple Out**: a triple.
- **Master Out**: a double, a triple or the bull (50).
- **Open Out**: any scoring dart.

The outer bull (25) only finishes with Open Out.

## Safe point
With **Safe Point** on, a target finished within the **first 3 darts** of its attempt becomes your safe point: you can never fall back below it. A slower success moves you on but sets no safe point.

## Failure
When the darts allowed run out:
- **Back to Start**: the next attempt starts again from the starting target, or from your safe point.
- **Step Back**: the next attempt is the current target minus 1, never below the starting target or your safe point.

## End of game
With **Max Rounds** on *Unlimited*, play as long as you like and leave with **Back**. Otherwise, after the last round, players are ranked by their **highest target completed**.
"""

func _init() -> void:
	id = "one_twenty_one"
	name = "121"
	rules = RULES
	screen_scene = preload("res://games/one_twenty_one/one_twenty_one_screen.tscn")
	max_players = 8
	options = [
		{
			"id": "start", "type": "enum", "name": "Starting Target",
			"items": ["29", "47", "71", "121"], "default": "121",
			"info": "Target of the first attempt. Each success adds **1** to the target.",
		},
		{
			"id": "darts_per_target", "type": "enum", "name": "Darts per Target",
			"items": ["3", "6", "9", "12", "15", "18", "21", "24", "27", "30"], "default": "9",
			"info": "Darts allowed to finish a target (a multiple of 3: darts are thrown in volleys of 3). Every new attempt gets them all back.",
		},
		{
			"id": "out_condition", "type": "enum", "name": "Out",
			"items": OneTwentyOneRules.OUT_CONDITIONS, "default": "Double Out",
			"info": "Dart allowed to reach exactly zero.\n- **Double Out**: a double or the bull (50).\n- **Triple Out**: a triple.\n- **Master Out**: a double, a triple or the bull (50).\n- **Open Out**: any scoring dart.\n\nThe outer bull (25) only finishes with Open Out.",
		},
		{"type": "group", "name": "Progression"},
		{
			"id": "safety", "type": "bool", "name": "Safe Point",
			"default": true,
			"info": "**On**: a target finished within the **first 3 darts** of its attempt becomes your safe point; after a failure you never fall back below it.\n\n**Off**: no safe point, the starting target is always the floor.",
		},
		{
			"id": "fail_rule", "type": "enum", "name": "On Failure",
			"items": ["Back to Start", "Step Back"], "default": "Back to Start",
			"info": "When the darts allowed run out without finishing the target.\n- **Back to Start**: the next attempt starts from the starting target, or from your safe point.\n- **Step Back**: the next attempt is the current target minus 1, never below the starting target or your safe point.",
		},
		{"type": "group", "name": "End of game"},
		{
			"id": "max_rounds", "type": "enum", "name": "Max Rounds",
			"items": ["Unlimited", "10", "15", "20", "30"], "default": "Unlimited",
			"info": "**Unlimited**: play as long as you like and leave with Back.\n\nOtherwise, the game ends after this many rounds (a round: one volley of 3 darts per player) and players are ranked by their highest target completed.",
		},
	]
