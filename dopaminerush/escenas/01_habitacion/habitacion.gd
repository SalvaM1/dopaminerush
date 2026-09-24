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

# Cuanto retrocede el cuerpo al colapsar, para salir de adentro del
# escritorio antes de que el jugador pueda mirar alrededor.
const DISTANCIA_COLAPSO: float = 0.75
const DURACION_COLAPSO_ATRAS: float = 2.2

# ---- VAPE ----
# Es lo unico que rompe el plano de la pantalla: obliga a soltar el mouse
# y mirar a otro lado. El buff ayuda, pero los segundos de animacion son
# segundos en los que la barra sigue bajando y no se puede tocar nada.
const VAPE_COOLDOWN: float = 20.0
const VAPE_CAMARA_IDA: float = 0.7
const VAPE_CAMARA_VUELTA: float = 0.7
const VAPE_SUBE: float = 0.5        # cuanto tarda en llegar a la boca
const VAPE_PITADA: float = 0.9      # cuanto se queda ahi
const VAPE_BAJA: float = 0.4

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

# Vape
@onready var vape: Node3D = $Monitor/Vape
@onready var punto_vape: Marker3D = $Monitor/PuntoVape
@onready var humo: GPUParticles3D = $Monitor/Vape/Humo
@onready var indicador_vape: Control = $UI/IndicadorVape
@onready var contador_vape: Label = $UI/IndicadorVape/Contador
@onready var sonido_vape: AudioStreamPlayer3D = get_node_or_null("Monitor/Vape/Sonido")

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

var _vapeando: bool = false
var _cooldown_vape: float = 0.0
var _vape_pos_base: Vector3
var _camara_sentado: Transform3D


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

	_vape_pos_base = vape.position
	_configurar_humo()
	indicador_vape.hide()

	despertador.usado.connect(_apagar_despertador)
	monitor.usado.connect(_sentarse)
	puerta.usado.connect(_salir_al_parque)
	GameManager.colapso.connect(_al_colapsar)

	_despertar()


func _process(delta: float) -> void:
	if _puede_levantarse and Input.is_action_just_pressed("interactuar"):
		_levantarse()

	_actualizar_vape(delta)


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
	if not _sentado or _puede_levantarse or _vapeando:
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

	# Le apagamos la fisica al cuerpo: es un CharacterBody3D y su
	# move_and_slide() lo empujaria fuera del escritorio, corriendo la
	# camara de lugar. Sentado no necesita fisica para nada.
	jugador.set_physics_process(false)

	# El CUERPO viaja hasta el punto de la silla, alineado hacia el monitor.
	var destino_cuerpo := punto_sentado.global_transform
	destino_cuerpo.origin.y = jugador.global_position.y   # el cuerpo no flota

	# La CAMARA solo baja a la altura de ojos sentado, sin rotacion propia.
	# Animarla en global mientras el cuerpo se mueve la dejaba con una
	# transformacion local rara, y eso causaba un salto al levantarse.
	# Asi, el punto donde termina es exactamente el mismo del que sale.
	var altura_sentado: float = punto_sentado.global_position.y - jugador.global_position.y
	var destino_camara := Transform3D(Basis(), Vector3(0, altura_sentado, 0))

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(jugador, "global_transform", destino_cuerpo, DURACION_TRANSICION)
	tween.tween_property(camara, "transform", destino_camara, DURACION_TRANSICION)

	await tween.finished

	# La camara queda alineada con el cuerpo, mirando derecho al monitor
	jugador.rotacion_vertical = 0.0
	jugador.rotacion_horizontal_sentado = 0.0

	# Guardamos este punto exacto: es al que vuelve la camara despues de vapear
	_camara_sentado = camara.transform

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

	# El cuerpo se aparta del escritorio, despacio, durante el silencio.
	# Estaba metido adentro de la madera: si no se corre, al mirar
	# alrededor se veria desde adentro del mueble.
	var destino := jugador.global_position + jugador.global_transform.basis.z * DISTANCIA_COLAPSO
	print("[colapso] retrocede de ", jugador.global_position, " a ", destino)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(jugador, "global_position", destino, DURACION_COLAPSO_ATRAS)
	await tween.finished

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
	jugador.set_physics_process(true)
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


