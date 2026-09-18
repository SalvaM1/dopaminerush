extends Node3D

# ============================================================
#  Habitacion
# ============================================================
#
# El escritorio 2D vive adentro de un SubViewport, y ese SubViewport se usa
# como textura del quad "Pantalla" del monitor 3D. Asi la interfaz es parte
# del objeto: la camara se puede mover y la pantalla se mueve con el monitor.
#
# FLUJO COMPLETO:
#   1. Negro total. Suena el despertador (entra por fundido). Sin control.
#   2. Se habilita mirar y la imagen aparece por fundido.
#   3. El despertador es lo unico interactuable -> al apagarlo:
#      se habilita caminar y el despertador se apaga como interactuable.
#   4. Mira el monitor, aprieta E -> la camara viaja a PuntoSentado.
#   5. Se bloquea todo, se libera el cursor, la pantalla se enciende.
#   6. Queda sentado hasta que la dopamina colapsa.
#   7. Durante el colapso: solo puede mirar. Ningun objeto responde.
#      Solo aparece el cartel de levantarse.
#   8. Al levantarse se habilita la puerta, y solo ahi se puede salir.
#
# CADA OBJETO SE APAGA CUANDO YA CUMPLIO SU FUNCION. Por eso nunca se
# superponen dos carteles ni se puede hacer algo fuera de orden.

const DURACION_TRANSICION: float = 1.5
const ALCANCE_RAYO: float = 5.0

# Despertar
const NEGRO_INICIAL: float = 3.0      # segundos de negro con el despertador sonando
const FUNDIDO_DESPERTAR: float = 2.0  # cuanto tarda en aparecer la imagen

# Colapso
const NEGRO_COLAPSO: float = 2.0

@onready var jugador: CharacterBody3D = $Jugador
@onready var punto_sentado: Marker3D = $Monitor/PuntoSentado
@onready var monitor: Interactuable = $Monitor
@onready var pantalla: MeshInstance3D = $Monitor/Pantalla
@onready var area_pantalla: Area3D = $Monitor/Pantalla/AreaPantalla
@onready var despertador: Interactuable = $Despertador
@onready var puerta: Interactuable = $Puerta
@onready var pantalla_viewport: SubViewport = $PantallaViewport
@onready var apagada: ColorRect = $PantallaViewport/Apagada
@onready var escritorio: CanvasLayer = $PantallaViewport/Escritorio
@onready var cartel_levantarse: Label = $UI/CartelLevantarse

# Opcional: si no existe el nodo, la secuencia funciona igual en silencio.
@onready var sonido_despertador: AudioStreamPlayer3D = get_node_or_null("Despertador/Sonido")

var _desperto: bool = false
var _sentado: bool = false
var _puede_levantarse: bool = false
# Donde estaba la camara RESPECTO DEL CUERPO antes de sentarse.
# Volver a esta transformacion local (y no a la global) es lo que hace
# que al levantarse la camara quede otra vez alineada con el cuerpo,
# sin importar hacia donde se estuviera mirando.
var _transform_local_original: Transform3D
var _ultima_pos_viewport: Vector2 = Vector2.ZERO


func _ready() -> void:
	# La textura del monitor es lo que renderiza el SubViewport.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = pantalla_viewport.get_texture()
	pantalla.material_override = material

	apagada.show()
	escritorio.hide()
	cartel_levantarse.hide()

	# La puerta no existe como opcion hasta despues del colapso
	puerta.activo = false

	despertador.usado.connect(_apagar_despertador)
	monitor.usado.connect(_sentarse)
	puerta.usado.connect(_salir_al_parque)
	GameManager.colapso.connect(_al_colapsar)

	_despertar()


func _process(_delta: float) -> void:
	if _puede_levantarse and Input.is_action_just_pressed("interactuar"):
		_levantarse()


# ============================================================
#  Despertar
# ============================================================

func _despertar() -> void:
	# Negro total antes de que se vea un solo frame
	SceneLoader.tapar_ya(Color.BLACK)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jugador.puede_mover = false
	jugador.puede_mirar = false

	# El despertador entra de a poco, junto con la conciencia
	if sonido_despertador and sonido_despertador.stream:
		AudioManager.fundir_entrada(sonido_despertador, NEGRO_INICIAL + 1.0, 0.0)

	# Solo sonido, sin imagen
	await get_tree().create_timer(NEGRO_INICIAL).timeout

	# Aparece la habitacion. Se puede mirar, pero todavia no caminar:
	# lo unico posible es buscar el despertador con la vista.
	jugador.puede_mirar = true
	await SceneLoader.fundir_desde(FUNDIDO_DESPERTAR)


func _apagar_despertador() -> void:
	if _desperto:
		return
	_desperto = true

	# Ya no sirve para nada: deja de ser interactuable
	despertador.activo = false

	if sonido_despertador:
		# Corte seco: apagar un despertador es un gesto, no un desvanecimiento
		AudioManager.fundir_salida(sonido_despertador, 0.15)

	# Recien ahora se puede caminar
	jugador.puede_mover = true


