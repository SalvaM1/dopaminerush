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
# 8 segundos, no 3: el vape se desbloquea junto con la 3ra app, y antes
# el cartel salia encima del de la oferta. Este respiro le da al jugador
# tiempo de abrir la app nueva y mirarla un poco antes de que el juego le
# ofrezca otra cosa.
const DEMORA_AVISO_VAPE: float = 8.0
const DURACION_AVISO_VAPE: float = 5.0   # cuanto se queda si no lo usas

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

# ---- EL CELULAR (Mercado Libre) ----
# Mismo sistema que el vape: un Marker3D y un tween de camara. Pero con
# UNA DIFERENCIA CRUCIAL: aca el drenaje NO se congela. Estas perdiendo
# tiempo en una gestion administrativa mientras todo lo demas se cae, y
# esa frustracion es exactamente el punto de la app.
#
# El telefono es EL OTRO OBJETO QUE ROBA TU ATENCION. Que tengas que
# soltar el mouse y mirar el celular para poder seguir comprando en la
# compu es, literalmente, lo que el juego retrata.
# NO ES UN INTERRUPTOR, ES UNA SECUENCIA. Apretas C una vez y el juego
# hace todo: gira la camara, te acerca el telefono a la mano, te da
# TELEFONO_LECTURA segundos para leer, y vuelve solo. Antes habia que
# apretar C de nuevo para volver, y el jugador no tenia forma de saberlo:
# se quedaba mirando el telefono sin entender como salir.
# LOS TRES SUMAN 3.0 SEGUNDOS EXACTOS. Si cambias uno, compensa otro.
# La camara y el telefono se mueven AL MISMO TIEMPO, no uno despues del
# otro: en la vida real girás la cabeza y estirás la mano a la vez. Eso
# ademas es lo que hace que entre todo en tres segundos sin que ninguna
# parte se sienta apurada.
const TELEFONO_IDA: float = 0.55       # girar y agarrar el telefono
const TELEFONO_LECTURA: float = 1.95   # el telefono quieto frente a vos
const TELEFONO_VUELTA: float = 0.5     # dejarlo y volver a la pantalla

# Mientras mirás el codigo el drenaje corre al 60%. No se congela como
# con el vape -el tramite tiene que doler- pero perder la partida por
# una animacion que no podes cortar seria injusto, no tenso.
const TELEFONO_ALIVIO: float = 0.6
const TELEFONO_SUBE: float = 0.35      # el temblor de aviso sobre la mesa
const TELEFONO_ALTURA: float = 0.06

# Donde queda el telefono respecto de la camara cuando lo levantas.
const TELEFONO_EN_MANO := Vector3(0.045, -0.035, -0.26)

# El telefono NO avisa una sola vez: insiste cada TELEFONO_REPIQUE
# segundos hasta que lo mirás. Un unico aviso se pierde entre seis
# ventanas abiertas, y quedarte sin saber que tenes un codigo esperando
# convierte el tramite en una trampa en vez de una molestia.
const TELEFONO_REPIQUE: float = 6.0

# ---- LA PANTALLA ----
# No se prende de golpe: despega con un pico de brillo y se asienta, que
# es lo que hace cualquier celular al despertarse. Y la luz REAL que tira
# sobre el escritorio es lo que hace que lo notes sin estar mirandolo:
# en una habitacion a oscuras, un charco de luz nuevo a tu izquierda se
# ve aunque tengas los ojos clavados en el monitor.
const TELEFONO_LUZ: float = 1.25          # brillo estable
const TELEFONO_LUZ_PICO: float = 2.1      # el golpe del encendido
const TELEFONO_EMISION: float = 2.4       # cuanto "quema" la pantalla
const TELEFONO_FUNDIDO: float = 0.16

# La pantalla apagada es un vidrio negro; encendida, un blanco calido.
# Blanco y no amarillo: un celular mostrando una app se ve blanco, el
# amarillo de Mercado Libre lo pone el texto de la marca.
const PANTALLA_APAGADA := Color(0.0196078, 0.0196078, 0.0313726, 1)
const PANTALLA_ENCENDIDA := Color(0.98, 0.95, 0.86, 1)

# Se usa el primero que exista, asi da igual en que formato lo guarden.
const SONIDOS_TELEFONO := [
	"res://assets/audio/ambiente/celular.ogg",
	"res://assets/audio/ambiente/celular.wav",
]

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

