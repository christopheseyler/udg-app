class_name GameLogo3D
extends Node3D

## Logo 3D d'un jeu dans le carrousel de selection : la cible de l'ecran
## titre, de face, avec devant elle le nom du jeu en lettres HemiHead, un peu
## sous son centre (voir set_text()). Le nom a la meme taille pour tous les
## jeux tant qu'il tient dans `max_name_width` ; un nom de plusieurs mots qui
## devrait sinon descendre sous `min_one_line_scale` passe sur deux lignes, et
## un nom qui ne tient toujours pas est reduit.
## Une fois le nom pose, les maillages du logo sont fusionnes (voir
## _merge_meshes()) : le logo n'est plus qu'une poignee de maillages, toujours
## rendus opaques. Un masque, dessine par-dessus, l'estompe (voir
## set_opacity()).

## Calque de rendu des lettres, le seul eclaire par LettersLight : vu de face,
## le metal ne reflete sinon que le ciel sombre de l'environnement.
const LETTERS_LAYER := 2
const FADE_MASK_SHADER := preload("res://main_screens/game_selection/logo_fade_mask.gdshader")

## Agrandissement des lettres (1 = taille des caracteres generes).
@export var name_scale: float = 1.8
## Largeur maximale du nom, en metres.
@export var max_name_width: float = 0.6
## En dessous de cet agrandissement, un nom de plusieurs mots passe sur deux
## lignes plutot que d'etre reduit sur une seule.
@export var min_one_line_scale: float = 1.4
## Ecart entre deux lignes (du bas de l'une au haut de la suivante, plaques
## comprises), a l'echelle des caracteres.
@export var line_gap: float = 0.004
## Taille d'une ligne entre crochets (voir set_text()) par rapport aux autres.
@export var small_line_scale: float = 0.6

@onready var name_root: Node3D = $Name

## Maillages fusionnes deja construits, par contenu ([groupe, morceaux], voir
## _merge_meshes()) : la cible, identique dans tous les logos, n'est fusionnee
## qu'une fois (relire les maillages sur le GPU coute cher).
static var _merged_meshes: Dictionary = {}
## Maillages du masque d'estompage deja construits, par liste des maillages
## fusionnes qu'ils reunissent (voir _add_fade_masks()).
static var _mask_meshes: Dictionary = {}

## Materiau du masque d'estompage de ce logo, qui porte son opacite.
var _fade_mask := ShaderMaterial.new()
var _masks: Array[MeshInstance3D] = []
## Lueurs du decor, qui suivent l'opacite du logo (voir LogoGlow).
var _glows: Array[LogoGlow] = []

## Construit le texte du logo devant la cible : le nom du jeu, ou son
## GameDefinition.logo_text. Un "\n" force un retour a la ligne, et une ligne
## entre crochets ("Around\n[the]\nClock") est reduite a `small_line_scale`.
## Les lignes sont empilees selon leur hauteur, a `line_gap` l'une de
## l'autre, et le bloc est centre sur le noeud Name. `decoration`
## (GameDefinition.logo_decoration) est ajoute au logo avant la fusion de ses
## maillages. A appeler une fois, apres l'ajout du logo a l'arbre.
func set_text(text: String, decoration: PackedScene = null) -> void:
	if decoration:
		add_child(decoration.instantiate())
	var block: AABB
	var widest := 0.0
	var lines := _lines(text)
	for k in lines.size():
		var line := Node3D.new()
		line.scale = Vector3.ONE * lines[k][1]
		name_root.add_child(line)
		var bounds := line.transform * HemiHeadText.new(line, lines[k][0], LETTERS_LAYER).bounds
		if k > 0:
			line.position.y = block.position.y - line_gap - bounds.end.y
			bounds.position.y += line.position.y
		block = bounds if k == 0 else block.merge(bounds)
		widest = maxf(widest, bounds.size.x)

	for line: Node3D in name_root.get_children():
		line.position.y -= block.get_center().y
	name_root.scale = Vector3.ONE * minf(name_scale, max_name_width / widest)
	_merge_meshes()

## Opacite du logo entier (cible et nom) ; masque a 0. Estomper un logo en
## alpha surface par surface laisserait voir ses faces internes. Le logo reste
## donc rendu opaque, puis son masque (logo_fade_mask.gdshader) multiplie
## l'alpha de l'image par `alpha` sur sa seule surface visible : le
## SubViewportContainer le compose avec le fond d'un bloc. Opaque, le logo
## n'a pas besoin du masque, qui n'est pas dessine.
func set_opacity(alpha: float) -> void:
	visible = alpha > 0.005
	_fade_mask.set_shader_parameter("opacity", alpha)
	for mask in _masks:
		mask.visible = alpha < 0.995
	for glow in _glows:
		glow.opacity = alpha

## Lignes du texte, [texte, taille] : coupees aux retours a la ligne, ou a
## defaut par _split_lines() ; une ligne entre crochets est reduite.
func _lines(text: String) -> Array[Array]:
	var lines: Array[Array] = []
	var parts: Array = Array(text.split("\n", false)) if "\n" in text else _split_lines(text)
	for part: String in parts:
		part = part.strip_edges()
		if part.begins_with("[") and part.ends_with("]"):
			lines.append([part.substr(1, part.length() - 2), small_line_scale])
		else:
			lines.append([part, 1.0])
	return lines

