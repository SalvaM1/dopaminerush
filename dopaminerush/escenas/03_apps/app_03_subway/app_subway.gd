extends AppBase

# ============================================================
#  Subway Slop — el video de fondo
# ============================================================
#
# LA MECANICA: cada canal tiene una barra de FRESCURA que baja mientras
# lo mirás. La dopamina que da es proporcional a esa frescura, asi que
# un canal quemado no da casi nada.
#
# Pero los canales que NO estas mirando se RECUPERAN solos.
#
# Eso convierte la app en un problema de rotacion. No es "apreta de
# nuevo", es "cual de los ocho estara recuperado ahora". Y como el
# cambio es al azar, puede salir uno que ya quemaste.
#
# EL COSTO DEL CAMBIO no es el gesto: es el buffering. Al cambiar hay
# 0.8 segundos de rueda girando en los que no entra nada. Por eso
# spamear el cambio es la peor estrategia posible: cuanto mas cambias,
# menos ves. Igual que hacer zapping de verdad.
#
# ES LA TOLERANCIA HECHA MECANICA: quemas una fuente, deja de darte
# algo, y tenés que dejarla descansar para que vuelva a funcionar.
#
# GESTO: mantener apretado sobre el video. En TikBrainRot mantener
# ACELERA el video; aca lo DESCARTA. El mismo gesto con sentido
# opuesto, para que las dos apps abiertas se peleen en los dedos.

# ---- BALANCEO (provisorio, se ajusta en la fase G) ----
# ESTA APP TIENE QUE SERVIR, PERO NO TANTO. Es la que se mira de reojo
# mientras atendes otras ventanas, asi que si rinde demasiado te conviene
# quedarte aca y el juego entero se cae. Los tres numeros se leen juntos:
#
#   - paga 7/s con el canal fresco y baja hasta 0 en ~30 s
#   - cada canal entero rinde ~105 de dopamina
#   - los otros canales tardan ~91 s en recuperarse, o sea TRES VECES lo
#     que tardas en quemar uno: no alcanza con rotar entre dos, hay que
#     ir recorriendo los ocho y aun asi encontrar alguno a medio cargar
#
# Esa ultima relacion es la que sostiene la mecanica. Si se afloja, la
# app pasa de "cual estara recuperado" a "apreta y segui".
const DOPAMINA_POR_SEGUNDO: float = 7.0   # con el canal fresco del todo
const QUEMA_POR_SEGUNDO: float = 0.0333   # un canal dura ~30 s
const RECUPERA_POR_SEGUNDO: float = 0.011 # y tarda ~91 s en volver

# Un canal quemado del todo deja de dar dopamina: CERO, no "casi nada".
# Que el numero llegue a 0 y el +X deje de aparecer es lo que ensena la
# mecanica sin texto: quedarse en un canal muerto no rinde, hay que rotar.
const FRESCURA_MINIMA: float = 0.0

# ---- COMO SE VE LA DOPAMINA POR SEGUNDO ----
# La dopamina entra de a fracciones en cada frame, asi que no se puede
# mostrar un numero por cobro como en las otras apps. Se junta lo ganado
# durante un segundo y recien ahi sale un +X.
#
# El efecto es que el numero ENCOGE solo a medida que el canal se quema
# (+5, +4, +2, +1) y desaparece cuando llega a cero. Esa caida visible
# es justamente la mecanica de la app.
const CADENCIA_NUMERO: float = 1.0        # cada cuanto sale un +X
const NUMERO_MINIMO: float = 0.5          # abajo de esto no muestra nada

const MANTENER_PARA_CAMBIAR: float = 0.5  # cuanto hay que sostener
const DURACION_BUFFERING: float = 3.0     # el castigo del zapping

const RUTA_AUDIO := "res://assets/audio/apps/canales/"

# Un video por canal, con el nombre del id: subway.ogv, slime.ogv, etc.
# El canal que todavia no tiene archivo sigue andando con su color, asi
# se pueden ir agregando de a uno sin que nada se rompa.
const RUTA_VIDEO := "res://assets/video/subway/"

