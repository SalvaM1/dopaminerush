extends Node3D

# Television fisica, fuera del catalogo de apps. La habitacion solo aporta
# el acceso a la camara y bloquea sus otros gestos mientras se mira la TV.
# El alivio tiene su propio multiplicador para no pisar LinkedOut ni el vape.
@export_group("Balance")
# La TV llega con la QUINTA app. Hasta la cuarta el juego ya se sostiene
# solo; es recien con cinco ventanas abiertas que la atencion no alcanza
# y hace falta una fuente que no pida mouse.
# OJO: la meseta del drenaje tiene que arrancar junto con la TV. Como el
# GameManager compara con <=, su APPS_HASTA_LA_MESETA (4) es uno menos
# que este numero. Si se mueve uno, mover el otro.
@export var apps_para_desbloquear: int = 5

# Lo que tarda el cartel en aparecer despues de desbloquear la app. Le da
# tiempo al jugador a abrir lo que acaba de conseguir; si el cartel sale
# encima del de la oferta, las dos cosas se pisan.
@export var demora_aviso: float = 15.0
@export var duracion_cartel: float = 8.0

@export_range(0.0, 1.0) var factor_drenaje: float = 0.9

# La mirada es el respiro del juego: da MUCHA dopamina de una, pero no se
# puede repetir seguido. El drenaje sigue corriendo durante la mirada, asi
# que lo que importa es el neto.
@export var dopamina_por_mirada: float = 70.0
@export var cooldown: float = 30.0

# El giro dura casi el doble que al principio. La camara gira Y hace un
# zoom de 80 a 22 grados de FOV: comprimir las dos cosas en medio segundo
# era lo que hacia que se sintiera brusco, no la interpolacion.
@export var duracion_mirada: float = 4.2
@export var duracion_giro: float = 0.95

@export_group("Encuadre")
@export_range(10.0, 80.0) var fov_television: float = 22.0

@export_group("Pelicula")
# Imagen y sonido separados: el audio del VideoStreamPlayer es 2D.
# La pista aparte se reproduce desde la TV con AudioStreamPlayer3D.
@export_file("*.ogv") var ruta_video: String = "res://assets/video/netflox/pelicula.ogv"
@export_file("*.ogg", "*.wav", "*.mp3") var ruta_audio: String = "res://assets/audio/netflox/pelicula.ogg"

@onready var viewport_tv: SubViewport = $PantallaViewport
@onready var marco: Control = $PantallaViewport/Pantalla
@onready var pelicula: VideoStreamPlayer = $PantallaViewport/Pantalla/Pelicula
@onready var portada: Control = $PantallaViewport/Pantalla/Portada
@onready var destello: ColorRect = $PantallaViewport/Pantalla/Destello
@onready var sonido: AudioStreamPlayer3D = $SonidoPelicula

var _habitacion: Node3D
var _pantalla: CSGBox3D
var _superficie: MeshInstance3D
var _indicador: Control
var _contador: Label
var _efecto: Label
var _camara: Camera3D
var _camara_base: Transform3D
var _fov_base: float
var _tween_mirada: Tween
var _desbloqueada: bool = false
var _anuncio_pedido: bool = false
var _encendida: bool = false
var _mirando: bool = false
var _cooldown_restante: float = 0.0

var _cartel: Panel = null
var _boton_cartel: Panel = null
var _cartel_visible: bool = false
var _latido_cartel: Tween = null


func _ready() -> void:
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)
	GameManager.fallo_temprano.connect(_cancelar_mirada)
	GameManager.dia_arruinado.connect(apagar)
	GameManager.colapso.connect(apagar)
	sonido.finished.connect(_repetir_audio)
	pelicula.volume_db = -80.0
	_cargar_pelicula()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_DISABLED


