extends SceneTree

# Godot --headless --path . --script res://tools/hornear_personaje.gd
#
# Arma el cuerpo del jugador a partir del modelo (Male.fbx), que viene sin
# esqueleto: le genera uno, le reparte los pesos de cada vertice entre los
# huesos y guarda la escena lista para animar:
#   assets/modelos/personaje/personaje.res   la malla, con sus pesos
#   escenas/01_habitacion/cuerpo.tscn        Cuerpo > Esqueleto > Malla
# Las animaciones no estan aca: son procedurales, en cuerpo.gd.
#
# El fbx viene como sale de Blender: chiquito (0,66 m), con la Z para
# arriba, mirando para +Z y en T-pose. Esto lo para (Y arriba), lo gira
# para que mire a -Z, como la camara, y lo lleva a la altura del jugador.
# La T-pose se deja tal cual: es la pose de descanso del esqueleto, y bajar
# los brazos es trabajo de la animacion.
#
# Volver a correrlo si se cambia el modelo o alguna de estas medidas.

const ORIGEN := "res://assets/modelos/personaje/Male.fbx"
const MALLA := "res://assets/modelos/personaje/personaje.res"
const ESCENA := "res://escenas/01_habitacion/cuerpo.tscn"
const SCRIPT := "res://escenas/01_habitacion/cuerpo.gd"

# Una persona de 1,80. La camara del jugador queda donde estaba (a 2,25 del
# origen), un poco mas arriba que estos ojos: no importa, el cuerpo no se ve
# y la sombra no deja comparar. El piso esta a 0,1 del origen (el fondo de
# la capsula de colision).
const ALTURA := 1.8
const ALTURA_PISO := 0.1

# El modelo es flaco: en la sombra los brazos se pierden contra el cuerpo.
# Se lo "arma" un poco: brazos mas gruesos, algo mas de hombros y piernas.
const ENGROSAR_BRAZOS := 1.45
const ENGROSAR_PIERNAS := 1.12
const ENSANCHAR_HOMBROS := 0.10

# Las articulaciones, medidas sobre el modelo en fracciones de la altura:
# x al costado (+ es la derecha del personaje), y para arriba desde los
# pies, z para atras. Los huesos del lado izquierdo son los mismos con la
# x al reves.
const HUESOS := [
	# nombre, padre, posicion
	["Cadera", "", Vector3(0, 0.52, 0)],
	["Columna", "Cadera", Vector3(0, 0.60, 0)],
	["Pecho", "Columna", Vector3(0, 0.70, 0)],
	["Cuello", "Pecho", Vector3(0, 0.84, 0)],
	["Cabeza", "Cuello", Vector3(0, 0.88, 0)],
	["Brazo.D", "Pecho", Vector3(0.115, 0.775, 0.02)],
	["Antebrazo.D", "Brazo.D", Vector3(0.25, 0.72, 0.02)],
	["Mano.D", "Antebrazo.D", Vector3(0.34, 0.70, 0.0)],
	["Muslo.D", "Cadera", Vector3(0.055, 0.50, 0.0)],
	["Pierna.D", "Muslo.D", Vector3(0.07, 0.28, 0.015)],
	["Pie.D", "Pierna.D", Vector3(0.07, 0.05, 0.035)],
]


