@tool
extends Node3D

# ============================================================
#  Poblador
# ============================================================
#
# Planta vegetacion sola, evitando el camino y el lago.
#
# COMO SE USA:
#   1. Arrastrar los .glb del pack a la propiedad "Modelos" del Inspector
#      (arboles en uno, arbustos/pastos/piedras en el otro).
#   2. Tildar "Repoblar" y se replanta todo al instante.
#
# Es @tool, asi que se ve en el editor sin correr el juego. Todo lo que
# planta son hijos normales: si algo quedo feo, se mueve o se borra a mano.
#
# DOS COSAS QUE HACEN LA DIFERENCIA:
#   - Rotacion Y aleatoria y escala variable: sin eso, veinte copias del
#     mismo arbol gritan "copiar y pegar".
#   - Agrupamiento: la naturaleza viene en grupos con claros entre medio,
#     no repartida pareja.

@export_group("Modelos")
@export var arboles: Array[PackedScene] = []
@export var arbustos: Array[PackedScene] = []
## Matas de pasto, flores, hongos. Lo que mas cambia el resultado:
## en una escena linda no hay ni un centimetro de suelo pelado.
@export var pasto: Array[PackedScene] = []
## Piedras / losas. Cubren la SUPERFICIE del camino y se desparraman
## tambien un poco fuera del borde, para que el limite entre el sendero
## y el pasto no quede recto.
@export var piedras_camino: Array[PackedScene] = []

@export_group("Cantidad")
@export var cantidad_arboles: int = 120
@export var cantidad_arbustos: int = 220
@export var cantidad_pasto: int = 600
@export var cantidad_piedras: int = 420
## 0 = todas sobre el camino. 1 = todas fuera. En el medio, mezcla.
@export_range(0.0, 1.0) var proporcion_fuera: float = 0.25
## Cuanto se apartan del centro las que van sobre el camino
@export var ancho_camino: float = 1.7

@export_group("Area")
@export var radio: float = 50.0
@export var margen_camino: float = 4.5      # cuanto se aparta del camino
@export var margen_lago: float = 2.5

@export_group("Colisiones")
## Un cilindro por tronco. Es barato: lo caro seria generar colision
## desde la malla del arbol, con miles de triangulos por hoja, y ademas
## no aporta nada (al jugador solo le importa no atravesar el tronco).
@export var colision_arboles: bool = true
@export var radio_tronco: float = 0.45
@export var altura_tronco: float = 4.0
## Para rocas grandes. Dejalo apagado si en Arbustos hay plantas:
## chocarse con un helecho se siente mal.
@export var colision_arbustos: bool = false
@export var radio_arbusto: float = 0.6

@export_group("Variacion")
@export var escala_min: float = 0.8
@export var escala_max: float = 1.4
@export var semilla: int = 1234

@export_group("Acciones")
@export var repoblar: bool = false:
	set(valor):
		if valor:
			poblar()

## Convierte todo lo plantado en MultiMesh: miles de copias del mismo
## modelo pasan a dibujarse en UNA sola llamada en vez de una por planta.
## Visualmente es casi identico y el rendimiento mejora muchisimo.
## OJO: despues de fijar ya no se puede mover ni borrar una planta suelta.
## Para volver atras hay que apretar Repoblar (se pierde el fijado).
@export var fijar: bool = false:
	set(valor):
		if valor:
			fijar_poblacion()

