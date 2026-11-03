class_name GameLogo3D
extends Node3D

## Logo 3D d'un jeu dans le carrousel de selection : la cible de l'ecran
## titre, de face, avec devant elle le nom du jeu en lettres HemiHead, un peu
## sous son centre. Le nom a la meme taille pour tous les jeux tant qu'il
## tient dans `max_name_width` ; un nom de plusieurs mots qui devrait sinon
## descendre sous `min_one_line_scale` passe sur deux lignes, et un nom qui
## ne tient toujours pas est reduit.
## Une fois le nom pose, les maillages du logo sont fusionnes (voir
## _merge_meshes()) : le logo n'est plus qu'une poignee de maillages.

## Calque de rendu des lettres, le seul eclaire par LettersLight (voir
## TitleIntro3D.TITLE_LAYER).
const LETTERS_LAYER := 2
## Ecart de profondeur en dessous duquel deux surfaces du logo sont fusionnees
## dans le meme maillage, et dessinees avec la meme priorite une fois le logo
## estompe.
const DEPTH_TOLERANCE := 0.0002

## Agrandissement des lettres (1 = taille des caracteres generes).
@export var name_scale: float = 1.8
## Largeur maximale du nom, en metres.
@export var max_name_width: float = 0.6
## En dessous de cet agrandissement, un nom de plusieurs mots passe sur deux
## lignes plutot que d'etre reduit sur une seule.
@export var min_one_line_scale: float = 1.4
## Ecart entre les lignes de base de deux lignes, a l'echelle des caracteres.
@export var line_spacing: float = 0.075

@onready var name_root: Node3D = $Name

## Encombrement de chaque surface des maillages, par [maillage, surface].
static var _surface_bounds: Dictionary = {}
## Maillages fusionnes deja construits, par contenu ([groupe, morceaux], voir
## _merge_meshes()) : la cible, identique dans tous les logos, n'est fusionnee
## qu'une fois (relire les maillages sur le GPU coute cher).
static var _merged_meshes: Dictionary = {}

## Surfaces des maillages du logo : [maillage, surface, materiau estompe,
## materiau de surface d'origine].
var _surfaces: Array[Array] = []
## Copies en alpha des materiaux du logo (voir _prepare_fading()).
var _faded_materials: Array[BaseMaterial3D] = []
var _faded := false

## Construit le nom du jeu devant la cible. A appeler une fois, apres
## l'ajout du logo a l'arbre.
func set_game_name(game_name: String) -> void:
	var lines := _split_lines(game_name)
	var block: AABB
	var widest := 0.0
	for k in lines.size():
		var line := Node3D.new()
		line.position.y = -k * line_spacing
		name_root.add_child(line)
		var text := HemiHeadText.new(line, lines[k], LETTERS_LAYER)
		var placed := Transform3D(Basis(), line.position) * text.bounds
		block = placed if k == 0 else block.merge(placed)
		widest = maxf(widest, text.bounds.size.x)

	for line: Node3D in name_root.get_children():
		line.position.y -= block.get_center().y
	name_root.scale = Vector3.ONE * minf(name_scale, max_name_width / widest)
	_merge_meshes()
	_prepare_fading()

## Opacite du logo entier (cible et nom) ; masque a 0. Opaque, le logo
## reprend ses materiaux d'origine.
func set_opacity(alpha: float) -> void:
	visible = alpha > 0.005
	for material in _faded_materials:
		material.albedo_color.a = alpha
	var faded := alpha < 0.995
	if faded == _faded:
		return
	_faded = faded
	for surface in _surfaces:
		(surface[0] as MeshInstance3D).set_surface_override_material(surface[1], surface[2] if faded else surface[3])

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