# --- explorar la habitacion ---
@onready var dialogo: CanvasLayer = $Dialogo
@onready var mochila: Interactuable = $Interactuables/Mochila
@onready var ropa: Interactuable = $Interactuables/Ropa
@onready var cama: Interactuable = $Interactuables/Cama
@onready var cajon: Interactuable = $Interactuables/Cajon
@onready var libreta: Interactuable = $Interactuables/Cajon/Libreta
@onready var interruptor: Interactuable = $Interactuables/Interruptor
@onready var libreta_viewport: SubViewport = $Interactuables/Cajon/Libreta/PaginaViewport
@onready var libreta_pagina: MeshInstance3D = $Interactuables/Cajon/Libreta/Pagina
@onready var libreta_titulo: Label = $Interactuables/Cajon/Libreta/PaginaViewport/Titulo
@onready var libreta_fecha: Label = $Interactuables/Cajon/Libreta/PaginaViewport/Fecha
@onready var libreta_tareas: VBoxContainer = $Interactuables/Cajon/Libreta/PaginaViewport/Tareas

# Vape
@onready var vape: Node3D = $Monitor/Vape
@onready var punto_vape: Marker3D = $Monitor/PuntoVape
@onready var humo: GPUParticles3D = $Monitor/Vape/Humo
@onready var indicador_vape: Control = $UI/IndicadorVape
@onready var contador_vape: Label = $UI/IndicadorVape/Contador
@onready var efecto_vape: Label = get_node_or_null("UI/IndicadorVape/Efecto")
@onready var sonido_vape: AudioStreamPlayer3D = get_node_or_null("Monitor/Vape/Sonido")

@onready var telefono: Node3D = $Monitor/Telefono
@onready var telefono_vibra: Node3D = $Monitor/Telefono/Vibra
@onready var punto_telefono: Marker3D = $Monitor/PuntoTelefono
@onready var telefono_pantalla: MeshInstance3D = $Monitor/Telefono/Vibra/Pantalla
@onready var telefono_luz: OmniLight3D = $Monitor/Telefono/Vibra/Luz
@onready var telefono_viewport: SubViewport = $Monitor/Telefono/PantallaViewport
@onready var telefono_codigo: Label = $Monitor/Telefono/PantallaViewport/CajaCodigo/Codigo
@onready var indicador_celular: Control = $UI/IndicadorCelular
@onready var sonido_telefono: AudioStreamPlayer3D = get_node_or_null("Monitor/Telefono/Vibra/Sonido")

# Opcional: si no existe el nodo, la secuencia funciona igual en silencio.
@onready var sonido_despertador: AudioStreamPlayer3D = get_node_or_null("Despertador/Sonido")

var _desperto: bool = false
var _sentado: bool = false
var _puede_levantarse: bool = false

# OJO: _puede_levantarse NO sirve para saber si ya paso el colapso. Es
# -hay cartel para pararse de la silla-, y _levantarse() lo apaga apenas
# te paras. Esta es la que dice de verdad que el dia termino y la puerta
# ya lleva a algun lado.
var _puede_salir: bool = false
# Donde estaba la camara RESPECTO DEL CUERPO antes de sentarse.
# Volver a esta transformacion local (y no a la global) es lo que hace
# que al levantarse la camara quede otra vez alineada con el cuerpo,
# sin importar hacia donde se estuviera mirando.
var _transform_local_original: Transform3D
var _ultima_pos_viewport: Vector2 = Vector2.ZERO

var _vapeando: bool = false
var _vape_desbloqueado: bool = false

# DOS COSAS DISTINTAS, a proposito:
#   _vape_desbloqueado  el juego ya decidio dartelo (al desbloquear la 3ra app)
#   _vape_anunciado     YA TE ENTERASTE: salio el cartel
# El indicador [V] mira la segunda. Si mirara la primera, el boton
# aparecia 8 segundos antes que el cartel y podias vapear sin que el
# juego te lo hubiera ofrecido nunca -- que es justo lo contrario de lo
# que la escena quiere contar.
var _vape_anunciado: bool = false
var _aviso_vape: Panel = null
var _zumbido: AudioStreamPlayer = null
var _sin_senal: Control = null
var _snd_apagon: AudioStreamPlayer = null
var _boton_aviso: Panel = null
var _latido_aviso: Tween = null
var _aviso_vape_visible: bool = false
var _cooldown_vape: float = 0.0
var _vape_pos_base: Vector3
var _camara_sentado: Transform3D

# --- explorar la habitacion ---
var _pensamientos: Dictionary = {}
var _dichos: Dictionary = {}          # clave -> cuantas lineas ya dijo
var _cajon_abierto: bool = false
var _cajon_moviendo: bool = false
var _cajon_pos_base: Vector3
var _libreta_base: Transform3D
var _leyendo_libreta: bool = false
var _luz_prendida: bool = true
var _luz_general: OmniLight3D = null
var _energia_luz_base: float = 1.0
var _frente_cajon: Node3D = null
var _tirador_cajon: Node3D = null
var _interactuables: Array = []
var _aviso_libreta: Label = null
var snd_interruptor: AudioStreamPlayer = null