# ---- LOS CANALES ----
# Cada uno tiene que ser reconocible en dos segundos por su color, porque
# el jugador lo va a ver de reojo mientras atiende otra ventana.
const CANALES := [
	{
		"id": "slime",
		"nombre": "SlimeASMR_oficial",
		"titulo": "3 HORAS de slime satisfactorio 💗",
		"color": Color(0.93, 0.45, 0.72),
	},
	{
		"id": "cuchillo",
		"nombre": "HotKnife",
		"titulo": "CUCHILLO AL ROJO VIVO vs 20 COSAS",
		"color": Color(0.96, 0.44, 0.13),
	},
	{
		"id": "subway",
		"nombre": "GameplayParaVer",
		"titulo": "gameplay sin copyright para tus videos",
		"color": Color(0.22, 0.52, 0.95),
	},
	{
		"id": "mukbang",
		"nombre": "MEGA MUKBANG",
		"titulo": "COMIENDO 40.000 CALORIAS (me sentí mal)",
		"color": Color(0.82, 0.22, 0.18),
	},
	{
		"id": "prensa",
		"nombre": "Prensa Hidráulica",
		"titulo": "APLASTANDO COSAS QUE NO DEBERÍA",
		"color": Color(0.46, 0.48, 0.52),
	},
	{
		"id": "asmr",
		"nombre": "calma.asmr",
		"titulo": "susurros para tu ansiedad ✨ (1 hora)",
		"color": Color(0.58, 0.42, 0.85),
	},
	{
		"id": "jabon",
		"nombre": "SoapCutting",
		"titulo": "cortando jabones caros 🧼",
		"color": Color(0.55, 0.85, 0.82),
	},
	{
		"id": "alfombra",
		"nombre": "DeepClean",
		"titulo": "la alfombra MÁS SUCIA que limpié jamás",
		"color": Color(0.24, 0.66, 0.5),
	},
]

# ---- NODOS ----
@onready var video: ColorRect = $Marco/Video
@onready var marco_video: Control = $Marco/Video/MarcoVideo
@onready var reproductor: VideoStreamPlayer = $Marco/Video/MarcoVideo/Reproductor
@onready var etiqueta_canal: Label = $Marco/Video/Etiqueta
@onready var barra_frescura: ProgressBar = $Medidor/Barra
@onready var tasa: Label = $Medidor/Tasa
@onready var titulo_video: Label = $Marco/BarraInferior/Titulo
@onready var boton: Panel = $Marco/BarraInferior/BotonCambiar
@onready var relleno: ColorRect = $Marco/BarraInferior/BotonCambiar/Relleno
@onready var sonido: AudioStreamPlayer = $Sonido

# ---- ESTADO ----
var _frescura: Array[float] = []
var _actual: int = 0
var _manteniendo: bool = false
var _sostenido: float = 0.0
var _buffering: float = 0.0
var _pulso: float = 0.0

# Lo ganado desde el ultimo +X que salio flotando
var _acumulado: float = 0.0
var _tiempo_numero: float = 0.0

var _spinner: Control = null       # la rueda de carga
var _hay_video: bool = false       # el canal actual tiene archivo?
var _tam_video_previo: Vector2 = Vector2.ZERO
var _tam_marco_previo: Vector2 = Vector2.ZERO


func _ready() -> void:
	for i in range(CANALES.size()):
		_frescura.append(1.0)

	barra_frescura.show_percentage = false
	barra_frescura.max_value = 100.0

	_crear_spinner()
	reproductor.hide()
	boton.gui_input.connect(_input_boton)
	_poner_canal(randi() % CANALES.size(), false)

	await get_tree().process_frame
	if not esta_activa:
		iniciar()


func _process(delta: float) -> void:
	if not esta_activa:
		return

	_recuperar_canales(delta)

	# --- buffering: la rueda gira y no entra nada ---
	if _buffering > 0.0:
		_buffering = max(0.0, _buffering - delta)
		if _buffering <= 0.0:
			_terminar_buffering()
		return

	# --- mantener apretado para descartar ---
	if _manteniendo:
		_sostenido += delta
		_pintar_relleno(clamp(_sostenido / MANTENER_PARA_CAMBIAR, 0.0, 1.0))
		if _sostenido >= MANTENER_PARA_CAMBIAR:
			_cambiar_canal()
			return

	# --- el canal se quema y da dopamina segun lo fresco que este ---
	var f: float = _frescura[_actual]
	_frescura[_actual] = max(FRESCURA_MINIMA, f - QUEMA_POR_SEGUNDO * delta)

	var ganado: float = DOPAMINA_POR_SEGUNDO * f * delta
	GameManager.sumar_dopamina(ganado, id_app)

	_acumular_numero(ganado, delta)
	_actualizar_hud(f, delta)


