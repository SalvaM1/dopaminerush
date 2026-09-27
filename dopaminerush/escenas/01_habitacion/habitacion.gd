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
const DURACION_SIN_SENAL: float = 4.0
const RUTA_APAGON := "res://assets/audio/ui/powerdown.wav"
const PITCH_APAGON: float = 0.78     # un poco mas grave que el original
const VOLUMEN_APAGON: float = 5.0    # y un poco mas fuerte
const CAJA_TAMANO := Vector2(660, 300)

# Cuanto retrocede el cuerpo al colapsar, para salir de adentro del
# escritorio antes de que el jugador pueda mirar alrededor.
const DISTANCIA_COLAPSO: float = 0.75
const DURACION_COLAPSO_ATRAS: float = 2.2

# ---- VAPE ----
# Es lo unico que rompe el plano de la pantalla: obliga a soltar el mouse
# y mirar a otro lado. El buff ayuda, pero los segundos de animacion son
# segundos en los que la barra sigue bajando y no se puede tocar nada.
# El vape aparece recien con la tercera app: antes el juego todavia
# es manejable y no hace falta.
const APPS_PARA_VAPE: int = 3
const DEMORA_AVISO_VAPE: float = 3.0   # para que no se amontone con el cartel de oferta

# Zumbido de fondo: ese ruido bajo que tienen todas las habitaciones y
# que solo se nota cuando desaparece. Es lo que hace que el silencio del
# corte de luz pegue: no cortamos musica, cortamos el aire.
const RUTA_ZUMBIDO := "res://assets/audio/ambiente/zumbido.ogg"
const VOLUMEN_ZUMBIDO: float = -26.0
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
@onready var efecto_vape: Label = get_node_or_null("UI/IndicadorVape/Efecto")
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
var _vape_desbloqueado: bool = false
var _aviso_vape: Panel = null
var _zumbido: AudioStreamPlayer = null
var _sin_senal: Control = null
var _snd_apagon: AudioStreamPlayer = null
var _boton_aviso: Panel = null
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
	_crear_aviso_vape()
	_crear_zumbido()
	_crear_sin_senal()
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)

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
	# 1. Mueren las apps y su audio. El zumbido de la habitacion sigue:
	#    lo que fallo es la computadora, no el mundo.
	escritorio.cortar_todo()
	escritorio.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 2. El monitor pierde la señal, como cuando se desconecta un cable.
	#    No explica nada, pero se entiende al instante.
	_mostrar_sin_senal(true)
	await get_tree().create_timer(DURACION_SIN_SENAL).timeout

	# 3. EL APAGON. Todo en el mismo frame: el sonido, la pantalla negra
	#    y el corte del zumbido. Que no quede claro si se corto la luz,
	#    si murio la maquina o si el que colapso fue el jugador.
	if _snd_apagon and _snd_apagon.stream:
		_snd_apagon.play()
	_mostrar_sin_senal(false)
	apagada.show()
	if _zumbido:
		_zumbido.stop()

	# 4. Silencio. La tentacion va a ser rellenarlo; hay que resistirla.
	await get_tree().create_timer(NEGRO_COLAPSO).timeout

	# 5. El cuerpo se aparta del escritorio, despacio.
	var destino := jugador.global_position + jugador.global_transform.basis.z * DISTANCIA_COLAPSO
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
	# Solo existe mientras esta sentado frente a la compu, y despues
	# de que el juego lo haya ofrecido.
	if not _sentado or _puede_levantarse or not _vape_desbloqueado:
		indicador_vape.hide()
		return

	if _vapeando:
		return

	indicador_vape.show()

	# El buff activo manda en la visualizacion: es la unica forma de que
	# el jugador entienda que vapear sirvio para algo.
	if GameManager.buff_vape > 0.0:
		contador_vape.text = "-10%%  %.0f" % ceil(GameManager.buff_vape)
		indicador_vape.modulate = Color(0.45, 1.0, 0.6)
		if efecto_vape:
			efecto_vape.text = "menos ansiedad"
		return

	if _cooldown_vape > 0.0:
		_cooldown_vape = max(0.0, _cooldown_vape - delta)
		contador_vape.text = "%.0f" % ceil(_cooldown_vape)
		indicador_vape.modulate = Color(0.55, 0.55, 0.55, 1.0)
		if efecto_vape:
			efecto_vape.text = "recargando"
		return

	# Listo para usar
	contador_vape.text = "[V]"
	indicador_vape.modulate = Color.WHITE
	if efecto_vape:
		efecto_vape.text = "un respiro"

	if Input.is_action_just_pressed("vapear"):
		_vapear()