var _telefono_activo: bool = false      # hay un codigo esperando
var _mirando_telefono: bool = false
var _girando_telefono: bool = false
var _telefono_base: Transform3D
var _mat_telefono: StandardMaterial3D = null
var _codigo_visto: bool = false
var _repique: float = 0.0
var _tween_vibrar: Tween = null
var _tween_luz: Tween = null


func _ready() -> void:
	# La textura del monitor es lo que renderiza el SubViewport.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = pantalla_viewport.get_texture()
	pantalla.material_override = material

	apagada.show()
	escritorio.hide()
	cartel_levantarse.hide()

	# La puerta SI se puede tocar desde el principio, pero no se abre: el
	# personaje se miente a si mismo. Esa linea de dos segundos reencuadra
	# toda la apertura del juego, y cuesta un string.
	puerta.activo = true
	puerta.texto_interaccion = "Salir"

	_vape_pos_base = vape.position
	_configurar_humo()
	indicador_vape.hide()
	_crear_aviso_vape()
	_crear_zumbido()
	_crear_sin_senal()
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)

	# Los nodos del mueble viven en la escena visual, pero en tiempo de
	# ejecucion son nodos como cualquier otro y se pueden mover.
	_luz_general = get_node_or_null("HabitacionVisual/Iluminacion/LuzGeneralFria")
	if _luz_general:
		_energia_luz_base = _luz_general.light_energy
	# El frente plano que trae el mueble se esconde: ahora hay un cajon
	# de verdad en su lugar, con laterales y fondo, para que al abrirse
	# se vea que es un cajon y no una tapa que se despega.
	_frente_cajon = get_node_or_null("HabitacionVisual/MesaDeLuz/FrenteCajon")
	_tirador_cajon = get_node_or_null("HabitacionVisual/MesaDeLuz/Tirador")
	if _frente_cajon:
		_frente_cajon.visible = false
	if _tirador_cajon:
		_tirador_cajon.visible = false

	_preparar_exploracion()

	_preparar_telefono()
	GameManager.codigo_pedido.connect(_al_llegar_codigo)
	GameManager.codigo_resuelto.connect(_al_resolver_codigo)

	despertador.usado.connect(_apagar_despertador)
	monitor.usado.connect(_sentarse)
	puerta.usado.connect(_salir_al_parque)
	GameManager.colapso.connect(_al_colapsar)

	_despertar()


func _process(delta: float) -> void:
	if _puede_levantarse and Input.is_action_just_pressed("interactuar"):
		_levantarse()

	_actualizar_vape(delta)
	_actualizar_telefono(delta)


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
	if not _sentado or _puede_levantarse or _vapeando or _mirando_telefono:
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
	_habilitar_exploracion(false)
	GameManager.iniciar_sesion_pc()


# ============================================================
#  Colapso y levantarse
# ============================================================

func _al_colapsar() -> void:
	# Si la partida termina en plena animacion del celular, el alivio de
	# drenaje quedaria puesto para siempre.
	GameManager.mult_drenaje_celular = 1.0
	_telefono_activo = false
	_encender_telefono(false, true)

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
	_habilitar_exploracion(true)
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
	_puede_salir = true


func _salir_al_parque() -> void:
	# Antes del colapso la puerta no lleva a ningun lado.
	if not _puede_salir:
		_decir("puerta_antes")
		return

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
	if not _sentado or _puede_levantarse or not _vape_anunciado or _mirando_telefono:
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

	# El cartel esta en el centro de la pantalla y tapa justo la animacion
	# del vape, que es lo que el cartel vino a anunciar. Se va rapido y
	# sin await: se desvanece mientras la camara ya esta girando.
	_cerrar_aviso_vape(0.22)

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


# ============================================================
#  Explorar la habitacion
# ============================================================
#
# Todo esto pasa ANTES de sentarse a la computadora, cuando el drenaje
# todavia no arranco. Explorar es gratis y TIENE que serlo: si mirar la
# mochila costara dopamina, el jugador aprenderia a no mirar nada, y la
# habitacion volveria a ser un pasillo hacia el monitor.
#
# Y POR LA MISMA RAZON NADA DE ACA DA NADA. Ni dopamina, ni logros, ni
# desbloqueos. Si explorar rindiera, la habitacion competiria con las
# apps y el argumento del juego se daria vuelta: el mundo real tiene que
# ser aburrido y aun asi valer la pena. En el momento en que regar la
# planta sume 5 de dopamina, deja de significar lo que significa.
#
# Lo unico que se lleva el jugador es haber entendido a quien esta
# jugando. Eso no se cobra: se cobra solo, en el parque del final.

const RUTA_PENSAMIENTOS := "res://escenas/01_habitacion/pensamientos.json"