# Junta lo ganado y lo saca como un +X una vez por segundo. Sin esto el
# jugador ve bajar la barra de entretenimiento pero no tiene forma de
# saber que la app le esta pagando mientras mira.
func _acumular_numero(ganado: float, delta: float) -> void:
	_acumulado += ganado
	_tiempo_numero += delta
	if _tiempo_numero < CADENCIA_NUMERO:
		return

	_tiempo_numero = 0.0

	# Con el canal quemado no sale nada. El silencio es la informacion.
	if _acumulado < NUMERO_MINIMO:
		_acumulado = 0.0
		return

	# Modesto a proposito: esta app paga por estar, no por acertar, asi
	# que el numero acompana en vez de festejar.
	Juice.numero_flotante(
		self,
		"+%d" % round(_acumulado),
		Color(0.45, 0.88, 0.55, 0.85),
		Vector2(size.x - 64.0, size.y - 52.0),
		17
	)
	_acumulado = 0.0


# Los canales que NO se estan mirando vuelven en si. Es lo que obliga
# a rotar en vez de quedarse en uno solo.
func _recuperar_canales(delta: float) -> void:
	for i in range(_frescura.size()):
		if i == _actual and _buffering <= 0.0:
			continue
		_frescura[i] = min(1.0, _frescura[i] + RECUPERA_POR_SEGUNDO * delta)


# ============================================================
#  Cambiar de canal
# ============================================================