# ============================================================
#  Reenvio de input al SubViewport
# ============================================================

func _input(event: InputEvent) -> void:
	if not _sentado or _puede_levantarse:
		return

	if event is InputEventKey:
		pantalla_viewport.push_input(event)
		return

	if not (event is InputEventMouse):
		return

	var punto := _punto_en_viewport(event.position)
	if punto == Vector2(-1, -1):
		return   # el mouse no esta sobre la pantalla del monitor

	var evento := event.duplicate() as InputEventMouse
	evento.position = punto
	evento.global_position = punto

	if evento is InputEventMouseMotion:
		# El "relative" original esta en pixeles de la ventana real.
		# Lo recalculamos en pixeles del viewport para que el gesto de
		# arrastrar de las apps funcione igual.
		evento.relative = punto - _ultima_pos_viewport

	_ultima_pos_viewport = punto
	pantalla_viewport.push_input(evento)


# Convierte una posicion del mouse en pantalla a coordenadas del SubViewport.
# Devuelve (-1, -1) si el mouse no apunta a la pantalla del monitor.
func _punto_en_viewport(pos_mouse: Vector2) -> Vector2:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return Vector2(-1, -1)

	var origen := camara.project_ray_origin(pos_mouse)
	var direccion := camara.project_ray_normal(pos_mouse)

	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * ALCANCE_RAYO)
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false

	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty() or resultado.collider != area_pantalla:
		return Vector2(-1, -1)

	# Punto de impacto en coordenadas locales del quad.
	# Un QuadMesh esta centrado en el origen, en el plano XY, mirando a +Z.
	var local: Vector3 = pantalla.to_local(resultado.position)
	var tamano: Vector2 = pantalla.mesh.size

	var u := (local.x / tamano.x) + 0.5          # 0 = izquierda, 1 = derecha
	var v := 0.5 - (local.y / tamano.y)          # 0 = arriba,    1 = abajo

	return Vector2(u, v) * Vector2(pantalla_viewport.size)


# ============================================================
#  Sentarse
# ============================================================

func _sentarse() -> void:
	# No se puede ir a la compu sin apagar antes el despertador
	if _sentado or not _desperto:
		return
	_sentado = true

	# Una vez sentado ya no tiene sentido volver a "sentarse"
	monitor.activo = false

	var camara: Camera3D = jugador.camara
	_transform_local_original = camara.transform

	jugador.puede_mover = false
	jugador.puede_mirar = false

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camara, "global_transform",
		punto_sentado.global_transform, DURACION_TRANSICION)
	await tween.finished

	apagada.hide()
	escritorio.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.iniciar_sesion_pc()


# ============================================================
#  Colapso y levantarse
# ============================================================

func _al_colapsar() -> void:
	# Version minima. En el paso 40 aca va la secuencia completa:
	# apagar luces, silenciar todo, negro absoluto.
	escritorio.hide()
	apagada.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	await get_tree().create_timer(NEGRO_COLAPSO).timeout

	_puede_levantarse = true
	cartel_levantarse.text = "[E] Levantarse"
	cartel_levantarse.show()

	# Se puede girar la cabeza, pero NADA responde: el unico cartel
	# posible es el de levantarse.
	# Sincronizamos las variables con donde quedo la camara realmente,
	# para que el mouse no pegue un salto en el primer movimiento.
	jugador.rotacion_horizontal_sentado = jugador.camara.rotation.y
	jugador.rotacion_vertical = jugador.camara.rotation.x
	jugador.mirar_sentado = true
	jugador.puede_mirar = true
	jugador.puede_interactuar = false


func _levantarse() -> void:
	_puede_levantarse = false
	cartel_levantarse.hide()
	jugador.puede_mirar = false

	var camara: Camera3D = jugador.camara
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Volvemos a la transformacion LOCAL: la camara queda otra vez
	# alineada con el cuerpo y el WASD apunta bien.
	tween.tween_property(camara, "transform",
		_transform_local_original, DURACION_TRANSICION)
	await tween.finished

	# De vuelta al modo de pie
	jugador.mirar_sentado = false
	jugador.rotacion_horizontal_sentado = 0.0
	jugador.rotacion_vertical = camara.rotation.x

	_sentado = false
	jugador.puede_mover = true
	jugador.puede_mirar = true
	jugador.puede_interactuar = true

	# Ahora si: la unica salida
	puerta.activo = true


func _salir_al_parque() -> void:
	jugador.puede_mover = false
	jugador.puede_mirar = false
	jugador.puede_interactuar = false
	await SceneLoader.cambiar_escena("res://escenas/04_parque/parque.tscn", Color.WHITE, 2.0)
