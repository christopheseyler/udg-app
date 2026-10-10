class_name UiKit
extends RefCounted

## Elements du kit UI (assets/ui/setup, rendus par tools/blender/ui_kit.py)
## construits par code : images affichees a leur taille visuelle et
## medaillons numerotes des joueurs.

## Marge transparente rendue autour de chaque element du kit (ombre, halo).
const PAD := 24
const MEDALLION_SIZE := 80
## Medaillons des joueurs, dans l'ordre des couleurs du kit (rouge, vert,
## bleu, orange, violet, cyan, rose, blanc).
const MEDALLIONS: Array[Texture2D] = [
	preload("res://assets/ui/setup/medallion_1.png"),
	preload("res://assets/ui/setup/medallion_2.png"),
	preload("res://assets/ui/setup/medallion_3.png"),
	preload("res://assets/ui/setup/medallion_4.png"),
	preload("res://assets/ui/setup/medallion_5.png"),
	preload("res://assets/ui/setup/medallion_6.png"),
	preload("res://assets/ui/setup/medallion_7.png"),
	preload("res://assets/ui/setup/medallion_8.png"),
]

## Image du kit affichee a sa taille visuelle : la texture deborde de PAD de
## chaque cote (ombre) sans compter dans la mise en page.
static func image(texture: Texture2D, visual_size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(visual_size, visual_size)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = -Vector2(PAD, PAD)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	return holder

## Medaillon a la couleur du joueur `player_index` (0 = premier joueur),
## portant le numero `number`.
static func medallion(player_index: int, number: int) -> Control:
	var holder := image(MEDALLIONS[player_index % MEDALLIONS.size()], MEDALLION_SIZE)
	var label := Label.new()
	label.text = str(number)
	label.add_theme_font_size_override("font_size", 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(label)
	return holder
