class_name AroundTheClockScorePanel
extends PanelContainer

## Panneau de score de l'Around the Clock : le parcours du mode de jeu en
## titre, puis une grille a 3 colonnes (nom du joueur, cible courante, texte
## d'aide, ex. "5 / 20") avec une ligne par joueur. Le joueur en cours est en
## surbrillance. set_players() construit les lignes, set_row() met a jour la
## cible et le texte d'un joueur, set_current_player() deplace la
## surbrillance, set_title() met a jour le titre.

const TARGET_COLUMN_WIDTH := 240.0
## Tailles selon le nombre de joueurs (le premier seuil atteint), pour
## afficher jusqu'a 8 joueurs sans defilement : polices du nom, de la cible
## et du texte d'aide, et marge verticale des cellules.
const ROW_SIZES := [
	{"players": 8, "name": 38, "target": 44, "hint": 26, "pad": 8},
	{"players": 6, "name": 46, "target": 52, "hint": 30, "pad": 12},
	{"players": 0, "name": 56, "target": 64, "hint": 36, "pad": 20},
]
const CELL_PADDING_X := 24.0

@onready var title_label: Label = $Margin/Content/TitleLabel
@onready var grid: GridContainer = $Margin/Content/Scroll/Grid

var _sizes: Dictionary = ROW_SIZES[-1]
## Plaques des lignes (creees au premier set_players).
var _row_plates: ScoreRowPlates
var _target_labels: Array[Label] = []
var _hint_labels: Array[Label] = []

func set_title(text: String) -> void:
	title_label.text = text

func set_players(names: Array[String]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if _row_plates == null:
		_row_plates = ScoreRowPlates.new(grid)
	_target_labels.clear()
	_hint_labels.clear()
	for sizes in ROW_SIZES:
		if names.size() >= sizes.players:
			_sizes = sizes
			break

	for player_name in names:
		_add_cell(player_name, _sizes.name, HORIZONTAL_ALIGNMENT_LEFT, 3.0, 0.0)
		_target_labels.append(_add_cell("", _sizes.target, HORIZONTAL_ALIGNMENT_CENTER, 0.0, TARGET_COLUMN_WIDTH))
		var hint_label := _add_cell("", _sizes.hint, HORIZONTAL_ALIGNMENT_LEFT, 4.0, 0.0)
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)

func set_row(index: int, target_text: String, hint: String) -> void:
	_target_labels[index].text = target_text
	_hint_labels[index].text = hint

func set_current_player(index: int) -> void:
	_row_plates.set_current(index)

## Ajoute une cellule (label, sans fond : voir ScoreRowPlates) a la grille et retourne son label.
## stretch > 0 : la colonne s'etire avec ce ratio ; min_width fixe sinon.
func _add_cell(text: String, font_size: int, align: HorizontalAlignment, stretch: float, min_width: float) -> Label:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.content_margin_left = CELL_PADDING_X
	style.content_margin_right = CELL_PADDING_X
	style.content_margin_top = float(_sizes.pad)
	style.content_margin_bottom = float(_sizes.pad)

	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", style)
	cell.custom_minimum_size.x = min_width
	if stretch > 0.0:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = stretch
	grid.add_child(cell)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	cell.add_child(label)
	return label