func configurar(habitacion: Node3D) -> void:
	_habitacion = habitacion
	_pantalla = habitacion.get_node("HabitacionVisual/Televisor/Cuerpo/Pantalla")
	_indicador = habitacion.get_node("UI/IndicadorNetflox")
	_contador = _indicador.get_node("Contador")
	_efecto = _indicador.get_node("Efecto")
	_indicador.hide()

	# El modelo existente queda en su lugar. Un quad sobre la cara que
	# mira al jugador recibe la imagen del viewport sin estirar los bordes.
	var vidrio := StandardMaterial3D.new()
	vidrio.albedo_color = Color(0.008, 0.008, 0.012)
	vidrio.roughness = 0.25
	_pantalla.material = vidrio
	var quad := QuadMesh.new()
	quad.size = Vector2(_pantalla.size.z, _pantalla.size.y)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport_tv.get_texture()
	_superficie = MeshInstance3D.new()
	_superficie.name = "ImagenNetflox"
	_superficie.mesh = quad
	_superficie.material_override = material
	_superficie.position.x = -_pantalla.size.x * 0.5 - 0.002
	_superficie.rotation.y = -PI * 0.5
	_superficie.hide()
	_pantalla.add_child(_superficie)
	sonido.global_position = _pantalla.global_position
	_crear_cartel()
	_al_desbloquear_app(-1)


func _process(delta: float) -> void:
	if not is_instance_valid(_habitacion):
		return
	if GameManager.activo:
		_cooldown_restante = maxf(0.0, _cooldown_restante - delta)

	var disponible: bool = _desbloqueada and _habitacion.puede_usar_television()
	_indicador.visible = disponible or (_mirando and GameManager.activo)
	_actualizar_indicador()
	if not disponible or _mirando:
		return
	if Input.is_action_just_pressed("mirar_television"):
		# La primera T enciende y ADEMAS gira la camara: si solo encendiera,
		# el jugador se perderia la animacion de encendido, que pasa en una
		# tele que todavia no esta mirando.
		if not _encendida:
			encender()
		mirar()


func _al_desbloquear_app(_indice: int) -> void:
	if _desbloqueada or _anuncio_pedido:
		return
	if GameManager.apps_desbloqueadas < apps_para_desbloquear:
		return
	_anuncio_pedido = true
	_anunciar()


# La TV no aparece de golpe: espera, y entra con su propio cartel, igual
# que el vape. El indicador aparece en el MISMO frame que el cartel, para
# que se lea como parte del anuncio y no como algo que ya estaba.
func _anunciar() -> void:
	await get_tree().create_timer(demora_aviso).timeout
	if not is_instance_valid(self) or not is_instance_valid(_habitacion):
		return

	# La TV queda habilitada SIEMPRE. Si esto volviera sin habilitarla,
	# como _anuncio_pedido ya quedo en true, la television se perderia
	# para el resto de la partida.
	_desbloqueada = true

	# El cartel, en cambio, solo tiene sentido con el jugador en la PC: si
	# el dia se arruino durante la espera, se saltea y la TV igual esta.
	if GameManager.activo:
		_mostrar_cartel()


func esta_mirando() -> bool:
	return _mirando


func encender() -> void:
	if _encendida or not _puede_usar():
		return
	_encendida = true
	GameManager.mult_drenaje_netflox = factor_drenaje
	_superficie.show()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if pelicula.stream:
		pelicula.play()
	if sonido.stream:
		sonido.play()
	_animar_encendido()
	_actualizar_indicador()


# El encendido de un tubo: una linea horizontal que aguanta un instante y
# despues se abre en vertical, con un fogonazo. Se escala la Pantalla
# entera (con su fondo), asi que detras queda el negro del viewport, que
# es justo lo que se ve en una tele prendiendose.
#
# Va con demora: la camara tarda duracion_giro en llegar, y el encendido
# tiene que terminar cuando el jugador ya esta mirando la pantalla.
func _animar_encendido() -> void:
	if not is_instance_valid(marco):
		return

	var demora: float = maxf(0.0, duracion_giro - 0.4)
	marco.pivot_offset = marco.size * 0.5
	marco.scale = Vector2(1.3, 0.004)
	destello.color.a = 0.0

	var abrir := create_tween()
	abrir.tween_interval(demora)
	abrir.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	abrir.tween_property(marco, "scale", Vector2.ONE, 0.32)

	var brillo := create_tween()
	brillo.tween_interval(demora)
	brillo.tween_property(destello, "color:a", 0.65, 0.10)
	brillo.tween_property(destello, "color:a", 0.0, 0.40)
	brillo.tween_callback(_calmar_viewport)


