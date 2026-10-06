class_name HalveItScorePanel
extends PanelContainer

## Panneau de score du Halve It : la cible du round en cours en titre, puis
## une grille a 3 colonnes (nom du joueur, score, texte d'aide, ex. "+9 this
## turn") avec une ligne par joueur. Le joueur en cours est en surbrillance.
## set_players() construit les lignes, set_row() met a jour score et texte
## d'un joueur, set_current_player() deplace la surbrillance, set_target()
## met a jour la cible affichee.

const TARGET_FONT_SIZE := 56
const SCORE_COLUMN_WIDTH := 240.0
## Tailles selon le nombre de joueurs (le premier seuil atteint), pour
## afficher jusqu'a 8 joueurs sans defilement : polices du nom, du score et
## du texte d'aide, et marge verticale des cellules.
const ROW_SIZES := [
	{"players": 8, "name": 38, "score": 44, "hint": 26, "pad": 8},
	{"players": 6, "name": 46, "score": 52, "hint": 30, "pad": 12},
	{"players": 0, "name": 56, "score": 64, "hint": 36, "pad": 20},
]
const CELL_PADDING_X := 24.0
const HIGHLIGHT_COLOR := Color(0.95, 0.75, 0.2, 0.38)
const NORMAL_COLOR := Color(1, 1, 1, 0.05)

@onready var target_label: Label = $Margin/Content/TargetLabel
@onready var grid: GridContainer = $Margin/Content/Scroll/Grid

var _sizes: Dictionary = ROW_SIZES[-1]
var _row_styles: Array[Array] = []
var _score_labels: Array[Label] = []
var _hint_labels: Array[Label] = []

func set_target(target_text: String) -> void:
	target_label.text = "Target: %s" % target_text

func set_players(names: Array[String]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_row_styles.clear()
	_score_labels.clear()
	_hint_labels.clear()
	for sizes in ROW_SIZES:
		if names.size() >= sizes.players:
			_sizes = sizes
			break

	for player_name in names:
		var styles: Array[StyleBoxFlat] = []
		_add_cell(player_name, _sizes.name, HORIZONTAL_ALIGNMENT_LEFT, 3.0, 0.0, styles)
		_score_labels.append(_add_cell("", _sizes.score, HORIZONTAL_ALIGNMENT_CENTER, 0.0, SCORE_COLUMN_WIDTH, styles))
		var hint_label := _add_cell("", _sizes.hint, HORIZONTAL_ALIGNMENT_LEFT, 4.0, 0.0, styles)
		hint_label.modulate.a = 0.85
		_hint_labels.append(hint_label)
		_row_styles.append(styles)

func set_row(index: int, score: int, hint: String) -> void:
	_score_labels[index].text = str(score)
	_hint_labels[index].text = hint

func set_current_player(index: int) -> void:
	for i in _row_styles.size():
		var color := HIGHLIGHT_COLOR if i == index else NORMAL_COLOR
		for style: StyleBoxFlat in _row_styles[i]:
			style.bg_color = color

## Ajoute une cellule (fond + label) a la grille et retourne son label.
## stretch > 0 : la colonne s'etire avec ce ratio ; min_width fixe sinon.
func _add_cell(text: String, font_size: int, align: HorizontalAlignment, stretch: float, min_width: float, styles: Array[StyleBoxFlat]) -> Label:
	var style := StyleBoxFlat.new()
	style.bg_color = NORMAL_COLOR
	style.content_margin_left = CELL_PADDING_X
	style.content_margin_right = CELL_PADDING_X
	style.content_margin_top = float(_sizes.pad)
	style.content_margin_bottom = float(_sizes.pad)
	styles.append(style)

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
