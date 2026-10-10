class_name ScoreRowPlates
extends RefCounted

## Plaques du kit UI (assets/ui/setup/row_plate_*) dessinees derriere chaque
## ligne d'une grille de scores, la ligne du joueur en cours eclairee. Une
## ligne = `columns` cellules de la grille ; les `header_rows` premieres lignes
## (en-tetes) n'ont pas de plaque. Dessinees sur le signal draw de la grille,
## donc sous les cellules (qui n'ont plus de fond).

const NORMAL_TEXTURE := preload("res://assets/ui/setup/row_plate_normal.png")
const ACTIVE_TEXTURE := preload("res://assets/ui/setup/row_plate_active.png")

var _grid: GridContainer
var _header_rows := 0
var _current := -1
var _normal := _style(NORMAL_TEXTURE)
var _active := _style(ACTIVE_TEXTURE)

func _init(grid: GridContainer, header_rows: int = 0) -> void:
	_grid = grid
	_header_rows = header_rows
	grid.draw.connect(_draw)
	grid.sort_children.connect(grid.queue_redraw)

## Eclaire la ligne du joueur `index` (-1 : aucune).
func set_current(index: int) -> void:
	_current = index
	_grid.queue_redraw()

func _draw() -> void:
	var row := 0
	while true:
		var first_cell := (row + _header_rows) * _grid.columns
		if first_cell >= _grid.get_child_count():
			break
		var cell := _grid.get_child(first_cell) as Control
		var rect := Rect2(0.0, cell.position.y, _grid.size.x, cell.size.y)
		_grid.draw_style_box(_active if row == _current else _normal, rect)
		row += 1

## Plaque 256x90 (+ marge UiKit.PAD) etiree en 9-slice : coins et bords fixes.
static func _style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = UiKit.PAD + 30
	style.texture_margin_right = UiKit.PAD + 30
	style.texture_margin_top = UiKit.PAD + 22
	style.texture_margin_bottom = UiKit.PAD + 22
	style.expand_margin_left = UiKit.PAD
	style.expand_margin_right = UiKit.PAD
	style.expand_margin_top = UiKit.PAD
	style.expand_margin_bottom = UiKit.PAD
	return style