func _vapear() -> void:
	_vapeando = true
	indicador_vape.hide()

	# La barra se congela durante la animacion. Sin esto, los ~4 segundos
	# de no poder tocar nada cuestan mas dopamina de la que el buff ahorra,
	# y no conviene vapear nunca.
	GameManager.drenaje_pausado = true

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

	GameManager.drenaje_pausado = false
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


# ============================================================
#  Desbloqueo del vape
# ============================================================

func _al_desbloquear_app(_indice: int) -> void:
	if _vape_desbloqueado:
		return
	if GameManager.apps_desbloqueadas < APPS_PARA_VAPE:
		return

	_vape_desbloqueado = true
	_mostrar_aviso_vape()


# El aviso va en la HABITACION, no en la pantalla de la compu: el vape
# es fisico, no es una app. Si saliera en el monitor se leeria como una
# notificacion mas.
#
# El tono y el diseño son los de un anuncio: el juego no te esta
# ayudando, te esta ofreciendo otra cosa que no te hace bien. Por eso
# es una tarjeta saturada con un boton que late, y no un cartelito de
# tutorial.

func _crear_aviso_vape() -> void:
	# --- la tarjeta ---
	_aviso_vape = Panel.new()
	_aviso_vape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_vape.set_anchors_preset(Control.PRESET_CENTER)
	_aviso_vape.offset_left = -300.0
	_aviso_vape.offset_right = 300.0
	_aviso_vape.offset_top = 90.0
	_aviso_vape.offset_bottom = 350.0
	_aviso_vape.modulate.a = 0.0
	_aviso_vape.visible = false

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.36, 0.22, 0.58)
	estilo.border_width_left = 3
	estilo.border_width_top = 3
	estilo.border_width_right = 3
	estilo.border_width_bottom = 3
	estilo.border_color = Color(0.62, 0.45, 0.95)
	estilo.corner_radius_top_left = 26
	estilo.corner_radius_top_right = 26
	estilo.corner_radius_bottom_right = 26
	estilo.corner_radius_bottom_left = 26
	estilo.shadow_color = Color(0, 0, 0, 0.55)
	estilo.shadow_size = 22
	estilo.shadow_offset = Vector2(0, 10)
	_aviso_vape.add_theme_stylebox_override("panel", estilo)

	# --- etiqueta chica de arriba, como un "patrocinado" ---
	var etiqueta := Label.new()
	etiqueta.text = "RECOMENDADO PARA VOS"
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	etiqueta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	etiqueta.offset_top = 22.0
	etiqueta.offset_bottom = 44.0
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_vape.add_child(etiqueta)

	# --- titular ---
	var titulo := Label.new()
	titulo.text = "¿Ansioso?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 46)
	titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 50.0
	titulo.offset_bottom = 110.0
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_vape.add_child(titulo)

	# --- bajada ---
	var texto := Label.new()
	texto.text = "Date un respiro. Todos lo hacen."
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 20)
	texto.add_theme_color_override("font_color", Color(0.88, 0.83, 0.98))
	texto.set_anchors_preset(Control.PRESET_TOP_WIDE)
	texto.offset_top = 116.0
	texto.offset_bottom = 148.0
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_vape.add_child(texto)

	# --- el boton falso ---
	# No se clickea (se usa la V), pero tiene que verse como un boton:
	# es lo que hace que el cartel se lea como publicidad y no como ayuda.
	_boton_aviso = Panel.new()
	_boton_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boton_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boton_aviso.offset_left = -150.0
	_boton_aviso.offset_right = 150.0
	_boton_aviso.offset_top = -92.0
	_boton_aviso.offset_bottom = -26.0

	var estilo_btn := StyleBoxFlat.new()
	estilo_btn.bg_color = Color(0.99, 0.78, 0.25)
	estilo_btn.border_width_bottom = 6
	estilo_btn.border_color = Color(0.72, 0.52, 0.09)
	estilo_btn.corner_radius_top_left = 18
	estilo_btn.corner_radius_top_right = 18
	estilo_btn.corner_radius_bottom_right = 18
	estilo_btn.corner_radius_bottom_left = 18
	_boton_aviso.add_theme_stylebox_override("panel", estilo_btn)

	var texto_btn := Label.new()
	texto_btn.text = "[V]  Vapear"
	texto_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_btn.add_theme_font_size_override("font_size", 26)
	texto_btn.add_theme_color_override("font_color", Color(0.22, 0.14, 0.04))
	texto_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_btn.offset_bottom = -6.0
	texto_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boton_aviso.add_child(texto_btn)

	_aviso_vape.add_child(_boton_aviso)
	$UI.add_child(_aviso_vape)