# SIN PELICULA LA PANTALLA ES UNA IMAGEN QUIETA, y redibujarla 60 veces
# por segundo es tirar el cuadro a la basura 60 veces por segundo. Con
# cinco apps abiertas (y Godot decodificando Ogg por CPU) eso alcanzaba
# para trabar el juego entero.
#
# Terminada la animacion, si no hay video, se dibuja UNA vez y listo. Con
# video hay que seguir, porque cada cuadro es distinto.
func _calmar_viewport() -> void:
	if not _encendida or not is_instance_valid(viewport_tv):
		return
	if pelicula.stream != null:
		return
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_ONCE


func mirar() -> void:
	if not _encendida or _mirando or _cooldown_restante > 0.0 or not _puede_usar():
		return
	_mirando = true
	# El cartel esta justo en el centro y taparia la tele, o sea la cosa
	# que el cartel vino a anunciar.
	_cerrar_cartel(0.22)
	_habitacion.soltar_mouse_del_monitor()
	_camara = _habitacion.jugador.camara
	_camara_base = _camara.transform
	_fov_base = _camara.fov

	# Girar desde la silla y acercar el encuadre para leer la pantalla.
	# El zoom acompana el giro y se restaura al volver al monitor.
	var global_destino := _camara.global_transform.looking_at(_pantalla.global_position, Vector3.UP)
	var destino: Transform3D = _camara.get_parent().global_transform.affine_inverse() * global_destino
	var giro: float = minf(duracion_giro, duracion_mirada * 0.5)
	_tween_mirada = create_tween()
	# CUBIC entra y sale mas suave que SINE, que en el medio es casi lineal.
	# El Tween sobre "transform" ya interpola la rotacion con slerp (probado:
	# conserva la escala en 1.0), asi que no hace falta interpolar a mano.
	_tween_mirada.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween_mirada.tween_property(_camara, "transform", destino, giro)
	_tween_mirada.parallel().tween_property(_camara, "fov", minf(_fov_base, fov_television), giro)
	_tween_mirada.tween_interval(maxf(0.0, duracion_mirada - giro * 2.0))
	_tween_mirada.tween_property(_camara, "transform", _camara_base, giro)
	_tween_mirada.parallel().tween_property(_camara, "fov", _fov_base, giro)
	_tween_mirada.finished.connect(_terminar_mirada)
	_actualizar_indicador()


func _terminar_mirada() -> void:
	_mirando = false
	# El drenaje sigue corriendo mientras se mira. Si hubo una caida, no
	# se entrega una recompensa tardia ni se mueve la camara del colapso.
	if not _encendida or not GameManager.activo:
		return
	_cooldown_restante = cooldown
	GameManager.sumar_dopamina(dopamina_por_mirada, "netflox")
	Juice.numero_flotante(_indicador, "+%d" % int(dopamina_por_mirada),
		Color(0.45, 1.0, 0.6), Vector2(80, 10), 24)
	_actualizar_indicador()


func _cancelar_mirada() -> void:
	if _tween_mirada and _tween_mirada.is_valid():
		_tween_mirada.kill()
	if _mirando and is_instance_valid(_camara):
		_camara.transform = _camara_base
		_camara.fov = _fov_base
	_mirando = false


func apagar() -> void:
	_cerrar_cartel(0.2)
	_cancelar_mirada()
	_encendida = false
	GameManager.mult_drenaje_netflox = 1.0
	pelicula.stop()
	sonido.stop()
	viewport_tv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Dejar el tubo "cerrado" para que el proximo encendido arranque bien.
	if is_instance_valid(marco):
		marco.scale = Vector2.ONE
	if is_instance_valid(destello):
		destello.color.a = 0.0
	if is_instance_valid(_superficie):
		_superficie.hide()
	if is_instance_valid(_indicador):
		_indicador.hide()