# El camino, muestreado. Generado junto con la escena: si se cambia la
# curva del camino, hay que regenerar esta lista tambien.
const CAMINO := [Vector2(6.0, 42.0), Vector2(6.9, 40.9), Vector2(8.2, 39.5), Vector2(9.8, 37.8), Vector2(11.5, 35.9), Vector2(13.1, 33.9), Vector2(14.5, 31.9), Vector2(15.5, 29.9), Vector2(16.0, 28.0), Vector2(15.9, 26.1), Vector2(15.4, 24.2), Vector2(14.6, 22.3), Vector2(13.5, 20.3), Vector2(12.2, 18.4), Vector2(10.8, 16.5), Vector2(9.4, 14.7), Vector2(8.0, 13.0), Vector2(6.4, 11.5), Vector2(4.4, 10.0), Vector2(2.3, 8.7), Vector2(0.1, 7.4), Vector2(-2.0, 6.2), Vector2(-3.8, 4.9), Vector2(-5.2, 3.5), Vector2(-6.0, 2.0), Vector2(-6.0, 0.4), Vector2(-5.3, -1.3), Vector2(-4.2, -3.1), Vector2(-2.8, -4.9), Vector2(-1.3, -6.8), Vector2(-0.0, -8.6), Vector2(0.8, -10.3), Vector2(1.0, -12.0), Vector2(0.5, -13.7), Vector2(-0.5, -15.4), Vector2(-1.9, -17.2), Vector2(-3.6, -18.9), Vector2(-5.2, -20.5), Vector2(-6.8, -21.9), Vector2(-8.1, -23.1), Vector2(-9, -24)]

# El lago, como poligono. No es un circulo: hay que testear si el punto
# cae adentro, no solo la distancia al centro.
const LAGO := [Vector2(14.7, -4.1), Vector2(14.7, 1.9), Vector2(15.7, 6.2), Vector2(16.7, 9.5), Vector2(17.6, 12.6), Vector2(18.6, 14.3), Vector2(19.6, 15.7), Vector2(20.7, 14.2), Vector2(21.5, 12.0), Vector2(22.2, 9.1), Vector2(22.6, 5.6), Vector2(23.2, 2.9), Vector2(24.1, 0.2), Vector2(25.0, -4.1), Vector2(25.7, -10.2), Vector2(25.7, -17.1), Vector2(24.6, -21.6), Vector2(23.0, -22.4), Vector2(21.6, -20.8), Vector2(20.5, -18.5), Vector2(19.8, -17.1), Vector2(19.0, -17.8), Vector2(17.9, -18.7), Vector2(16.8, -17.3), Vector2(16.2, -13.4), Vector2(15.6, -9.2)]


const NODO_COLISIONES := "Colisiones"

var _cuerpo: StaticBody3D = null


func poblar() -> void:
	for hijo in get_children():
		hijo.queue_free()

	_cuerpo = null

	if arboles.is_empty() and arbustos.is_empty():
		push_warning("[Poblador] no hay modelos cargados en el Inspector")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = semilla

	_crear_cuerpo_colisiones()
	_plantar(arboles, cantidad_arboles, rng, 0.9, 1.5, true, margen_camino)
	_plantar(arbustos, cantidad_arbustos, rng, 0.7, 1.3, false, margen_camino * 0.6)
	# El pasto puede crecer casi pegado al camino: eso difumina el borde
	_plantar(pasto, cantidad_pasto, rng, 0.6, 1.4, false, 1.4)
	_piedras_en_el_borde(rng)


func _plantar(modelos: Array[PackedScene], cantidad: int, rng: RandomNumberGenerator,
		esc_min: float, esc_max: float, agrupar: bool, margen: float) -> void:
	if modelos.is_empty():
		return

	var puestos := 0
	var intentos := 0
	var centro_grupo := Vector2.ZERO
	var en_grupo := 0

	while puestos < cantidad and intentos < cantidad * 30:
		intentos += 1

		var punto: Vector2
		if agrupar and en_grupo > 0:
			# Cerca del ultimo grupo: los arboles vienen de a racimos
			punto = centro_grupo + Vector2(
				rng.randf_range(-7.0, 7.0),
				rng.randf_range(-7.0, 7.0)
			)
			en_grupo -= 1
		else:
			var ang := rng.randf_range(0.0, TAU)
			var dist := sqrt(rng.randf()) * radio
			punto = Vector2(cos(ang), sin(ang)) * dist
			if agrupar:
				centro_grupo = punto
				en_grupo = rng.randi_range(2, 6)

		if not _sirve(punto, margen):
			continue

		var escena: PackedScene = modelos[rng.randi() % modelos.size()]
		var inst := escena.instantiate()
		add_child(inst)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			inst.owner = get_tree().edited_scene_root

		inst.position = Vector3(punto.x, 0.44, punto.y)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		var e := rng.randf_range(esc_min, esc_max)
		inst.scale = Vector3(e, rng.randf_range(e * 0.9, e * 1.15), e)

		# Colision: un cilindro donde va el tronco
		if agrupar and colision_arboles:
			_agregar_colision(punto, radio_tronco * e, altura_tronco * e)
		elif not agrupar and colision_arbustos and esc_min >= 0.7:
			_agregar_colision(punto, radio_arbusto * e, 1.2 * e)

		puestos += 1


