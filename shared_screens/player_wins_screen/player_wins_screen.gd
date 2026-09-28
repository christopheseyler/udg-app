class_name PlayerWinsScreen
extends Control

## Ecran partage affiche quand un joueur (ou plusieurs ex aequo) termine la
## partie a une place donnee : son nom accompagne de la coupe de son rang
## (#1, #2, #3), ou d'un simple texte "Rank #x" au-dela. show_rank()
## l'affiche ; continue_pressed est emis quand le joueur le ferme (voir
## GameScreen.announce_rank pour la suite : reprise de la partie ou ecran de
## classement).

signal continue_pressed

## Coupes des trois premieres places, dans l'ordre des rangs.
const CUP_TEXTURES: Array[Texture2D] = [
	preload("res://assets/game_screen/ranking/cup_1.png"),
	preload("res://assets/game_screen/ranking/cup_2.png"),
	preload("res://assets/game_screen/ranking/cup_3.png"),
]

@onready var winner_label: Label = $Center/Content/WinnerLabel
@onready var cup: TextureRect = $Center/Content/Cup
@onready var rank_label: Label = $Center/Content/RankLabel
@onready var continue_button: Button = $Center/Content/ContinueButton

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(func(): continue_pressed.emit())

## Affiche player_names (plusieurs noms = ex aequo) a la place rank (1 = le
## gagnant).
func show_rank(player_names: Array[String], rank: int) -> void:
	var names := " & ".join(player_names)
	winner_label.text = "%s wins!" % names if rank == 1 else names
	var has_cup := rank >= 1 and rank <= CUP_TEXTURES.size()
	cup.visible = has_cup
	rank_label.visible = not has_cup
	if has_cup:
		cup.texture = CUP_TEXTURES[rank - 1]
	else:
		rank_label.text = "Rank #%d" % rank
	visible = true

func hide_screen() -> void:
	visible = false