func _exit_tree() -> void:
	# Al recargar la habitacion no queda ni el alivio ni un giro pendiente.
	_cancelar_mirada()
	GameManager.mult_drenaje_netflox = 1.0


func _puede_usar() -> bool:
	return _desbloqueada and is_instance_valid(_habitacion) and _habitacion.puede_usar_television()


func _poner(etiqueta: Label, texto: String) -> void:
	# Asignar .text rehace el renglon aunque el texto sea el mismo, y esto
	# corre en cada frame: solo se escribe cuando de verdad cambio.
	if etiqueta.text != texto:
		etiqueta.text = texto


# Mismo formato que el indicador del vape y el del celular: la tecla
# grande arriba y abajo, en chico, lo que hace.
func _actualizar_indicador() -> void:
	if _mirando:
		_poner(_contador, "[T]")
		_poner(_efecto, "mirando...")
	elif not _encendida:
		_poner(_contador, "[T]")
		_poner(_efecto, "prender la tele")
	elif _cooldown_restante > 0.0:
		_poner(_contador, "%.0f s" % ceilf(_cooldown_restante))
		_poner(_efecto, "-%.0f%% drenaje" % ((1.0 - factor_drenaje) * 100.0))
	else:
		_poner(_contador, "[T]")
		_poner(_efecto, "mirar un rato")
	_indicador.modulate = Color(0.65, 0.65, 0.7) if _cooldown_restante > 0.0 else Color.WHITE


func _cargar_pelicula() -> void:
	if ruta_video != "" and ResourceLoader.exists(ruta_video):
		pelicula.stream = load(ruta_video)
	if ruta_audio != "" and ResourceLoader.exists(ruta_audio):
		sonido.stream = load(ruta_audio)
	# Sin archivos se conserva la portada; las mecanicas se pueden probar
	# ahora y la pelicula se agrega despues sin cambiar codigo.
	pelicula.visible = pelicula.stream != null
	portada.visible = pelicula.stream == null


func _repetir_audio() -> void:
	if _encendida and sonido.stream:
		sonido.play()


# ============================================================
#  El cartel
# ============================================================
# Mismo diseño que el del vape y por el mismo motivo: la TV es un objeto
# fisico, no una app, asi que se anuncia en la HABITACION y no en el
# monitor. Si saliera en la pantalla de la compu se leeria como una
# notificacion mas.
#
# Se construye ACA y no en habitacion.gd: Netflox es un modulo aparte y
# el codigo del vape no se toca.
#
# El tono es el de un anuncio, no el de un tutorial: el juego no te esta
# ayudando, te esta ofreciendo otra cosa que no te hace bien.

const ROJO_FONDO := Color(0.62, 0.09, 0.13)
const ROJO_BORDE := Color(0.98, 0.29, 0.33)
const ROJO_SUAVE := Color(1.0, 0.72, 0.72)