# El click del interruptor. Se usa el primero que exista.
const SONIDOS_INTERRUPTOR := [
	"res://assets/audio/ui/interruptor.wav",
	"res://assets/audio/ui/interruptor.ogg",
	"res://assets/audio/ui/softclick.wav",
]

# Cuanto se abre el cajon, y en que eje
const CAJON_ABRE: float = 0.42
const CAJON_DURACION: float = 0.5

# El primer plano de la libreta, mismo sistema que el celular
const LIBRETA_ACERCAR: float = 0.55
const LIBRETA_EN_MANO := Vector3(0.0, -0.06, -0.42)


func _preparar_exploracion() -> void:
	_cargar_pensamientos()
	_interactuables = [mochila, ropa, cama, cajon, libreta, interruptor]

	# El click del interruptor. Se crea por codigo para no tener que
	# tocar la escena: si falta el archivo, suena el silencio.
	snd_interruptor = AudioStreamPlayer.new()
	snd_interruptor.bus = "UI"
	snd_interruptor.volume_db = -6.0
	add_child(snd_interruptor)
	for ruta in SONIDOS_INTERRUPTOR:
		if ResourceLoader.exists(ruta):
			snd_interruptor.stream = load(ruta)
			break

	cajon.usado.connect(_al_usar_cajon)
	libreta.usado.connect(_al_leer_libreta)
	mochila.usado.connect(_decir.bind("mochila"))
	ropa.usado.connect(_decir.bind("ropa"))
	cama.usado.connect(_decir.bind("cama"))
	interruptor.usado.connect(_al_usar_interruptor)

	_llenar_libreta()

	_cajon_pos_base = cajon.position
	_libreta_base = libreta.transform
	libreta.visible = false
	libreta.activo = false

	# El material de la pagina se arma por codigo, igual que el del
	# telefono y el del monitor.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = libreta_viewport.get_texture()
	libreta_pagina.material_override = mat


# ------------------------------------------------------------
#  Los pensamientos
# ------------------------------------------------------------

func _cargar_pensamientos() -> void:
	var datos = null
	var recurso = load(RUTA_PENSAMIENTOS)
	if recurso is JSON:
		datos = recurso.data
	elif FileAccess.file_exists(RUTA_PENSAMIENTOS):
		var f := FileAccess.open(RUTA_PENSAMIENTOS, FileAccess.READ)
		datos = JSON.parse_string(f.get_as_text())
		f.close()

	if datos is Dictionary:
		_pensamientos = datos
	else:
		push_warning("[Habitacion] no se pudieron cargar " + RUTA_PENSAMIENTOS)


# Dice el pensamiento que corresponde a ese objeto. Si la clave tiene
# varias lineas, avanza una por vez y se queda en la ultima: insistir
# sobre el mismo objeto dice algo nuevo en lugar de repetir, que es lo
# que hace que valga la pena volver a mirar.
func _decir(clave: String) -> void:
	if dialogo.esta_abierto():
		return

	var entrada = _pensamientos.get(clave, "")
	var linea := ""

	if entrada is Array:
		if entrada.is_empty():
			return
		var i: int = _dichos.get(clave, 0)
		linea = str(entrada[i])
		_dichos[clave] = min(i + 1, entrada.size() - 1)
	else:
		linea = str(entrada)

	if linea == "":
		return

	dialogo.mostrar(linea, jugador)


# ------------------------------------------------------------
#  El cajon y la libreta
# ------------------------------------------------------------

# Un solo tween: la libreta es HIJA del cajon, asi que sale con el. Antes
# eran dos animaciones en paralelo que podian desfasarse.
func _al_usar_cajon() -> void:
	if _cajon_moviendo or _cajon_abierto:
		return

	_cajon_abierto = true
	_cajon_moviendo = true

	# El cajon se abre UNA vez y listo: deja de ofrecerse para siempre.
	# Lo que importa de ahi en mas es la libreta, no el mueble.
	cajon.activo = false

	libreta.visible = true

	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cajon, "position:z", _cajon_pos_base.z + CAJON_ABRE, CAJON_DURACION)
	await t.finished

	_cajon_moviendo = false
	libreta.activo = true
	_decir("cajon_abierto")


