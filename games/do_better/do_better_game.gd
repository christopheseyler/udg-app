extends GameDefinition

## Do Better If You Can : titre provisoire, le nom definitif reste a choisir
## (voir l'issue #1). Regles dans DoBetterRules.

## Regles affichees par le panneau Rules (syntaxe : voir MarkdownView).
const RULES := """
# Do Better If You Can
Beat the **master** of the round on the target they chose. The player with the most **points** at the end wins.

## Round
1. The **master** throws first: their **first dart sets the target** of the round.
2. Their 3 darts, the first one included, give the **marks to beat**.
3. Each other player then throws **3 darts** at the same target, in order:
   - more marks than the master: **+1 point for the player**;
   - fewer marks: **+1 point for the master**;
   - a tie: no point.

The master role moves to the next player every round: everyone is master the same number of times.

## Marks
- On a number: single = **1**, double = **2**, triple = **3**. A first dart in the triple 20 sets the target to 20 and already scores 3 marks.
- On the bull: outer bull = **1**, bull = **2**.
- If the master's first dart misses the board, the target is **Miss**: every missed dart scores 1 mark.
- Darts outside the target score nothing.

## Get the Lead (option)
- A player who beats the **current master** scores 1 point, **becomes the master**, and their marks become the marks to beat. The target never changes.
- If the first master lost the title, they get a **last turn** after everyone else:
  - better: they take the title back, score 1 point and **take back every point** the other players scored during this round;
  - worse: the current master scores 1 point;
  - a tie: no point.

## End of game
After the last round, the player with the most points wins. Players with the same points share the same place.
"""

func _init() -> void:
	id = "do_better"
	name = "Do Better If You Can"
	rules = RULES
	logo_text = "Do Better\n[if you can]"
	logo_decoration = preload("res://games/do_better/do_better_logo.tscn")
	screen_scene = preload("res://games/do_better/do_better_screen.tscn")
	min_players = 2
	max_players = 8
	options = [
		{
			"id": "rounds_per_player", "type": "enum", "name": "Rounds per Player",
			"items": ["1", "2", "3", "4"], "default": "2",
			"info": "Number of times each player is the master. The game has this many rounds **per player** (e.g. 2 with 4 players: 8 rounds), so that everyone is the first master the same number of times.",
		},
		{
			"id": "get_the_lead", "type": "bool", "name": "Get the Lead",
			"default": false,
			"info": "**Off**: the first master's marks stay the marks to beat for the whole round.\n\n**On**: a player who beats the current master scores 1 point and **becomes the master**; their marks become the marks to beat (the target doesn't change). If the first master lost the title, they get a last turn: if they do better, they take the title back, score 1 point and take back every point the other players scored during the round; if they do worse, the current master scores 1 point.",
		},
	]