# Un solo StaticBody3D con muchas formas adentro: es mas eficiente que
# un cuerpo por arbol, y a Godot le da igual cuantas formas tenga.
func _crear_cuerpo_colisiones() -> void:
	if not (colision_arboles or colision_arbustos):
		return

	_cuerpo = StaticBody3D.new()
	_cuerpo.name = NODO_COLISIONES
	add_child(_cuerpo)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_cuerpo.owner = get_tree().edited_scene_root


func _agregar_colision(punto: Vector2, radio: float, altura: float) -> void:
	if _cuerpo == null:
		return

	var forma := CylinderShape3D.new()
	forma.radius = radio
	forma.height = altura

	var nodo := CollisionShape3D.new()
	nodo.shape = forma
	nodo.position = Vector3(punto.x, 0.44 + altura * 0.5, punto.y)
	_cuerpo.add_child(nodo)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		nodo.owner = get_tree().edited_scene_root


# Descarta los puntos que caen sobre el camino, el lago o el banco.
func _sirve(punto: Vector2, margen: float) -> bool:
	if _cerca_del_lago(punto):
		return false

	# Espacio libre alrededor del banco
	if punto.distance_to(Vector2(-9, -25)) < 7.0:
		return false

	for i in range(CAMINO.size() - 1):
		if _distancia_a_segmento(punto, CAMINO[i], CAMINO[i + 1]) < margen:
			return false

	return true


# Piedras a lo largo del camino. La mayoria van SOBRE el sendero,
# cubriendolo como un empedrado; el resto se desparrama apenas afuera
# para que el borde no quede recto.
func _piedras_en_el_borde(rng: RandomNumberGenerator) -> void:
	if piedras_camino.is_empty():
		return

	var largo_total := 0.0
	for i in range(CAMINO.size() - 1):
		largo_total += CAMINO[i].distance_to(CAMINO[i + 1])

	for n in range(cantidad_piedras):
		var recorrido := rng.randf() * largo_total
		var acumulado := 0.0
		var punto := Vector2.ZERO
		var normal := Vector2.RIGHT

		for i in range(CAMINO.size() - 1):
			var a: Vector2 = CAMINO[i]
			var b: Vector2 = CAMINO[i + 1]
			var largo := a.distance_to(b)
			if acumulado + largo >= recorrido:
				var t := (recorrido - acumulado) / largo
				punto = a.lerp(b, t)
				normal = (b - a).normalized().orthogonal()
				break
			acumulado += largo

		var lado: float = 1.0 if rng.randf() < 0.5 else -1.0
		var desvio: float
		if rng.randf() < proporcion_fuera:
			# afuera, pegada al borde
			desvio = rng.randf_range(ancho_camino, ancho_camino + 1.2)
		else:
			# sobre el camino
			desvio = rng.randf_range(0.0, ancho_camino)

		punto += normal * desvio * lado

		var escena: PackedScene = piedras_camino[rng.randi() % piedras_camino.size()]
		var inst := escena.instantiate()
		add_child(inst)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			inst.owner = get_tree().edited_scene_root

		# Apenas por encima de la tierra del sendero, para que no se hunda
		inst.position = Vector3(punto.x, 0.53, punto.y)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		# Un poco de inclinacion: ninguna piedra esta perfectamente plana
		inst.rotation.x = rng.randf_range(-0.06, 0.06)
		inst.rotation.z = rng.randf_range(-0.06, 0.06)
		var e := rng.randf_range(0.45, 1.0)
		inst.scale = Vector3(e, e * rng.randf_range(0.6, 0.9), e)


