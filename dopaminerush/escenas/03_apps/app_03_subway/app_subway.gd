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
const DOPAMINA_POR_SEGUNDO: float = 5.5   # con el canal fresco del todo
const QUEMA_POR_SEGUNDO: float = 0.055    # un canal dura ~18 s
const RECUPERA_POR_SEGUNDO: float = 0.022 # y tarda ~45 s en volver
const FRESCURA_MINIMA: float = 0.08       # nunca da CERO, solo casi nada

const MANTENER_PARA_CAMBIAR: float = 0.5  # cuanto hay que sostener
const DURACION_BUFFERING: float = 3.0     # el castigo del zapping

const RUTA_AUDIO := "res://assets/audio/apps/canales/"

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
@onready var etiqueta_canal: Label = $Marco/Video/Etiqueta
@onready var barra_frescura: ProgressBar = $Medidor/Barra
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

var _spinner: Control = null       # la rueda de carga


func _ready() -> void:
	for i in range(CANALES.size()):
		_frescura.append(1.0)

	barra_frescura.show_percentage = false
	barra_frescura.max_value = 100.0

	_crear_spinner()
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

	GameManager.sumar_dopamina(DOPAMINA_POR_SEGUNDO * f * delta, id_app)

	_actualizar_hud(f, delta)


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
	var datos: Dictionary = CANALES[indice]

	etiqueta_canal.text = str(datos["id"]).to_upper()
	titulo_video.text = str(datos["titulo"])

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
	if sonido.playing:
		sonido.stop()


func _terminar_buffering() -> void:
	_buffering = 0.0
	_spinner.visible = false
	video.modulate = Color.WHITE
	etiqueta_canal.show()
	if sonido.stream:
		sonido.play()


func _cargar_sonido(id_canal: String) -> void:
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

	if frescura > 0.6:
		barra_frescura.modulate = Color(0.35, 0.82, 0.45)
	elif frescura > 0.3:
		barra_frescura.modulate = Color(0.95, 0.75, 0.25)
	else:
		barra_frescura.modulate = Color(0.88, 0.32, 0.28)

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
