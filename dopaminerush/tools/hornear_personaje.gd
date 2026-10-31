extends SceneTree

# Godot --headless --path . --script res://tools/hornear_personaje.gd
#
# Convierte el modelo del personaje (Male.fbx) en la malla que usa el
# jugador para hacer sombra: assets/modelos/personaje/personaje.res
#
# El fbx viene como sale de Blender: chiquito (0,66 m), con la Z para
# arriba, mirando para +Z y en T-pose. Esto lo:
#   - para (Y arriba) y lo gira para que mire a -Z, como la camara
#   - escala a la altura del jugador, con los pies en el piso
#   - le baja los brazos: en T-pose la sombra es una cruz
#
# El fbx original queda sin tocar (Mixamo, para animarlo, lo pide en T-pose).
# Volver a correrlo si se cambia el modelo o alguna de estas constantes.

const ORIGEN := "res://assets/modelos/personaje/Male.fbx"
const DESTINO := "res://assets/modelos/personaje/personaje.res"

# La camara del jugador esta a 2,25 del origen y el piso a 0,1 (el fondo de
# la capsula de colision): los ojos quedan a ~2,15 del piso. Los ojos de una
# persona estan al 93 % de su altura.
const ALTURA := 2.3
const ALTURA_PISO := 0.1

# Los brazos: donde esta el hombro (en fraccion de la altura, medido sobre el
# modelo; el borde de ARRIBA del brazo, asi el hombro no se levanta al
# girar) y cuanto bajan. 72 grados los deja casi pegados al cuerpo pero
# separados, como se ve una persona parada en una sombra.
const HOMBRO_X := 0.11
const HOMBRO_ALTO := 0.78
const BAJADA_BRAZOS := 72.0
# El hombro no gira de golpe: entre estas distancias del centro el giro se
# reparte, asi la axila no se rompe.
const FUNDIDO_DESDE := 0.10
const FUNDIDO_HASTA := 0.16


func _initialize() -> void:
	var escena: Node = load(ORIGEN).instantiate()
	var original: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays: Array = original.mesh.surface_get_arrays(0)
	escena.free()

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var caja := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		caja = caja.expand(v)
	var alto_original := caja.size.z
	var escala := ALTURA / alto_original
	var centro := caja.get_center()

	var nuevos := PackedVector3Array()
	var nuevas_normales := PackedVector3Array()
	for i in vertices.size():
		# En fracciones de la altura, con los pies en 0 y el cuerpo centrado
		var p := (vertices[i] - Vector3(centro.x, centro.y, caja.position.z)) / alto_original
		var n := normales[i]
		var giro := _giro_brazo(p)
		if giro != 0.0:
			var lado := signf(p.x)
			var pivote := Vector2(HOMBRO_X * lado, HOMBRO_ALTO)
			var d := Vector2(p.x, p.z) - pivote
			var a := -giro * lado
			d = d.rotated(a)
			p.x = pivote.x + d.x
			p.z = pivote.y + d.y
			var nn := Vector2(n.x, n.z).rotated(a)
			n.x = nn.x
			n.z = nn.y
		# Blender (Z arriba, mira a -Y) -> Godot (Y arriba, mira a -Z), y girado
		# 180 para que mire para el mismo lado que la camara.
		nuevos.append(Vector3(-p.x, p.z, p.y) * ALTURA + Vector3(0, ALTURA_PISO, 0))
		nuevas_normales.append(Vector3(-n.x, n.z, n.y).normalized())

	var salida := []
	salida.resize(Mesh.ARRAY_MAX)
	salida[Mesh.ARRAY_VERTEX] = nuevos
	salida[Mesh.ARRAY_NORMAL] = nuevas_normales
	salida[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	if arrays[Mesh.ARRAY_TEX_UV]:
		salida[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV]
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, salida)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.58)
	malla.surface_set_material(0, material)

	var error := ResourceSaver.save(malla, DESTINO)
	print("personaje: %d vertices, %.2f m (escala x%.0f) -> %s (%s)"
		% [nuevos.size(), malla.get_aabb().size.y, escala, DESTINO, error_string(error)])
	quit(error)


# Cuanto gira este vertice: todo el brazo baja BAJADA_BRAZOS; el hombro, una
# parte; el torso, nada.
func _giro_brazo(p: Vector3) -> float:
	if p.z < HOMBRO_ALTO - 0.17 or p.z > HOMBRO_ALTO + 0.02:
		return 0.0
	var peso := smoothstep(FUNDIDO_DESDE, FUNDIDO_HASTA, absf(p.x))
	return deg_to_rad(BAJADA_BRAZOS) * peso
