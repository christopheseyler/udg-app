class_name HemiHeadText
extends RefCounted

## Ligne de texte en caracteres 3D HemiHead, posee sous un Node3D parent en
## ajoutant les chasses des caracteres, centree horizontalement sur l'origine
## du parent, la ligne de base en y = 0. Chaque lettre est un pivot place au
## centre de son caractere (axe des rotations quand on anime les lettres une
## a une), avec le maillage en enfant. Les plaques de deux lettres voisines
## peuvent se chevaucher : une lettre sur deux est avancee d'un
## demi-millimetre pour que leurs faces ne se battent pas a l'affichage. Une
## espace separe deux mots de `word_gap`.

## Caracteres HemiHead (Char_A, Char_a, Char_0, Char_-...) : origine sur la
## ligne de base, chasse en metres dans la metadonnee glTF extras.advance.
const FONT_SCENE := preload("res://assets/udg-3d-assets/hemihead/HemiHeadChamfer.glb")

## Maillage et chasse de chaque caractere ({"mesh", "advance"}), lus une
## seule fois dans FONT_SCENE.
static var _glyphs: Dictionary = {}

## Pivots des lettres, un tableau par mot, de gauche a droite.
var words: Array[Array] = []
## Encombrement de la ligne dans le repere du parent.
var bounds: AABB

func _init(parent: Node3D, text: String, layers: int = 1, word_gap: float = 0.03) -> void:
	var layout := _layout(text, word_gap)
	bounds = _bounds(layout)
	var centre := Vector3(bounds.get_center().x, 0.0, 0.0)
	bounds.position -= centre

	var index := 0
	for word in layout:
		var pivots: Array[Node3D] = []
		for placed in word:
			var glyph: Dictionary = placed[0]
			var aabb: AABB = glyph.mesh.get_aabb()
			var mesh := MeshInstance3D.new()
			mesh.mesh = glyph.mesh
			mesh.layers = layers
			mesh.position = -aabb.get_center()
			var pivot := Node3D.new()
			pivot.position = Vector3(placed[1], 0.0, (index % 2) * 0.0005) + aabb.get_center() - centre
			pivot.add_child(mesh)
			parent.add_child(pivot)
			pivots.append(pivot)
			index += 1
		words.append(pivots)

## Hauteur du centre des minuscules au-dessus de la ligne de base : le centre
## de la boite du "x" (sa plaque deborde autant en haut qu'en bas).
static func lowercase_centre() -> float:
	_load_glyphs()
	return _glyphs["x"].mesh.get_aabb().get_center().y

## Largeur de `text` une fois pose, sans creer de noeuds.
static func width(text: String, word_gap: float = 0.03) -> float:
	return _bounds(_layout(text, word_gap)).size.x

## Encombrement des caracteres `from` a `from + count - 1` de `text` une fois
## la ligne posee (centree comme dans _init()), sans creer de noeuds. Vide si
## aucun de ces caracteres n'a de modele 3D.
static func chars_bounds(text: String, from: int, count: int, word_gap: float = 0.03) -> AABB:
	var layout := _layout(text, word_gap)
	var picked: Array[Array] = [[]]
	for word in layout:
		for placed in word:
			if placed[2] >= from and placed[2] < from + count:
				picked[0].append(placed)
	if picked[0].is_empty():
		return AABB()
	var box := _bounds(picked)
	box.position.x -= _bounds(layout).get_center().x
	return box

## Caracteres de `text` avec leur abscisse sur la ligne et leur position dans
## `text` ([glyphe, x, index]), un tableau par mot. Les caracteres sans modele
## 3D sont ignores.
static func _layout(text: String, word_gap: float) -> Array[Array]:
	_load_glyphs()
	var layout: Array[Array] = []
	var x := 0.0
	var placed := []
	var in_word := false
	for i in text.length():
		var ch := text[i]
		if ch == " ":
			if in_word:
				layout.append(placed)
				placed = []
				in_word = false
				x += word_gap
			continue
		in_word = true
		if not _glyphs.has(ch):
			push_warning("HemiHeadText : pas de caractere 3D pour '%s'" % ch)
			continue
		placed.append([_glyphs[ch], x, i])
		x += _glyphs[ch].advance
	if in_word:
		layout.append(placed)
	return layout

static func _bounds(layout: Array[Array]) -> AABB:
	var extent := AABB()
	var first := true
	for word in layout:
		for placed in word:
			var box: AABB = Transform3D(Basis(), Vector3(placed[1], 0.0, 0.0)) * placed[0].mesh.get_aabb()
			extent = box if first else extent.merge(box)
			first = false
	return extent

static func _load_glyphs() -> void:
	if not _glyphs.is_empty():
		return
	var font := FONT_SCENE.instantiate()
	for glyph: MeshInstance3D in font.get_node("HemiHead").get_children():
		var ch := String(glyph.name).trim_prefix("Char_")
		_glyphs[ch] = {"mesh": glyph.mesh, "advance": glyph.get_meta("extras")["advance"]}
	font.free()