# La libreta sube a la mano, como el celular. Es la unica forma de que
# una lista de seis renglones se lea de verdad: a la distancia del cajon
# no se entiende nada, y ese papel es el centro de toda la habitacion.
func _al_leer_libreta() -> void:
	if _leyendo_libreta or _cajon_moviendo:
		return
	_leyendo_libreta = true

	# Tambien se le frena la mirada: si gira la cabeza mientras la libreta
	# vuela hacia el, la pose quedaria calculada para otro lado. De paso
	# desaparecen el cartel y el punto de mira, que sobre la libreta a
	# diez centimetros quedaban ridiculos.
	jugador.puede_mover = false
	jugador.puede_interactuar = false
	jugador.puede_mirar = false

	var camara: Camera3D = jugador.camara
	var destino := camara.global_transform
	var pos := destino.origin + destino.basis * LIBRETA_EN_MANO
	var hacia := (pos - destino.origin).normalized()
	var pose := Transform3D(Basis.looking_at(hacia, destino.basis.y), pos)

	var t1 := create_tween()
	t1.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t1.tween_property(libreta, "global_transform", pose, LIBRETA_ACERCAR)
	await t1.finished

	# Sin reloj: la lee el tiempo que quiera. Es lo unico del juego que
	# no te apura. Pero hay que decirle COMO sale, o se queda mirando la
	# lista sin saber que hacer -- el mismo error que tenia el celular.
	_mostrar_aviso_libreta(true)
	await _esperar_tecla()
	_mostrar_aviso_libreta(false)

	# Vuelve a su lugar DENTRO del cajon. Como el cajon es el padre, el
	# transform local no cambio aunque el mueble se haya movido.
	var vuelta := _libreta_base

	var t2 := create_tween()
	t2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(libreta, "transform", vuelta, LIBRETA_ACERCAR)
	await t2.finished

	jugador.puede_mover = true
	jugador.puede_interactuar = true
	jugador.puede_mirar = true
	_leyendo_libreta = false

	_decir("libreta_cerrar")


func _mostrar_aviso_libreta(visible_: bool) -> void:
	if _aviso_libreta == null:
		_aviso_libreta = Label.new()
		_aviso_libreta.text = "[E] Guardar la libreta"
		_aviso_libreta.add_theme_font_size_override("font_size", 18)
		_aviso_libreta.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		_aviso_libreta.add_theme_color_override("font_outline_color", Color.BLACK)
		_aviso_libreta.add_theme_constant_override("outline_size", 7)
		_aviso_libreta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aviso_libreta.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_aviso_libreta.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_aviso_libreta.offset_top = -96.0
		_aviso_libreta.offset_bottom = -70.0
		_aviso_libreta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		$UI.add_child(_aviso_libreta)

	_aviso_libreta.visible = visible_


# Espera a que suelte y vuelva a apretar E, para que la misma pulsacion
# que abrio la libreta no la cierre en el mismo frame.
func _esperar_tecla() -> void:
	await get_tree().create_timer(0.35).timeout
	while not Input.is_action_just_pressed("interactuar"):
		await get_tree().process_frame


# Arma la lista a partir del JSON. Las casillas se dibujan con nodos y no
# con simbolos tipo checkbox porque esos glifos no estan en todas las
# fuentes y saldrian como cuadraditos vacios.
func _llenar_libreta() -> void:
	var datos = _pensamientos.get("libreta", {})
	if not (datos is Dictionary):
		return

	libreta_titulo.text = str(datos.get("titulo", ""))
	libreta_fecha.text = str(datos.get("fecha", ""))

	for hijo in libreta_tareas.get_children():
		libreta_tareas.remove_child(hijo)
		hijo.queue_free()

	for t in datos.get("tareas", []):
		libreta_tareas.add_child(_fila_tarea(
			str(t.get("texto", "")), bool(t.get("hecha", false))
		))