## Le nom sur une ligne, ou sur deux s'il est trop large et a plusieurs mots :
## coupe a l'espace qui equilibre le mieux la largeur des deux lignes.
func _split_lines(game_name: String) -> Array[String]:
	var words := game_name.split(" ", false)
	if words.size() < 2 or max_name_width / HemiHeadText.width(game_name) >= min_one_line_scale:
		return [game_name]
	var best: Array[String] = []
	var best_width := INF
	for cut in range(1, words.size()):
		var first := " ".join(words.slice(0, cut))
		var second := " ".join(words.slice(cut))
		var width := maxf(HemiHeadText.width(first), HemiHeadText.width(second))
		if width < best_width:
			best_width = width
			best = [first, second]
	return best

## Remplace les maillages du logo par un maillage par materiau et calque de
## rendu. La cible compte une centaine de maillages et le nom un par lettre :
## avec trois logos a l'ecran et leurs ombres, le carrousel depassait 700 draw
## calls, et ne tenait plus 60 FPS sur la carte (le temps CPU du pilote GL
## faisait rater l'image au compositeur). Les decors mobiles (LogoMover, non
## imbriques) sont detaches avant, rattaches au logo a la meme place, puis
## fusionnes chacun a part dans son repere : ils continuent a bouger. Les
## noeuds d'origine sont liberes.
func _merge_meshes() -> void:
	var moving: Array[Node3D] = []
	for node in find_children("*", "Node3D", true, false):
		if node is LogoMover:
			moving.append(node)
	for part in moving:
		var parent_to_logo := _transform_in(part.get_parent(), self)
		part.get_parent().remove_child(part)
		part.transform = parent_to_logo * part.transform
	_merge_into(self)
	for part in moving:
		add_child(part)
		_merge_into(part)

## Remplace les maillages sous `root` par un maillage par materiau et calque de
## rendu, enfants de `root`, et y ajoute leurs masques d'estompage. Les autres
## instances visuelles (lumieres, comme la lueur de l'eclair de 3-2-1 Zap) sont
## gardees telles quelles, rattachees a `root` a la meme place, hors des
## masques.
func _merge_into(root: Node3D) -> void:
	var groups := {}
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var to_root := _transform_in(mesh, root)
		for i in mesh.mesh.get_surface_count():
			groups.get_or_add([mesh.get_active_material(i), mesh.layers], []).append([mesh.mesh, i, to_root])
	var kept: Array[Node3D] = []
	for node: VisualInstance3D in root.find_children("*", "VisualInstance3D", true, false):
		# (parents before children: a child of a kept node goes with it)
		if not node is MeshInstance3D and not kept.any(func(k: Node3D) -> bool: return k.is_ancestor_of(node)):
			var parent_to_root := _transform_in(node.get_parent(), root)
			node.get_parent().remove_child(node)
			node.transform = parent_to_root * node.transform
			kept.append(node)
	for node in kept:
		for glow in [node] + node.find_children("*", "Node3D", true, false):
			if glow is LogoGlow:
				_glows.append(glow)

	for child in root.get_children():
		child.free()
	for node in kept:
		root.add_child(node)
	var by_layers := {}
	for key in groups:
		var content := [key, groups[key]]
		if not _merged_meshes.has(content):
			_merged_meshes[content] = _merge(groups[key], key[0])
		var merged := MeshInstance3D.new()
		merged.mesh = _merged_meshes[content]
		merged.layers = key[1]
		root.add_child(merged)
		by_layers.get_or_add(key[1], []).append(merged.mesh)
	_add_fade_masks(root, by_layers.values())

## Ajoute sous `root` le masque d'estompage (voir set_opacity()) : ses
## maillages fusionnes, reunis en un seul par calque de rendu, pour que le
## masque ne coute qu'un draw call par calque. Le masque de la cible, identique
## dans tous les logos, n'est construit qu'une fois. Il ne projette pas
## d'ombre.
func _add_fade_masks(root: Node3D, meshes_by_layers: Array) -> void:
	_fade_mask.shader = FADE_MASK_SHADER
	for meshes: Array in meshes_by_layers:
		if not _mask_meshes.has(meshes):
			var parts := []
			for mesh: Mesh in meshes:
				parts.append([mesh, 0, Transform3D()])
			_mask_meshes[meshes] = _merge(parts, null)
		var mask := MeshInstance3D.new()
		mask.mesh = _mask_meshes[meshes]
		mask.material_override = _fade_mask
		mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mask.visible = false
		root.add_child(mask)
		_masks.append(mask)

## Fusionne des surfaces ([maillage, surface, transformation]) en un maillage
## d'une seule surface, de materiau `material`.
static func _merge(parts: Array, material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	for part in parts:
		tool.append_from(part[0], part[1], part[2])
	var merged := tool.commit()
	merged.surface_set_material(0, material)
	return merged

## Transformation d'un noeud dans le repere de son ancetre `root`, composee de
## parent en parent : exacte, donc identique d'un logo a l'autre quelle que
## soit leur position.
static func _transform_in(node: Node3D, root: Node3D) -> Transform3D:
	var transform_in_root := Transform3D()
	while node != root:
		transform_in_root = node.transform * transform_in_root
		node = node.get_parent()
	return transform_in_root