## Remplace les maillages du logo par un maillage par materiau, calque de
## rendu et profondeur dans le logo (meme regroupement que les priorites de
## _prepare_fading()). La cible compte une centaine de maillages et le nom un
## par lettre : avec trois logos a l'ecran et leurs ombres, le carrousel
## depassait 700 draw calls, et ne tenait plus 60 FPS sur la carte (le temps
## CPU du pilote GL faisait rater l'image au compositeur). Les noeuds
## d'origine sont liberes.
func _merge_meshes() -> void:
	var groups := {}
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var to_logo := _transform_in_logo(mesh)
		for i in mesh.mesh.get_surface_count():
			var depth := snappedf((to_logo * _surface_aabb(mesh.mesh, i)).get_center().z, DEPTH_TOLERANCE)
			var key := [mesh.get_active_material(i), mesh.layers, depth]
			if not groups.has(key):
				groups[key] = []
			groups[key].append([mesh.mesh, i, to_logo])

	for child in get_children():
		child.free()
	for key in groups:
		var content := [key, groups[key]]
		if not _merged_meshes.has(content):
			var tool := SurfaceTool.new()
			for part in groups[key]:
				tool.append_from(part[0], part[1], part[2])
			var merged_mesh := tool.commit()
			merged_mesh.surface_set_material(0, key[0])
			_merged_meshes[content] = merged_mesh
		var merged := MeshInstance3D.new()
		merged.mesh = _merged_meshes[content]
		merged.layers = key[1]
		add_child(merged)

## Transformation d'un noeud dans le repere du logo, composee de parent en
## parent : exacte, donc identique d'un logo a l'autre quelle que soit leur
## position.
func _transform_in_logo(node: Node3D) -> Transform3D:
	var transform_in_logo := Transform3D()
	while node != self:
		transform_in_logo = node.transform * transform_in_logo
		node = node.get_parent()
	return transform_in_logo

## Prepare l'estompage du logo. La propriete transparency des
## GeometryInstance3D ne marche qu'en Forward+, pas avec les renderers Mobile
## et Compatibility : chaque surface recoit a la place une copie en alpha de
## son materiau, avec pre-passe de profondeur pour que seule la surface la
## plus proche reste visible (le logo s'estompe d'un bloc, sans laisser voir
## ses faces internes). Le renderer Compatibility de la carte ne fait pas
## cette pre-passe, et trie les surfaces transparentes par la distance du
## centre de leur boite : une fois le logo tourne, le cadre de la cible
## passerait devant une partie des secteurs. Les copies portent donc aussi
## une priorite de rendu qui suit la profondeur de la surface dans le logo,
## de l'arriere vers l'avant (une copie par materiau et par priorite).
func _prepare_fading() -> void:
	var entries := []
	var depths := {}
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var to_logo := _transform_in_logo(mesh)
		for i in mesh.mesh.get_surface_count():
			var depth := snappedf((to_logo * _surface_aabb(mesh.mesh, i)).get_center().z, DEPTH_TOLERANCE)
			entries.append([mesh, i, depth])
			depths[depth] = true
	var levels := depths.keys()
	levels.sort()

	var copies := {}
	for entry in entries:
		var mesh: MeshInstance3D = entry[0]
		var base: BaseMaterial3D = mesh.get_active_material(entry[1])
		var priority := mini(levels.find(entry[2]), Material.RENDER_PRIORITY_MAX)
		var key := [base, priority]
		if not copies.has(key):
			var copy: BaseMaterial3D = base.duplicate()
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			copy.render_priority = priority
			copies[key] = copy
		_surfaces.append([mesh, entry[1], copies[key], mesh.get_surface_override_material(entry[1])])
	_faded_materials.assign(copies.values())

## Encombrement d'une surface d'un maillage, dans le repere du maillage.
static func _surface_aabb(mesh: Mesh, surface: int) -> AABB:
	if mesh.get_surface_count() == 1:
		return mesh.get_aabb()
	var key := [mesh, surface]
	if not _surface_bounds.has(key):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var box := AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			box = box.expand(vertex)
		_surface_bounds[key] = box
	return _surface_bounds[key]
