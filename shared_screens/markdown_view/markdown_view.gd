class_name MarkdownView
extends ScrollContainer

## Texte enrichi a partir d'une syntaxe "markdown-like" simple, avec
## defilement vertical (glisser au tactile ou a la souris, molette) quand le
## contenu depasse la hauteur disponible. Utilise par la vue d'aide des
## options (GameOptions) et par le panneau des regles (RulesPanel) : tout
## texte d'aide ou de regles passe par ce composant pour garder la meme
## presentation.
##
## Syntaxe retenue (sous-ensemble de Markdown, pas de support complet) :
##
##   # Titre               titre de niveau 1 (le plus grand, dore)
##   ## Sous-titre         titre de niveau 2
##   ### Section           titre de niveau 3
##   **gras**              gras (aussi __gras__)
##   *italique*            italique (aussi _italique_)
##   ***gras italique***   gras et italique
##   - element             liste a puces (aussi "* " ou "+ ")
##   1. element            liste numerotee (aussi "1) ") ; la numerotation
##                         ecrite est reprise telle quelle
##   (2 espaces ou 1 tabulation devant "-" ou "1.") element de sous-liste,
##                         jusqu'a 3 niveaux
##   ligne vide            separe deux paragraphes (espacement lisible)
##   retour a la ligne     simple retour a la ligne dans le paragraphe
##   \* \_ \# \\           caractere litteral (pas de mise en forme)
##
## Un texte sans aucune de ces marques s'affiche tel quel (retours a la
## ligne compris) : les textes d'aide existants restent valides. Les
## crochets sont affiches tels quels (le BBCode n'est pas interprete).
##
## Exemple :
##
##   # Cricket
##   Close the **7 targets** before your opponents.
##
##   ## Marks
##   - Single = 1 mark, double = 2, triple = 3.
##   - 3 marks close a target.
##     - Extra marks *score* while others still have it open.
##
##   ## Turn
##   1. Throw 3 darts.
##   2. Remove your darts.

@export_multiline var markdown := "":
	set(value):
		markdown = value
		_render()

@export_group("Style")
@export var font_size := 36:
	set(value):
		font_size = value
		_render()
## Tailles des titres de niveau 1, 2 et 3.
@export var heading_sizes := PackedInt32Array([54, 46, 40]):
	set(value):
		heading_sizes = value
		_render()
@export var text_color := Color(1, 1, 1, 1):
	set(value):
		text_color = value
		_render()
@export var heading_color := Color(1, 0.78, 0.25, 1):
	set(value):
		heading_color = value
		_render()
## Espace entre deux paragraphes, et avant un titre, en pixels.
@export var paragraph_spacing := 20:
	set(value):
		paragraph_spacing = value
		_render()
## Decalage d'un niveau de liste, en pixels.
@export var list_indent := 28:
	set(value):
		list_indent = value
		_render()
## Marge autour du texte, dans la zone de defilement.
@export var content_margin := 24:
	set(value):
		content_margin = value
		_render()

const BULLETS := ["•", "◦", "–"]

var _margin: MarginContainer
var _label: RichTextLabel

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_margin)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Laisse le glisser remonter jusqu'au ScrollContainer (defilement tactile).
	_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_label.selection_enabled = false
	_margin.add_child(_label)

func _ready() -> void:
	_render()

## Remplace le contenu et revient en haut.
func set_markdown(text: String) -> void:
	markdown = text
	scroll_vertical = 0

func _render() -> void:
	if _label == null:
		return
	for side in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, content_margin)
	_label.add_theme_color_override("default_color", text_color)
	for font in ["normal", "bold", "italics", "bold_italics"]:
		_label.add_theme_font_size_override(font + "_font_size", font_size)
	_label.text = to_bbcode(markdown)