func _initialize() -> void:
	var escena: Node = load(ORIGEN).instantiate()
	var original: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays: Array = original.mesh.surface_get_arrays(0)
	escena.free()

	# ---- el esqueleto ----
	var huesos := _huesos_con_lados()
	var esqueleto := Skeleton3D.new()
	esqueleto.name = "Esqueleto"
	var global_de := {}
	for h in huesos:
		var i := esqueleto.add_bone(h[0])
		var pos: Vector3 = _a_metros(h[2])
		global_de[h[0]] = pos
		var local := pos
		if h[1] != "":
			esqueleto.set_bone_parent(i, esqueleto.find_bone(h[1]))
			local = pos - global_de[h[1]]
		esqueleto.set_bone_rest(i, Transform3D(Basis(), local))
	esqueleto.reset_bone_poses()

	# ---- la malla, con sus pesos ----
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var caja := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		caja = caja.expand(v)
	var alto := caja.size.z
	var centro := caja.get_center()

	var nuevos := PackedVector3Array()
	var nuevas_normales := PackedVector3Array()
	var ids := PackedInt32Array()
	var pesos := PackedFloat32Array()
	for i in vertices.size():
		# Blender (Z arriba, mira a -Y) -> Godot (Y arriba, mira a -Z), girado
		# 180 para que mire para el mismo lado que la camara.
		var r := (vertices[i] - Vector3(centro.x, centro.y, caja.position.z)) / alto
		var p := Vector3(-r.x, r.z, r.y)
		var n := normales[i]
		nuevos.append(_a_metros(_armar(p)))
		nuevas_normales.append(Vector3(-n.x, n.z, n.y).normalized())
		var reparto := _pesos(p)
		var nombres := reparto.keys()
		nombres.sort_custom(func(a, b): return reparto[a] > reparto[b])
		var total := 0.0
		for k in mini(4, nombres.size()):
			total += reparto[nombres[k]]
		for k in 4:
			if k < nombres.size():
				ids.append(esqueleto.find_bone(nombres[k]))
				pesos.append(reparto[nombres[k]] / total)
			else:
				ids.append(0)
				pesos.append(0.0)

	var salida := []
	salida.resize(Mesh.ARRAY_MAX)
	salida[Mesh.ARRAY_VERTEX] = nuevos
	salida[Mesh.ARRAY_NORMAL] = nuevas_normales
	salida[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	salida[Mesh.ARRAY_BONES] = ids
	salida[Mesh.ARRAY_WEIGHTS] = pesos
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, salida)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.58)
	malla.surface_set_material(0, material)
	var error := ResourceSaver.save(malla, MALLA)
	if error != OK:
		push_error("no se pudo guardar la malla: " + error_string(error))
		quit(1)
		return
	malla = load(MALLA)

	# La piel: para cada hueso, como llevar un vertice de la malla (en la
	# pose de descanso) al espacio de ese hueso.
	var piel := Skin.new()
	for i in esqueleto.get_bone_count():
		piel.add_named_bind(esqueleto.get_bone_name(i), esqueleto.get_bone_global_rest(i).affine_inverse())

	# ---- la escena ----
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.set_script(load(SCRIPT))
	cuerpo.add_child(esqueleto)
	esqueleto.owner = cuerpo
	var instancia := MeshInstance3D.new()
	instancia.name = "Malla"
	instancia.mesh = malla
	instancia.skin = piel
	# Solo hace sombra: la camara esta adentro de la cabeza y nunca lo ve.
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	esqueleto.add_child(instancia)
	instancia.owner = cuerpo
	instancia.skeleton = NodePath("..")

	var empaquetada := PackedScene.new()
	empaquetada.pack(cuerpo)
	error = ResourceSaver.save(empaquetada, ESCENA)
	print("cuerpo: %d vertices, %d huesos, %.2f m -> %s (%s)"
		% [nuevos.size(), esqueleto.get_bone_count(), malla.get_aabb().size.y, ESCENA, error_string(error)])
	cuerpo.free()
	quit(error)


# Engrosa cada parte alrededor de su eje (el hueso), sin moverla de lugar.
# Los pesos se calculan sobre la forma original: esto no los cambia.
func _armar(p: Vector3) -> Vector3:
	var lado := signf(p.x) if p.x != 0.0 else 1.0
	var ax := absf(p.x)
	# Los brazos: alrededor de la linea hombro-muneca (en T-pose)
	if p.y > 0.62 and ax > 0.09:
		var nuevo := _engrosar(p, Vector3(0.115 * lado, 0.775, 0.02), Vector3(0.36 * lado, 0.695, 0.0),
			ENGROSAR_BRAZOS)
		var peso := smoothstep(0.09, 0.15, ax) * (1.0 - 0.6 * smoothstep(0.33, 0.37, ax))
		# Solo lo que es brazo: el costado del torso queda como esta
		var es_brazo := maxf(smoothstep(0.66, 0.71, p.y) * (1.0 - smoothstep(0.83, 0.86, p.y)),
			smoothstep(0.105, 0.13, ax))
		p = p.lerp(nuevo, peso * es_brazo)
	# Las piernas: alrededor de la linea cadera-tobillo
	if p.y < 0.5 and ax > 0.005:
		var nuevo := _engrosar(p, Vector3(0.055 * lado, 0.50, 0.0), Vector3(0.07 * lado, 0.05, 0.035),
			ENGROSAR_PIERNAS)
		var peso := (1.0 - smoothstep(0.42, 0.49, p.y)) * smoothstep(0.03, 0.08, p.y)
		p = p.lerp(nuevo, peso)
	# Los hombros y el pecho, un poco mas anchos
	if ax < 0.13:
		var bulto := smoothstep(0.62, 0.74, p.y) * (1.0 - smoothstep(0.80, 0.85, p.y))
		p.x *= 1.0 + ENSANCHAR_HOMBROS * bulto
	return p