func _fila_tarea(texto: String, hecha: bool) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)

	var casilla := Panel.new()
	casilla.custom_minimum_size = Vector2(26, 26)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0)
	estilo.border_color = Color(0.29, 0.33, 0.44)
	estilo.set_border_width_all(2)
	casilla.add_theme_stylebox_override("panel", estilo)
	fila.add_child(casilla)

	if hecha:
		var tilde := Label.new()
		tilde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tilde.text = "X"
		tilde.add_theme_font_size_override("font_size", 22)
		tilde.add_theme_color_override("font_color", Color(0.29, 0.33, 0.44))
		tilde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tilde.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		casilla.add_child(tilde)

	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(250, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("normal_font_size", 21)

	if hecha:
		l.add_theme_color_override("default_color", Color(0.55, 0.57, 0.62))
		l.text = "[s]%s[/s]" % texto
	else:
		l.add_theme_color_override("default_color", Color(0.18, 0.21, 0.31))
		l.text = texto

	fila.add_child(l)
	return fila


# Sentado en la computadora no se explora: el cajon le queda dentro de
# los 75 grados que puede girar la cabeza, y abrirlo ahi dispararia un
# pensamiento encima del monitor con el drenaje corriendo. La habitacion
# es para antes y para despues, nunca durante.
func _habilitar_exploracion(puede: bool) -> void:
	for i in _interactuables:
		if is_instance_valid(i):
			i.activo = puede

	# La libreta sigue su propia regla: solo si el cajon esta abierto.
	if is_instance_valid(libreta):
		libreta.activo = puede and _cajon_abierto


# ------------------------------------------------------------
#  El interruptor
# ------------------------------------------------------------
#
# No hace absolutamente nada mecanico. Pero apagar el plafon y quedarte
# con el monitor como unica fuente de luz es lo que hace cualquiera a
# las tres de la mañana, y cambia la habitacion entera.

func _al_usar_interruptor() -> void:
	_luz_prendida = not _luz_prendida

	interruptor.texto_interaccion = "Apagar la luz" if _luz_prendida else "Prender la luz"

	# La tecla bascula, como una de verdad
	var tecla := interruptor.get_node_or_null("Tecla")
	if tecla:
		var t := create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(tecla, "rotation:x",
			deg_to_rad(10.0 if _luz_prendida else -10.0), 0.14)

	if _luz_general:
		var t2 := create_tween()
		t2.set_trans(Tween.TRANS_SINE)
		t2.tween_property(_luz_general, "light_energy",
			_energia_luz_base if _luz_prendida else 0.0, 0.25)

	# Sin pensamiento: prender y apagar una luz no merece un comentario.
	# El click ya dice todo lo que hay que decir.
	Juice.sonar(snd_interruptor, 2.0 if _luz_prendida else 0.0, 0.05)


# ============================================================
#  El celular — el otro objeto que te roba la atencion
# ============================================================

func _preparar_telefono() -> void:
	_telefono_base = telefono.transform

	# La pantalla es un SubViewport, igual que el monitor: adentro hay
	# una interfaz de verdad. Un numero flotando en el aire se ve como un
	# cartel de debug; una pantalla con su barra de estado y su header
	# amarillo se lee como un celular en dos decimas de segundo.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = telefono_viewport.get_texture()
	mat.albedo_color = Color.BLACK     # apagado
	telefono_pantalla.material_override = mat
	_mat_telefono = mat

	_cargar_sonido_telefono()
	indicador_celular.hide()
	_encender_telefono(false, true)


# Si alguien ya le asigno un archivo desde el editor, no lo pisamos.
func _cargar_sonido_telefono() -> void:
	if sonido_telefono == null or sonido_telefono.stream != null:
		return

	for ruta in SONIDOS_TELEFONO:
		if ResourceLoader.exists(ruta):
			sonido_telefono.stream = load(ruta)
			return

	print("[Telefono] falta el sonido de notificacion: ", SONIDOS_TELEFONO[0])


# La llama el GameManager cuando Mercado Libre genera un codigo. Ni la
# app sabe que existe este telefono, ni el telefono sabe que existe la app.
func _al_llegar_codigo(codigo: String) -> void:
	# Separado, que a 3 cm de pantalla se lee muchisimo mejor.
	var espaciado := ""
	for c in codigo:
		espaciado += c + " "
	telefono_codigo.text = espaciado.strip_edges()

	_telefono_activo = true
	_codigo_visto = false
	_repique = TELEFONO_REPIQUE
	_encender_telefono(true)

	# SE ENCIENDE Y SUENA. Sin eso habria que adivinar cuando mirar, y
	# el jugador estaria girando la camara cada dos segundos por las dudas.
	_sonar_telefono(false)

	# Se despega un poco de la mesa: el movimiento se ve de reojo.
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(telefono, "position",
		_telefono_base.origin + Vector3(0, TELEFONO_ALTURA, 0), TELEFONO_SUBE)


func _al_resolver_codigo() -> void:
	_telefono_activo = false
	_codigo_visto = true
	_encender_telefono(false)

	if _tween_vibrar and _tween_vibrar.is_valid():
		_tween_vibrar.kill()
	telefono_vibra.position = Vector3.ZERO

	# Si lo estaba levantando, la secuencia lo devuelve sola.
	if not _mirando_telefono:
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(telefono, "position", _telefono_base.origin, TELEFONO_SUBE)


func _encender_telefono(prendido: bool, instantaneo: bool = false) -> void:
	if _tween_luz and _tween_luz.is_valid():
		_tween_luz.kill()

	if instantaneo:
		_brillo_pantalla(TELEFONO_LUZ if prendido else 0.0)
		return

	_tween_luz = create_tween()
	if prendido:
		# Pico y asentamiento: el gesto exacto de una pantalla que
		# despierta. Prenderla de un salto a su brillo final se lee como
		# "alguien subio un valor", no como un telefono.
		_tween_luz.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween_luz.tween_method(_brillo_pantalla, 0.0, TELEFONO_LUZ_PICO, TELEFONO_FUNDIDO)
		_tween_luz.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_luz.tween_method(_brillo_pantalla, TELEFONO_LUZ_PICO, TELEFONO_LUZ, 0.28)
	else:
		_tween_luz.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween_luz.tween_method(_brillo_pantalla, telefono_luz.light_energy, 0.0, 0.3)


# Un solo numero mueve la luz que sale y el brillo de la pantalla, porque
# en una pantalla real son el mismo fenomeno. La imagen del viewport se
# atenua multiplicandola por un gris: en negro la pantalla esta apagada.
func _brillo_pantalla(energia: float) -> void:
	telefono_luz.light_energy = energia
	if _mat_telefono:
		var f: float = clamp(energia / TELEFONO_LUZ, 0.0, 1.0)
		_mat_telefono.albedo_color = Color(f, f, f, 1.0)


# En cada vibracion la pantalla da un golpe de brillo, como cuando entra
# una notificacion nueva sobre un telefono que ya estaba despierto.
func _pulso_pantalla() -> void:
	if not _telefono_activo:
		return
	if _tween_luz and _tween_luz.is_valid():
		_tween_luz.kill()

	_tween_luz = create_tween()
	_tween_luz.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_luz.tween_method(_brillo_pantalla, telefono_luz.light_energy, TELEFONO_LUZ_PICO, 0.07)
	_tween_luz.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_luz.tween_method(_brillo_pantalla, TELEFONO_LUZ_PICO, TELEFONO_LUZ, 0.3)


func _actualizar_telefono(delta: float) -> void:
	if not _sentado or _puede_levantarse or _vapeando:
		indicador_celular.hide()
		return

	# El indicador aparece igual que el del vape: solo cuando sirve.
	indicador_celular.visible = _telefono_activo and not _mirando_telefono

	# Mientras el codigo siga sin leerse, el telefono vuelve a vibrar.
	# Deja de insistir apenas lo mirás: ya cumplio su funcion y seguir
	# sonando pasaria de "te estan reclamando" a ruido molesto.
	if _telefono_activo and not _codigo_visto and not _mirando_telefono:
		_repique -= delta
		if _repique <= 0.0:
			_repique = TELEFONO_REPIQUE
			_sonar_telefono()

	if _mirando_telefono or not _telefono_activo:
		return

	if Input.is_action_just_pressed("mirar_celular"):
		_mirar_telefono()


# Suena y VIBRA. La vibracion es un temblor del propio telefono sobre la
# mesa: se ve por el rabillo del ojo mientras mirás la pantalla, y
# funciona aunque todavia no haya archivo de audio cargado.
func _sonar_telefono(con_pulso: bool = true) -> void:
	if sonido_telefono and sonido_telefono.stream:
		sonido_telefono.play()

	# En el PRIMER aviso no pulsa: ahi la pantalla se esta encendiendo
	# desde cero, que es una animacion mas larga, y el pulso la cortaria.
	if con_pulso:
		_pulso_pantalla()

	if _tween_vibrar and _tween_vibrar.is_valid():
		_tween_vibrar.kill()

	# Se sacude el nodo Vibra y no el telefono entero, porque al telefono
	# ya lo estan animando los tweens que lo levantan y lo acercan.
	_tween_vibrar = create_tween()
	for i in range(3):
		_tween_vibrar.tween_property(telefono_vibra, "position:x", 0.0035, 0.045)
		_tween_vibrar.tween_property(telefono_vibra, "position:x", -0.0035, 0.045)
	_tween_vibrar.tween_property(telefono_vibra, "position:x", 0.0, 0.05)


# ============================================================
#  Mirar el celular: una sola tecla y vuelve solo
# ============================================================
#
# OJO: aca NO se toca GameManager.drenaje_pausado. El vape lo congela
# porque su valor es el descanso; este tramite tiene que doler. Estas
# perdiendo tiempo en una gestion administrativa mientras todo lo demas
# se cae, y esa frustracion es exactamente el punto de la app.

func _mirar_telefono() -> void:
	if _mirando_telefono:
		return
	_mirando_telefono = true
	_codigo_visto = true
	indicador_celular.hide()

	# El drenaje baja al 60% durante toda la secuencia. Son 3 segundos en
	# los que el jugador no puede tocar nada: cobrarselos enteros cuando
	# la app lo obligo a mirar el telefono se siente injusto.
	GameManager.mult_drenaje_celular = TELEFONO_ALIVIO

	var camara: Camera3D = jugador.camara
	var destino := jugador.global_transform.affine_inverse() * punto_telefono.global_transform

	# 1. La camara gira Y el telefono sube a la mano, A LA VEZ.
	# La pose de la mano se calcula desde donde la camara VA A ESTAR
	# (punto_telefono ya es ese transform global), no desde donde esta
	# ahora. Eso es lo que permite solapar los dos movimientos: el vape
	# tiene que esperar porque calcula la boca recien al final.
	var t1 := create_tween()
	t1.set_parallel(true)
	t1.tween_property(camara, "transform", destino, TELEFONO_IDA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# CUBIC + IN_OUT es el perfil de una mano que agarra algo: arranca,
	# acelera y frena. Con EASE_OUT el telefono parecia volar solo.
	t1.tween_property(telefono, "global_transform",
			_pose_en_mano(punto_telefono.global_transform), TELEFONO_IDA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t1.finished

	# 2. Quieto, para leer. Tres digitos no necesitan mas, y ademas ya se
	# venian leyendo durante el ultimo tramo del movimiento.
	await get_tree().create_timer(TELEFONO_LECTURA).timeout

	# 3. Lo deja y vuelve a la pantalla, tambien a la vez. Queda
	# levantado si el codigo todavia no se uso.
	var vuelta := _telefono_base
	if _telefono_activo:
		vuelta.origin += Vector3(0, TELEFONO_ALTURA, 0)

	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(telefono, "transform", vuelta, TELEFONO_VUELTA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(camara, "transform", _camara_sentado, TELEFONO_VUELTA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished

	GameManager.mult_drenaje_celular = 1.0
	_mirando_telefono = false


# El telefono frente a la camara, con la pantalla mirandola. Recibe el
# transform que la camara VA A TENER, no el nodo, asi se puede calcular
# antes de que llegue y mover las dos cosas en paralelo.
# Su +Z es la cara de la pantalla, asi que apuntamos el -Z al reves.
func _pose_en_mano(camara_final: Transform3D) -> Transform3D:
	var pos := camara_final.origin + camara_final.basis * TELEFONO_EN_MANO
	var hacia_afuera := (pos - camara_final.origin).normalized()
	return Transform3D(Basis.looking_at(hacia_afuera, camara_final.basis.y), pos)


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
	# Sin cartel no hay anuncio posible, pero dejar el vape inaccesible
	# para siempre seria peor: se habilita igual.
	if _aviso_vape == null:
		_vape_anunciado = true
		return

	# Le damos tiempo al jugador a abrir la app que acaba de desbloquear
	# y mirarla un poco. Si el cartel del vape sale encima del cartel de
	# oferta, las dos cosas se pisan y no se entiende ninguna.
	await get_tree().create_timer(DEMORA_AVISO_VAPE).timeout
	if not is_instance_valid(_aviso_vape):
		return

	_aviso_vape.visible = true
	_aviso_vape.pivot_offset = _aviso_vape.size * 0.5
	_aviso_vape.scale = Vector2(0.7, 0.7)
	_aviso_vape.rotation = deg_to_rad(-3.0)
	_aviso_vape_visible = true

	# EL BOTON APARECE ACA, en el mismo frame que el cartel. Entra con un
	# pop para que se lea como parte del anuncio y no como algo que ya
	# estaba ahi.
	_vape_anunciado = true
	Juice.centrar_pivote(indicador_vape)
	Juice.pop(indicador_vape, 0.2, 0.4)

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
	_latido_aviso = create_tween().set_loops()
	_latido_aviso.set_trans(Tween.TRANS_SINE)
	_latido_aviso.tween_property(_boton_aviso, "scale", Vector2.ONE * 1.06, 0.45)
	_latido_aviso.tween_property(_boton_aviso, "scale", Vector2.ONE, 0.45)

	await get_tree().create_timer(DURACION_AVISO_VAPE).timeout

	# Si el jugador ya vapeo, esto no hace nada: el cartel se cerro solo.
	_cerrar_aviso_vape()


# Cierra el cartel del vape. Se llama desde dos lados: cuando se le acaba
# el tiempo en pantalla, y cuando el jugador aprieta V. Ese segundo caso
# es el importante: el cartel esta justo en el centro y tapaba la
# animacion del vape, o sea la cosa que el cartel vino a anunciar.
#
# Es idempotente a proposito: los dos caminos pueden dispararse, y el
# segundo tiene que no hacer nada.
func _cerrar_aviso_vape(duracion: float = 0.4) -> void:
	if not _aviso_vape_visible:
		return
	_aviso_vape_visible = false

	if _latido_aviso and _latido_aviso.is_valid():
		_latido_aviso.kill()
	if not is_instance_valid(_aviso_vape):
		return

	# Encoge y se desvanece. Corto cuando lo cierra el jugador, para que
	# no quede flotando por encima del vape subiendo a la boca.
	var salida := create_tween()
	salida.set_parallel(true)
	salida.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	salida.tween_property(_aviso_vape, "scale", Vector2(0.85, 0.85), duracion)
	salida.tween_property(_aviso_vape, "modulate:a", 0.0, duracion)
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