# Adentro del lago, o a menos de margen_lago de la orilla.
func _cerca_del_lago(punto: Vector2) -> bool:
	# Test de punto en poligono (cruces de un rayo horizontal)
	var dentro := false
	var j := LAGO.size() - 1
	for i in range(LAGO.size()):
		var a: Vector2 = LAGO[i]
		var b: Vector2 = LAGO[j]
		if (a.y > punto.y) != (b.y > punto.y):
			if punto.x < (b.x - a.x) * (punto.y - a.y) / (b.y - a.y) + a.x:
				dentro = not dentro
		j = i

	if dentro:
		return true

	# Fuera, pero puede estar pegado a la orilla
	for i in range(LAGO.size()):
		var a: Vector2 = LAGO[i]
		var b: Vector2 = LAGO[(i + 1) % LAGO.size()]
		if _distancia_a_segmento(punto, a, b) < margen_lago:
			return true

	return false


func _distancia_a_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var largo2 := ab.length_squared()
	if largo2 < 0.001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / largo2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ============================================================
#  Fijar: pasar todo a MultiMesh
# ============================================================
#
# Cada planta suelta es una draw call. Con ~1300 plantas eso son ~1300
# llamadas por frame. El MultiMesh junta todas las copias de un mismo
# modelo en una sola, asi que quedan tantas llamadas como modelos
# distintos haya (unas pocas decenas).
#
# Lo que se pierde: el descarte por objeto (Godot deja de evaluar planta
# por planta y pasa a evaluar el conjunto) y la posibilidad de mover una
# a mano. Para este parque, el cambio conviene por lejos.

const NODO_FIJADO := "Fijado"


func fijar_poblacion() -> void:
	var previo := get_node_or_null(NODO_FIJADO)
	if previo:
		previo.free()

	# 1. Recolectamos todas las mallas con su posicion final
	var por_malla: Dictionary = {}     # Mesh -> Array[Transform3D]
	for hijo in get_children():
		if hijo.name == NODO_COLISIONES:
			continue          # las colisiones se quedan como estan
		_recolectar(hijo, hijo.transform, por_malla)

	if por_malla.is_empty():
		push_warning("[Poblador] no hay nada plantado para fijar")
		return

	# 2. Sacamos las instancias sueltas, pero NO las colisiones
	for hijo in get_children():
		if hijo.name == NODO_COLISIONES:
			continue
		hijo.free()

	# 3. Un MultiMeshInstance3D por cada malla distinta
	var contenedor := Node3D.new()
	contenedor.name = NODO_FIJADO
	add_child(contenedor)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		contenedor.owner = get_tree().edited_scene_root

	var total := 0
	var n := 0
	for malla in por_malla:
		var transformaciones: Array = por_malla[malla]

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla
		mm.instance_count = transformaciones.size()
		for i in range(transformaciones.size()):
			mm.set_instance_transform(i, transformaciones[i])

		var nodo := MultiMeshInstance3D.new()
		nodo.name = "Grupo%d" % n
		nodo.multimesh = mm
		contenedor.add_child(nodo)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			nodo.owner = get_tree().edited_scene_root

		total += transformaciones.size()
		n += 1

	print("[Poblador] fijado: %d instancias en %d grupos" % [total, n])


# Baja por el arbol de cada modelo acumulando la transformacion, porque
# un .fbx suele traer el tronco y las hojas como mallas separadas.
func _recolectar(nodo: Node, acumulada: Transform3D, por_malla: Dictionary) -> void:
	if nodo is MeshInstance3D and nodo.mesh != null:
		if not por_malla.has(nodo.mesh):
			por_malla[nodo.mesh] = []
		por_malla[nodo.mesh].append(acumulada)

	for hijo in nodo.get_children():
		if hijo is Node3D:
			_recolectar(hijo, acumulada * hijo.transform, por_malla)
