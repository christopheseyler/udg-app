class_name DoBetterScorePanel
extends PanelContainer

## Panneau de score de Do Better If You Can : en titre la cible du round et le
## score a battre (master actuel et ses marques), sous lui le resultat du
## dernier tour, puis une grille a 3 colonnes (nom du joueur, points, etat du
## joueur dans le round) avec une ligne par joueur. Le joueur en cours est en
## surbrillance.

const POINTS_COLUMN_WIDTH := 200.0
## Tailles selon le nombre de joueurs (le premier seuil atteint), pour
## afficher jusqu'a 8 joueurs sans defilement : polices du nom, des points et
## de l'etat, et marge verticale des cellules.
const ROW_SIZES := [
	{"players": 8, "name": 38, "score": 44, "hint": 26, "pad": 6},
	{"players": 6, "name": 46, "score": 52, "hint": 30, "pad": 10},
	{"players": 0, "name": 56, "score": 64, "hint": 36, "pad": 18},
]
const CELL_PADDING_X := 24.0
const MASTER_COLOR := Color(1, 0.78, 0.25)

@onready var target_label: Label = $Margin/Content/TargetLabel
@onready var to_beat_label: Label = $Margin/Content/ToBeatLabel
@onready var result_label: Label = $Margin/Content/ResultLabel
@onready var grid: GridContainer = $Margin/Content/Scroll/Grid

var _sizes: Dictionary = ROW_SIZES[-1]
var _row_plates: ScoreRowPlates
var _name_labels: Array[Label] = []
var _score_labels: Array[Label] = []
var _hint_labels: Array[Label] = []

func set_header(target_text: String, to_beat_text: String, result_text: String) -> void:
	target_label.text = "Target: %s" % target_text
	to_beat_label.text = to_beat_text
	result_label.text = result_text

func set_players(names: Array[String]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if _row_plates == null:
		_row_plates = ScoreRowPlates.new(grid)
	_name_labels.clear()
	_score_labels.clear()
	_hint_labels.clear()
	for sizes in ROW_SIZES:
		if names.size() >= sizes.players:
			_sizes = sizes
			break

	for player_name in names:
		_name_labels.append(_add_cell(player_name, _sizes.name, HORIZONTAL_ALIGNMENT_LEFT, 3.0, 0.0))
		_score_labels.append(_add_cell("", _sizes.score, HORIZONTAL_ALIGNMENT_CENTER, 0.0, POINTS_COLUMN_WIDTH))
		var hint_label := _add_cell("", _sizes.hint, HORIZONTAL_ALIGNMENT_LEFT, 4.0, 0.0)
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)

## Points et etat d'un joueur ; `is_master` met son nom en dore.
func set_row(index: int, points: int, hint: String, is_master: bool) -> void:
	_score_labels[index].text = str(points)
	_hint_labels[index].text = hint
	_name_labels[index].add_theme_color_override("font_color", MASTER_COLOR if is_master else Color.WHITE)

func set_current_player(index: int) -> void:
	_row_plates.set_current(index)

## Ajoute une cellule (label, sans fond : voir ScoreRowPlates) a la grille et
## retourne son label. stretch > 0 : la colonne s'etire avec ce ratio ;
## min_width fixe sinon.
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
