@tool
class_name WifiSignalIcon
extends Control

## Icone de reseau WiFi dessinee : quatre barres montantes, les `bars`
## premieres pleines (0 a 4, champ "bars" de udg-wifi), et un petit cadenas a
## droite si le reseau demande un mot de passe. Pas de glyphe : la police du
## jeu n'a ni barres ni cadenas.

@export_range(0, 4) var bars: int = 4:
	set(value):
		bars = value
		queue_redraw()
@export var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()
@export var color: Color = Color(1, 1, 1):
	set(value):
		color = value
		queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(76, 40)

func _draw() -> void:
	var h := size.y
	var bar_w := 9.0
	var gap := 4.0
	var dim := Color(color, 0.25)
	for i in 4:
		var bar_h := h * (0.3 + 0.7 * (i + 1) / 4.0)
		var rect := Rect2(i * (bar_w + gap), h - bar_h, bar_w, bar_h)
		draw_rect(rect, color if i < bars else dim)
	if locked:
		# Cadenas : anse (arc) au-dessus d'un corps rectangulaire.
		var x := 4 * (bar_w + gap) + 6.0
		var body := Rect2(x, h * 0.5, 16.0, h * 0.5)
		draw_arc(Vector2(x + 8.0, h * 0.5), 5.5, PI, TAU, 12, color, 3.0)
		draw_rect(body, color)
