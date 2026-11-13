class_name CrownMesh
extends MeshInstance3D

## Couronne en or construite par code (pas de modele a importer) : une paroi
## cylindrique mince dont le bord haut forme des pointes, une perle au bout de
## chaque pointe, un bandeau en relief en bas, serti de pierres rouges et
## bleues sous les pointes. Origine au centre de la base, axe vers +Y.
## Construite a _ready(), avant que GameLogo3D ne fusionne les maillages du
## logo.

## Rayon de la paroi et hauteur sous les pointes / au bout des pointes.
@export var radius: float = 0.06
@export var band_height: float = 0.026
@export var peak_height: float = 0.07
@export var peaks: int = 8
@export var wall_thickness: float = 0.003
@export var pearl_radius: float = 0.0052
@export var gem_radius: float = 0.0058
## Segments autour de l'axe.
@export var segments: int = 128

const GOLD := Color(1.0, 0.74, 0.28)
const RUBY := Color(0.75, 0.03, 0.08)
const SAPPHIRE := Color(0.05, 0.18, 0.8)

func _ready() -> void:
	mesh = build()

func build() -> ArrayMesh:
	# Paroi et bandeau : sommets seuls, normales calculees (lissees aux
	# sommets partages). Les spheres (perles, pierres) ont deja les leurs :
	# elles vont dans des surfaces a part, au meme materiau pour les perles.
	var gold_material := _material(GOLD, 1.0, 0.28)
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_wall(shell)
	_add_band(shell)
	shell.index()
	shell.generate_normals()
	var result := shell.commit()
	result.surface_set_material(0, gold_material)

	var pearls := SurfaceTool.new()
	pearls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pearl := SphereMesh.new()
	pearl.radius = pearl_radius
	pearl.height = pearl_radius * 2.0
	for i in peaks:
		var angle := TAU * i / peaks
		pearls.append_from(pearl, 0, Transform3D(Basis(), _on_wall(angle, radius, peak_height + pearl_radius * 0.6)))
	result = pearls.commit(result)
	result.surface_set_material(1, gold_material)

	var colors := [RUBY, SAPPHIRE]
	for c in 2:
		var gems := SurfaceTool.new()
		gems.begin(Mesh.PRIMITIVE_TRIANGLES)
		var gem := SphereMesh.new()
		gem.radius = gem_radius
		gem.height = gem_radius * 1.6
		for i in range(c, peaks, 2):
			var angle := TAU * i / peaks
			var basis := Basis.looking_at(-_on_wall(angle, 1.0, 0.0), Vector3.UP)
			gems.append_from(gem, 0, Transform3D(basis.scaled(Vector3(1, 1, 0.6)), _on_wall(angle, radius + 0.004, band_height * 0.5)))
		result = gems.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, _material(colors[c], 0.2, 0.08))
	return result

## Point de la paroi a l'angle `angle`, au rayon `r` et a la hauteur `y`.
## L'angle 0 est vers l'avant (+Z, vers la camera), face a une pointe.
func _on_wall(angle: float, r: float, y: float) -> Vector3:
	return Vector3(sin(angle) * r, y, cos(angle) * r)

## Hauteur du bord haut a l'angle `angle` : des pointes etroites et des creux
## arrondis.
func _top(angle: float) -> float:
	var f := fposmod(angle * peaks / TAU + 0.5, 1.0)
	var peak := pow(1.0 - absf(f * 2.0 - 1.0), 2.2)
	return band_height + (peak_height - band_height) * peak

## Paroi : faces exterieure et interieure, bord haut en pointes, bord bas.
func _add_wall(st: SurfaceTool) -> void:
	var inner := radius - wall_thickness
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var t0 := _top(a0)
		var t1 := _top(a1)
		_quad(st, _on_wall(a0, radius, 0.0), _on_wall(a1, radius, 0.0), _on_wall(a1, radius, t1), _on_wall(a0, radius, t0))
		_quad(st, _on_wall(a1, inner, 0.0), _on_wall(a0, inner, 0.0), _on_wall(a0, inner, t0), _on_wall(a1, inner, t1))
		_quad(st, _on_wall(a0, radius, t0), _on_wall(a1, radius, t1), _on_wall(a1, inner, t1), _on_wall(a0, inner, t0))
		_quad(st, _on_wall(a1, radius, 0.0), _on_wall(a0, radius, 0.0), _on_wall(a0, inner, 0.0), _on_wall(a1, inner, 0.0))

## Bandeau en relief au bas de la paroi : un anneau bombe.
func _add_band(st: SurfaceTool) -> void:
	var rings := 8
	var bulge := 0.0045
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for r in rings:
			var v0 := float(r) / rings
			var v1 := float(r + 1) / rings
			var y0 := band_height * v0
			var y1 := band_height * v1
			var r0 := radius + bulge * sin(PI * v0)
			var r1 := radius + bulge * sin(PI * v1)
			_quad(st, _on_wall(a0, r0, y0), _on_wall(a1, r0, y0), _on_wall(a1, r1, y1), _on_wall(a0, r1, y1))

## Quadrilatere a, b, c, d dans le sens anti-horaire vu de sa face visible
## (ajoute en sens horaire : les faces avant de Godot).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