func _crear_cartel() -> void:
	if not is_instance_valid(_habitacion):
		return
	var capa := _habitacion.get_node_or_null("UI")
	if capa == null:
		return

	_cartel = Panel.new()
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartel.set_anchors_preset(Control.PRESET_CENTER)
	_cartel.offset_left = -300.0
	_cartel.offset_right = 300.0
	_cartel.offset_top = 90.0
	_cartel.offset_bottom = 350.0
	_cartel.modulate.a = 0.0
	_cartel.visible = false

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = ROJO_FONDO
	estilo.border_width_left = 3
	estilo.border_width_top = 3
	estilo.border_width_right = 3
	estilo.border_width_bottom = 3
	estilo.border_color = ROJO_BORDE
	estilo.corner_radius_top_left = 26
	estilo.corner_radius_top_right = 26
	estilo.corner_radius_bottom_right = 26
	estilo.corner_radius_bottom_left = 26
	estilo.shadow_color = Color(0, 0, 0, 0.55)
	estilo.shadow_size = 22
	estilo.shadow_offset = Vector2(0, 10)
	_cartel.add_theme_stylebox_override("panel", estilo)

	_cartel.add_child(_texto_cartel("LO MAS VISTO HOY", 14, ROJO_SUAVE, 22.0, 44.0))
	_cartel.add_child(_texto_cartel("¿Mucho silencio?", 46, Color(1, 1, 1), 50.0, 110.0))
	_cartel.add_child(_texto_cartel(
		"Prendé el televisor. Ponete una serie de fondo.",
		20, Color(0.99, 0.87, 0.87), 116.0, 148.0))

	# El boton falso. No se clickea (se usa la T), pero tiene que verse
	# como un boton: es lo que hace que se lea como publicidad.
	_boton_cartel = Panel.new()
	_boton_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boton_cartel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boton_cartel.offset_left = -150.0
	_boton_cartel.offset_right = 150.0
	_boton_cartel.offset_top = -92.0
	_boton_cartel.offset_bottom = -26.0

	var estilo_btn := StyleBoxFlat.new()
	estilo_btn.bg_color = Color(0.97, 0.97, 0.98)
	estilo_btn.border_width_bottom = 6
	estilo_btn.border_color = Color(0.62, 0.6, 0.63)
	estilo_btn.corner_radius_top_left = 18
	estilo_btn.corner_radius_top_right = 18
	estilo_btn.corner_radius_bottom_right = 18
	estilo_btn.corner_radius_bottom_left = 18
	_boton_cartel.add_theme_stylebox_override("panel", estilo_btn)

	var texto_btn := _texto_cartel("[T]  Prender la tele", 26, Color(0.18, 0.05, 0.07), 0.0, 0.0)
	texto_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto_btn.offset_bottom = -6.0
	texto_btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boton_cartel.add_child(texto_btn)

	_cartel.add_child(_boton_cartel)
	capa.add_child(_cartel)


func _texto_cartel(texto: String, tamano: int, color: Color,
		arriba: float, abajo: float) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	etiqueta.offset_top = arriba
	etiqueta.offset_bottom = abajo
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _mostrar_cartel() -> void:
	# Sin cartel la TV igual se habilita: dejarla inaccesible para siempre
	# seria peor que quedarse sin anuncio.
	if not is_instance_valid(_cartel):
		return

	_cartel.visible = true
	_cartel.pivot_offset = _cartel.size * 0.5
	_cartel.scale = Vector2(0.7, 0.7)
	_cartel.rotation = deg_to_rad(3.0)
	_cartel_visible = true

	# El indicador entra en el MISMO frame que el cartel.
	if is_instance_valid(_indicador):
		Juice.centrar_pivote(_indicador)
		Juice.pop(_indicador, 0.2, 0.4)

	var entrada := create_tween()
	entrada.set_parallel(true)
	entrada.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_property(_cartel, "scale", Vector2.ONE, 0.55)
	entrada.tween_property(_cartel, "rotation", 0.0, 0.55)
	entrada.tween_property(_cartel, "modulate:a", 1.0, 0.3)
	await entrada.finished

	if not _cartel_visible or not is_instance_valid(_boton_cartel):
		return
	Juice.centrar_pivote(_boton_cartel)
	_latido_cartel = create_tween().set_loops()
	_latido_cartel.set_trans(Tween.TRANS_SINE)
	_latido_cartel.tween_property(_boton_cartel, "scale", Vector2.ONE * 1.06, 0.45)
	_latido_cartel.tween_property(_boton_cartel, "scale", Vector2.ONE, 0.45)

	await get_tree().create_timer(duracion_cartel).timeout
	_cerrar_cartel()


# Idempotente a proposito: lo pueden cerrar el temporizador, la T del
# jugador o el fin del dia, y los tres caminos pueden cruzarse.
func _cerrar_cartel(duracion: float = 0.4) -> void:
	if not _cartel_visible:
		return
	_cartel_visible = false

	if _latido_cartel and _latido_cartel.is_valid():
		_latido_cartel.kill()
	if not is_instance_valid(_cartel):
		return

	var salida := create_tween()
	salida.set_parallel(true)
	salida.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	salida.tween_property(_cartel, "scale", Vector2(0.85, 0.85), duracion)
	salida.tween_property(_cartel, "modulate:a", 0.0, duracion)
	await salida.finished

	if is_instance_valid(_cartel):
		_cartel.visible = false