func _mostrar_aviso_vape() -> void:
	if _aviso_vape == null:
		return

	# Un respiro despues del cartel de oferta, para que no se amontonen
	await get_tree().create_timer(DEMORA_AVISO_VAPE).timeout
	if not is_instance_valid(_aviso_vape):
		return

	_aviso_vape.visible = true
	_aviso_vape.pivot_offset = _aviso_vape.size * 0.5
	_aviso_vape.scale = Vector2(0.7, 0.7)
	_aviso_vape.rotation = deg_to_rad(-3.0)

	# Entrada con rebote: salta, no aparece
	var entrada := create_tween()
	entrada.set_parallel(true)
	entrada.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_property(_aviso_vape, "scale", Vector2.ONE, 0.55)
	entrada.tween_property(_aviso_vape, "rotation", 0.0, 0.55)
	entrada.tween_property(_aviso_vape, "modulate:a", 1.0, 0.3)
	await entrada.finished

	# El boton late mientras el cartel esta en pantalla
	Juice.centrar_pivote(_boton_aviso)
	var latido := create_tween().set_loops()
	latido.set_trans(Tween.TRANS_SINE)
	latido.tween_property(_boton_aviso, "scale", Vector2.ONE * 1.06, 0.45)
	latido.tween_property(_boton_aviso, "scale", Vector2.ONE, 0.45)

	await get_tree().create_timer(5.0).timeout

	if latido.is_valid():
		latido.kill()
	if not is_instance_valid(_aviso_vape):
		return

	# Salida
	var salida := create_tween()
	salida.set_parallel(true)
	salida.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	salida.tween_property(_aviso_vape, "scale", Vector2(0.85, 0.85), 0.4)
	salida.tween_property(_aviso_vape, "modulate:a", 0.0, 0.4)
	await salida.finished

	if is_instance_valid(_aviso_vape):
		_aviso_vape.visible = false


# ============================================================
#  Zumbido de fondo
# ============================================================

func _crear_zumbido() -> void:
	if not ResourceLoader.exists(RUTA_ZUMBIDO):
		print("[Habitacion] falta el zumbido: ", RUTA_ZUMBIDO)
		return

	_zumbido = AudioStreamPlayer.new()
	_zumbido.stream = load(RUTA_ZUMBIDO)
	_zumbido.bus = "Ambiente"
	_zumbido.volume_db = -60.0
	add_child(_zumbido)
	_zumbido.play()

	# Entra despacio, junto con la conciencia
	AudioManager.fundir_entrada(_zumbido, 4.0, VOLUMEN_ZUMBIDO)


# ============================================================
#  El apagon
# ============================================================