func _engrosar(p: Vector3, a: Vector3, b: Vector3, factor: float) -> Vector3:
	var eje := b - a
	var t := clampf((p - a).dot(eje) / eje.length_squared(), 0.0, 1.0)
	var centro := a + eje * t
	return centro + (p - centro) * factor


# Los huesos con ".D" se duplican para el lado izquierdo (".I", x al reves).
func _huesos_con_lados() -> Array:
	var lista := []
	for h in HUESOS:
		lista.append(h)
	for h in HUESOS:
		if h[0].ends_with(".D"):
			var p: Vector3 = h[2]
			lista.append([h[0].replace(".D", ".I"), h[1].replace(".D", ".I"), Vector3(-p.x, p.y, p.z)])
	return lista


func _a_metros(p: Vector3) -> Vector3:
	return p * ALTURA + Vector3(0, ALTURA_PISO, 0)


# Cuanto le toca a cada hueso de este vertice (p en fracciones de la
# altura). En las articulaciones el peso se reparte entre los dos huesos:
# asi el codo o la rodilla se doblan sin romperse.
func _pesos(p: Vector3) -> Dictionary:
	var lado := ".D" if p.x >= 0.0 else ".I"
	var ax := absf(p.x)
	var reparto := {}

	# El tronco y la cabeza, por altura
	var tronco := {}
	_tramo(tronco, p.y, [
		["Cadera", 0.0], ["Cadera", 0.55], ["Columna", 0.60], ["Columna", 0.65],
		["Pecho", 0.70], ["Pecho", 0.81], ["Cuello", 0.85], ["Cuello", 0.86],
		["Cabeza", 0.885],
	])

	# Las piernas: de la cadera para abajo, por altura
	var pierna := {}
	_tramo(pierna, p.y, [
		["Pie" + lado, 0.035], ["Pierna" + lado, 0.07], ["Pierna" + lado, 0.25],
		["Muslo" + lado, 0.31], ["Muslo" + lado, 0.46],
	])
	# En la entrepierna, el muslo le pasa el peso a la cadera
	var en_pierna := 1.0 - smoothstep(0.46, 0.53, p.y)
	# Justo en el medio (la costura entre las piernas) es de la cadera
	en_pierna *= smoothstep(0.0, 0.025, ax) if p.y > 0.42 else 1.0

	# Los brazos: del hombro para afuera, por distancia al centro
	var brazo := {}
	_tramo(brazo, ax, [
		["Pecho", 0.09], ["Brazo" + lado, 0.14], ["Brazo" + lado, 0.22],
		["Antebrazo" + lado, 0.28], ["Antebrazo" + lado, 0.32], ["Mano" + lado, 0.36],
	])
	# Solo a la altura de los brazos: el costado del torso no se mueve con ellos.
	# Pero lo que esta mas afuera que el torso (0,105) es brazo a cualquier
	# altura: las manos cuelgan mas abajo que el hombro.
	var en_brazo := smoothstep(0.66, 0.71, p.y) * (1.0 - smoothstep(0.83, 0.86, p.y))
	if p.y > 0.6:
		en_brazo = maxf(en_brazo, smoothstep(0.105, 0.13, ax))

	_sumar(reparto, tronco, (1.0 - en_pierna) * (1.0 - en_brazo))
	_sumar(reparto, pierna, en_pierna)
	_sumar(reparto, brazo, (1.0 - en_pierna) * en_brazo)
	for k in reparto.keys():
		if reparto[k] < 0.01:
			reparto.erase(k)
	return reparto


# Reparte el peso a lo largo de una cadena de puntos [hueso, posicion]:
# entre dos puntos de huesos distintos, se mezcla suave.
func _tramo(destino: Dictionary, t: float, puntos: Array) -> void:
	if t <= puntos[0][1]:
		destino[puntos[0][0]] = 1.0
		return
	for i in range(1, puntos.size()):
		if t <= puntos[i][1]:
			var a = puntos[i - 1]
			var b = puntos[i]
			var f := smoothstep(a[1], b[1], t)
			destino[a[0]] = destino.get(a[0], 0.0) + 1.0 - f
			destino[b[0]] = destino.get(b[0], 0.0) + f
			return
	destino[puntos[-1][0]] = 1.0


func _sumar(destino: Dictionary, origen: Dictionary, factor: float) -> void:
	if factor <= 0.0:
		return
	for k in origen:
		destino[k] = destino.get(k, 0.0) + origen[k] * factor