func _input_boton(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_manteniendo = evento.pressed and _buffering <= 0.0
		if not _manteniendo:
			_sostenido = 0.0
			_pintar_relleno(0.0)


func _cambiar_canal() -> void:
	_manteniendo = false
	_sostenido = 0.0
	_pintar_relleno(0.0)

	# Al azar, y puede tocar uno ya quemado: no se elige lo que se ve.
	var nuevo := _actual
	if CANALES.size() > 1:
		while nuevo == _actual:
			nuevo = randi() % CANALES.size()

	_poner_canal(nuevo, true)


func _poner_canal(indice: int, con_buffering: bool) -> void:
	_actual = indice

	# El contador del +X arranca limpio: lo poco que daba el canal viejo
	# no se mezcla con lo que empieza a dar el nuevo.
	_acumulado = 0.0
	_tiempo_numero = 0.0

	var datos: Dictionary = CANALES[indice]

	etiqueta_canal.text = str(datos["id"]).to_upper()
	titulo_video.text = str(datos["titulo"])

	_cargar_video(str(datos["id"]))
	_cargar_sonido(str(datos["id"]))

	if con_buffering:
		_empezar_buffering()
	else:
		_terminar_buffering()


# La rueda de YouTube. Nadie necesita que le expliquen que significa,
# y esos 0.8 segundos son el castigo mas reconocible que existe.
func _empezar_buffering() -> void:
	_buffering = DURACION_BUFFERING
	_spinner.visible = true
	video.modulate = Color(0.25, 0.25, 0.25)
	etiqueta_canal.hide()

	# El video se congela de verdad: si siguiera corriendo detras de la
	# rueda, al volver estaria tres segundos mas adelante y el castigo
	# del zapping se perderia.
	reproductor.paused = true

	if sonido.playing:
		sonido.stop()


func _terminar_buffering() -> void:
	_buffering = 0.0
	_spinner.visible = false
	video.modulate = Color.WHITE

	reproductor.paused = false
	etiqueta_canal.visible = not _hay_video

	if sonido.stream:
		sonido.play()


# Busca el video del canal. Si no esta, el canal se ve con su color de
# siempre: los ocho no tienen por que tener archivo al mismo tiempo.
func _cargar_video(id_canal: String) -> void:
	var ruta := RUTA_VIDEO + id_canal + ".ogv"
	_hay_video = ResourceLoader.exists(ruta)
	_tam_video_previo = Vector2.ZERO

	if not _hay_video:
		reproductor.stream = null
		reproductor.hide()
		etiqueta_canal.show()
		return

	reproductor.stream = load(ruta)
	reproductor.show()
	reproductor.play()

	# Con video real, el cartelon con el nombre del canal sobra: estaba
	# ahi justamente porque no habia nada que mirar.
	etiqueta_canal.hide()


# El video se escala a mano para no deformarse: se agranda hasta tapar
# todo el marco y lo que sobra se recorta. Igual que en TikBrainRot.
func _ajustar_video() -> void:
	var textura := reproductor.get_video_texture()
	if textura == null:
		return

	var tam_video: Vector2 = textura.get_size()
	var tam_marco: Vector2 = marco_video.size
	if tam_video.x <= 0.0 or tam_video.y <= 0.0 or tam_marco.x <= 0.0:
		return
	if tam_video == _tam_video_previo and tam_marco == _tam_marco_previo:
		return

	_tam_video_previo = tam_video
	_tam_marco_previo = tam_marco

	var escala: float = max(tam_marco.x / tam_video.x, tam_marco.y / tam_video.y)
	var final: Vector2 = tam_video * escala
	reproductor.size = final
	reproductor.position = (tam_marco - final) * 0.5


func _cargar_sonido(id_canal: String) -> void:
	# Si el canal tiene video, el audio sale del video: poner ademas el
	# .ogg del canal seria el mismo contenido sonando dos veces.
	if _hay_video:
		sonido.stream = null
		return

	var ruta := RUTA_AUDIO + id_canal + ".ogg"
	if ResourceLoader.exists(ruta):
		sonido.stream = load(ruta)
	else:
		sonido.stream = null


# ============================================================
#  Interfaz
# ============================================================

func _actualizar_hud(frescura: float, delta: float) -> void:
	barra_frescura.value = frescura * 100.0

	# EL VIDEO SE APAGA. Es la forma de que el aburrimiento se entienda
	# sin una sola palabra: el rosa chicle del slime termina en gris
	# sucio, y el jugador sabe que eso dejo de darle algo.
	var base: Color = CANALES[_actual]["color"]
	var gris: float = (base.r + base.g + base.b) / 3.0
	var apagado := Color(gris, gris, gris) * 0.45
	video.color = apagado.lerp(base, frescura)
	etiqueta_canal.modulate.a = 0.25 + frescura * 0.6

	# El video tambien se apaga. Es la misma idea que con el color: el
	# aburrimiento se entiende sin una sola palabra porque la imagen se
	# va poniendo gris y oscura a medida que el canal se quema.
	if _hay_video and _buffering <= 0.0:
		var apagon: float = 0.35 + frescura * 0.65
		reproductor.modulate = Color(apagon, apagon, apagon, 1.0)
		_ajustar_video()

	# LA TASA EN VIVO. Es lo que convierte la barra en informacion: sin
	# esto el jugador ve bajar algo, pero no sabe que lo que baja es
	# cuanto le estan pagando por segundo.
	var por_segundo: float = DOPAMINA_POR_SEGUNDO * frescura
	tasa.text = "+%.1f/s" % por_segundo

	var color_estado: Color
	if frescura > 0.6:
		color_estado = Color(0.35, 0.82, 0.45)
	elif frescura > 0.3:
		color_estado = Color(0.95, 0.75, 0.25)
	else:
		color_estado = Color(0.88, 0.32, 0.28)

	barra_frescura.modulate = color_estado

	# Cuando se agota, el numero se apaga en vez de quedar en rojo
	# gritando: un canal muerto no tiene que pedir nada, tiene que
	# dejar de existir visualmente.
	if por_segundo < 0.05:
		tasa.text = "AGOTADO"
		tasa.add_theme_color_override("font_color", Color(0.45, 0.47, 0.52))
	else:
		tasa.add_theme_color_override("font_color", color_estado)

	# Cuando el canal esta quemado, el boton late pidiendo que lo aprietes
	if frescura < 0.35:
		_pulso += delta * 4.5
		var brillo: float = 1.0 + sin(_pulso) * 0.25
		boton.modulate = Color(brillo, brillo, brillo)
	else:
		_pulso = 0.0
		boton.modulate = Color.WHITE


func _pintar_relleno(progreso: float) -> void:
	relleno.size.x = boton.size.x * progreso
	relleno.visible = progreso > 0.001


func _crear_spinner() -> void:
	_spinner = Anillo.new()
	_spinner.set_anchors_preset(Control.PRESET_CENTER)
	_spinner.offset_left = -22.0
	_spinner.offset_right = 22.0
	_spinner.offset_top = -22.0
	_spinner.offset_bottom = 22.0
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner.visible = false
	video.add_child(_spinner)


# ============================================================
#  La rueda de carga
# ============================================================
#
# El arco que gira, igual al de YouTube. Nadie necesita que le expliquen
# que significa.

class Anillo extends Control:
	var _angulo: float = 0.0

	func _process(delta: float) -> void:
		if visible:
			_angulo += delta * 5.0
			queue_redraw()

	func _draw() -> void:
		var centro := size * 0.5
		var radio: float = min(size.x, size.y) * 0.5 - 3.0
		draw_arc(centro, radio, _angulo, _angulo + TAU * 0.72, 40,
			Color(1, 1, 1, 0.95), 4.0, true)