## Convertit le texte markdown-like en BBCode pour RichTextLabel.
func to_bbcode(text: String) -> String:
	var out := PackedStringArray()
	var gap_pending := false
	var after_heading := false
	var heading_re := RegEx.create_from_string("^(#{1,3})\\s+(.*)$")
	var bullet_re := RegEx.create_from_string("^([ \\t]*)[-*+]\\s+(.*)$")
	var number_re := RegEx.create_from_string("^([ \\t]*)(\\d+)[.)]\\s+(.*)$")

	for raw_line in text.replace("\r", "").split("\n"):
		var line := raw_line.rstrip(" \t")
		if line.strip_edges().is_empty():
			# Pas d'espace de plus apres un titre : il a deja le sien.
			gap_pending = not out.is_empty() and not after_heading
			continue
		after_heading = false

		var m := heading_re.search(line)
		if m:
			if not out.is_empty():
				out.append(_gap(paragraph_spacing * 3 / 2))
			var level := m.get_string(1).length()
			var size := heading_sizes[mini(level, heading_sizes.size()) - 1] if not heading_sizes.is_empty() else font_size
			out.append("[font_size=%d][color=#%s][b]%s[/b][/color][/font_size]\n" % [
				size, heading_color.to_html(false), _inline(m.get_string(2))])
			out.append(_gap(paragraph_spacing / 2))
			gap_pending = false
			after_heading = true
			continue

		if gap_pending:
			out.append(_gap(paragraph_spacing))
			gap_pending = false

		var marker := ""
		var indent := ""
		var body := ""
		m = bullet_re.search(line)
		if m:
			indent = m.get_string(1)
			body = m.get_string(2)
		else:
			m = number_re.search(line)
			if m:
				indent = m.get_string(1)
				marker = m.get_string(2) + "."
				body = m.get_string(3)
		if m:
			var level := mini(_indent_level(indent), BULLETS.size() - 1)
			if marker == "":
				marker = BULLETS[level]
			out.append(_list_item(level, marker, _inline(body)) + "\n")
		else:
			out.append(_inline(line) + "\n")

	return "".join(out).trim_suffix("\n")

## Ligne vide d'environ `height` pixels (son retour a la ligne est dans la
## balise, sinon la ligne prendrait la hauteur de la police normale).
func _gap(height: int) -> String:
	return "[font_size=%d] \n[/font_size]" % maxi(height, 1)

## Element de liste : une table a deux colonnes (marqueur, texte) pour que
## les lignes coupees restent alignees sous le texte, pas sous la puce.
func _list_item(level: int, marker: String, body: String) -> String:
	return "[table=2][cell padding=%d,0,12,0]%s[/cell][cell expand=1]%s[/cell][/table]" % [
		list_indent * level + 4, marker, body]

## Niveau de liste d'une indentation : 2 espaces ou 1 tabulation par niveau.
func _indent_level(indent: String) -> int:
	return indent.replace("\t", "  ").length() / 2

const _ESCAPES := {"\\\\": "", "\\*": "", "\\_": "", "\\#": ""}
const _LITERALS := {"": "\\", "": "*", "": "_", "": "#"}

## Mise en forme d'une ligne : echappements, gras, italique.
func _inline(text: String) -> String:
	for key in _ESCAPES:
		text = text.replace(key, _ESCAPES[key])
	text = text.replace("[", "[lb]")
	text = _sub(text, "\\*\\*\\*(?![\\s*])(.*?\\S)\\*\\*\\*", "[b][i]$1[/i][/b]")
	text = _sub(text, "\\*\\*(?![\\s*])(.*?\\S)\\*\\*", "[b]$1[/b]")
	text = _sub(text, "(?<!\\w)__(?![\\s_])(.*?\\S)__(?!\\w)", "[b]$1[/b]")
	text = _sub(text, "(?<![*\\w])\\*(?![\\s*])(.*?\\S)\\*(?![*\\w])", "[i]$1[/i]")
	text = _sub(text, "(?<!\\w)_(?![\\s_])(.*?\\S)_(?!\\w)", "[i]$1[/i]")
	for key in _LITERALS:
		text = text.replace(key, _LITERALS[key])
	return text

func _sub(text: String, pattern: String, replacement: String) -> String:
	return RegEx.create_from_string(pattern).sub(text, replacement, true)