# ============================================================
#  El vape
# ============================================================

func _actualizar_vape(delta: float) -> void:
	# Solo existe mientras esta sentado frente a la compu
	if not _sentado or _puede_levantarse:
		indicador_vape.hide()
		return

	if _vapeando:
		return

	if _cooldown_vape > 0.0:
		_cooldown_vape = max(0.0, _cooldown_vape - delta)
		indicador_vape.show()
		contador_vape.text = "%.0f" % ceil(_cooldown_vape)
		indicador_vape.modulate = Color(0.55, 0.55, 0.55, 1.0)
		return

	# Listo para usar
	indicador_vape.show()
	contador_vape.text = "[V]"
	indicador_vape.modulate = Color.WHITE

	if Input.is_action_just_pressed("vapear"):
		_vapear()


func _vapear() -> void:
	_vapeando = true
	indicador_vape.hide()

	var camara: Camera3D = jugador.camara

	# El punto del vape esta definido por un Marker3D, pero la camara es
	# hija del cuerpo: convertimos a coordenadas locales del jugador.
	var destino := jugador.global_transform.affine_inverse() * punto_vape.global_transform

	# 1. La camara se aleja y mira al costado
	var t1 := create_tween()
	t1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t1.tween_property(camara, "transform", destino, VAPE_CAMARA_IDA)
	await t1.finished

	# 2. El vape sube hasta la boca: un punto calculado respecto de la
	# camara, no un offset fijo, asi funciona la mire desde donde la mire.
	var boca := camara.global_position + camara.global_transform.basis * Vector3(0, -0.09, -0.26)

	var t2 := create_tween()
	t2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t2.tween_property(vape, "global_position", boca, VAPE_SUBE)
	await t2.finished

	# 3. Recien con el vape en la boca: sonido y humo
	if sonido_vape and sonido_vape.stream:
		sonido_vape.play()

	humo.restart()
	humo.emitting = true

	await get_tree().create_timer(VAPE_PITADA).timeout

	# 4. El vape vuelve a la mesa
	var t3 := create_tween()
	t3.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t3.tween_property(vape, "position", _vape_pos_base, VAPE_BAJA)
	await t3.finished

	# 5. La camara vuelve a la pantalla
	var t4 := create_tween()
	t4.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t4.tween_property(camara, "transform", _camara_sentado, VAPE_CAMARA_VUELTA)
	await t4.finished

	GameManager.aplicar_buff_vape()
	_cooldown_vape = VAPE_COOLDOWN
	_vapeando = false


# El material de particulas se arma por codigo: son muchas propiedades
# para configurar a mano en el editor y asi queda igual para todos.
func _configurar_humo() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0.4)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.35
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0, 0.15, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.6
	mat.damping_min = 0.4
	mat.damping_max = 0.9

	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.85, 0.87, 0.9, 0.55))
	rampa.set_color(1, Color(0.85, 0.87, 0.9, 0.0))
	var textura := GradientTexture1D.new()
	textura.gradient = rampa
	mat.color_ramp = textura

	humo.process_material = mat
	humo.amount = 40
	humo.lifetime = 2.2
	humo.one_shot = true
	humo.explosiveness = 0.5
	humo.emitting = false

	# Si no tiene mesh asignado, le ponemos uno chiquito
	if humo.draw_pass_1 == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.09, 0.09)
		var mat_quad := StandardMaterial3D.new()
		mat_quad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_quad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_quad.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat_quad.vertex_color_use_as_albedo = true
		mat_quad.albedo_color = Color(1, 1, 1, 1)
		quad.material = mat_quad
		humo.draw_pass_1 = quad