func _crear_sin_senal() -> void:
	# Va DENTRO del SubViewport, asi aparece sobre la pantalla del
	# monitor y no flotando en el aire.
	#
	# El diseño imita el OSD de un monitor real: caja oscura con borde
	# claro, tipografia en mayusculas, jerarquia de tres niveles y una
	# linea final que anticipa el apagon sin explicarlo.
	_sin_senal = Control.new()
	_sin_senal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sin_senal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sin_senal.visible = false

	var fondo := ColorRect.new()
	fondo.color = Color(0.008, 0.008, 0.012)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sin_senal.add_child(fondo)

	# --- la caja que deriva ---
	var caja := Panel.new()
	caja.name = "Caja"
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.size = CAJA_TAMANO
	caja.position = Vector2(650, 410)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.043, 0.047, 0.062, 0.97)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2
	estilo.border_color = Color(0.3, 0.33, 0.4)
	estilo.corner_radius_top_left = 6
	estilo.corner_radius_top_right = 6
	estilo.corner_radius_bottom_right = 6
	estilo.corner_radius_bottom_left = 6
	estilo.shadow_color = Color(0, 0, 0, 0.6)
	estilo.shadow_size = 18
	estilo.shadow_offset = Vector2(0, 6)
	caja.add_theme_stylebox_override("panel", estilo)

	# Franja de acento arriba
	var acento := ColorRect.new()
	acento.color = Color(0.36, 0.55, 0.85)
	acento.set_anchors_preset(Control.PRESET_TOP_WIDE)
	acento.offset_left = 2.0
	acento.offset_right = -2.0
	acento.offset_top = 2.0
	acento.offset_bottom = 7.0
	acento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(acento)

	# Titular
	var titulo := Label.new()
	titulo.text = "SIN SEÑAL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 58)
	titulo.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 38.0
	titulo.offset_bottom = 110.0
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(titulo)

	# Separador
	var linea := ColorRect.new()
	linea.color = Color(0.22, 0.25, 0.31)
	linea.set_anchors_preset(Control.PRESET_TOP_WIDE)
	linea.offset_left = 70.0
	linea.offset_right = -70.0
	linea.offset_top = 122.0
	linea.offset_bottom = 123.0
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(linea)

	# Entrada
	var entrada := Label.new()
	entrada.text = "ENTRADA:  HDMI 1"
	entrada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entrada.add_theme_font_size_override("font_size", 24)
	entrada.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	entrada.set_anchors_preset(Control.PRESET_TOP_WIDE)
	entrada.offset_top = 140.0
	entrada.offset_bottom = 176.0
	entrada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(entrada)

	# Instruccion
	var ayuda := Label.new()
	ayuda.text = "Verificá la conexión del cable"
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 19)
	ayuda.add_theme_color_override("font_color", Color(0.4, 0.44, 0.52))
	ayuda.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ayuda.offset_top = 182.0
	ayuda.offset_bottom = 212.0
	ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(ayuda)

	# Ultima linea: anticipa el apagon sin explicarlo
	var aviso := Label.new()
	aviso.text = "El monitor entrará en modo de ahorro de energía"
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 15)
	aviso.add_theme_color_override("font_color", Color(0.29, 0.32, 0.39))
	aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	aviso.offset_top = -38.0
	aviso.offset_bottom = -16.0
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(aviso)

	_sin_senal.add_child(caja)
	pantalla_viewport.add_child(_sin_senal)

	# El sonido del apagon
	if ResourceLoader.exists(RUTA_APAGON):
		_snd_apagon = AudioStreamPlayer.new()
		_snd_apagon.stream = load(RUTA_APAGON)
		_snd_apagon.bus = "Ambiente"
		_snd_apagon.pitch_scale = PITCH_APAGON
		_snd_apagon.volume_db = VOLUMEN_APAGON
		add_child(_snd_apagon)
	else:
		print("[Habitacion] falta el sonido del apagon: ", RUTA_APAGON)


func _mostrar_sin_senal(visible_: bool) -> void:
	if _sin_senal == null:
		return

	_sin_senal.visible = visible_
	if not visible_:
		return

	# La caja deriva despacio por la pantalla, como en los monitores de
	# verdad cuando se quedan sin entrada. El recorrido esta calculado
	# para que nunca toque los bordes.
	var caja: Panel = _sin_senal.get_node_or_null("Caja")
	if caja == null:
		return

	caja.modulate.a = 0.0
	var entrada_tween := create_tween()
	entrada_tween.tween_property(caja, "modulate:a", 1.0, 0.35)

	var libre := Vector2(pantalla_viewport.size) - CAJA_TAMANO
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(caja, "position", Vector2(libre.x * 0.82, libre.y * 0.74), 3.1)
	t.tween_property(caja, "position", Vector2(libre.x * 0.14, libre.y * 0.86), 3.1)
	t.tween_property(caja, "position", Vector2(libre.x * 0.72, libre.y * 0.16), 3.1)
	t.tween_property(caja, "position", Vector2(libre.x * 0.5, libre.y * 0.5), 3.1)
