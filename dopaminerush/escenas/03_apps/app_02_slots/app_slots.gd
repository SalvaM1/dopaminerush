extends AppBase

# ============================================================
#  Family Savings™ — tragamonedas
# ============================================================
#
#   1. LA TIRADA DA LA DOPAMINA, NO EL RESULTADO.
#      Se arrastra la perilla hasta abajo del todo y la dopamina entra en
#      ese momento. Lo que salga en los rodillos casi no cambia nada.
#      (En las tragamonedas reales el pico es la anticipacion, no el premio.)
#
#   2. EL GIRO ES EL COOLDOWN.
#      Los rodillos frenan escalonados durante DURACION_GIRO y no se puede
#      volver a tirar hasta entonces. La animacion DURA lo que dura la
#      espera, asi no se siente artificial. Ese tiempo muerto es lo que
#      empuja al jugador a irse a otra app y volver.
#
#   3. EL PAYWALL.
#      Los creditos alcanzan para unas pocas tiradas. Cuando se acaban hay
#      que "comprarlos": tres pantallas y varios clicks, gratis, por nada.
#
#   4. EL DINERO ES UN CHISTE. Solo baja.
#
# ------------------------------------------------------------
#  SOBRE EL EXCESO DE JUICE EN ESTA APP
# ------------------------------------------------------------
# El resto del juego sigue la regla de "ninguna app puede ser demasiado
# divertida". Esta es la excepcion, por el mismo motivo que Lingofy: una
# tragamonedas real esta disenada por ingenieros para que tirar de la
# palanca se sienta increible, y retratar eso con fidelidad ES la critica.
#
# LA REGLA QUE SI SE RESPETA: que se sienta increible y este COMPLETAMENTE
# VACIA al mismo tiempo. La plata solo baja, el jackpot devuelve 12 sobre
# 25 de costo. Cuanto mejor se sienta, mas fuerte pega esa cuenta.

# ---- BALANCEO (provisorio, se ajusta en la fase G) ----
const DURACION_GIRO: float = 5.0
const PARADAS := [2.6, 3.6, 4.6]        # cuando frena cada rodillo

const COSTO_TIRADA: int = 25
const PREMIO_CHICO: int = 3
const PREMIO_JACKPOT: int = 12
const TIRADAS_MIN: int = 3
const TIRADAS_MAX: int = 7

const PROB_JACKPOT: float = 0.10        # tres iguales
const PROB_CASI: float = 0.35           # dos iguales y el tercero no
const MULT_JACKPOT: float = 3.0

const CLICKS_CONFIRMACION: int = 3
const DOPAMINA_POR_CLICK_PAYWALL: float = 0
const MARGEN_PAYWALL: float = 24.0      # cuanto respeta los bordes al reubicarse
const ALTO_TEXTO_PAYWALL: float = 200.0 # donde termina el texto de la tarjeta

# ---- LA PALANCA ----
# El arrastre es POSICIONAL y DIRECTO: la perilla va exactamente donde
# esta el mouse, sin inercia ni resistencia. Se probo con peso (la perilla
# quedandose atras y poniendose pesada al final) y se sentia pastosa:
# una palanca tiene que ir donde la llevas.
#
# RECORRIDO_MINIMO es lo que evita el tiron fantasma. Antes alcanzaba con
# que la perilla estuviera abajo para disparar, asi que cualquier cosa que
# la dejara ahi -una medida de riel mal calculada en el primer frame, un
# agarre cerca del fondo, un salto de framerate- cobraba la tirada sin que
# el jugador hubiera arrastrado nada. Ahora hay que recorrer de verdad.
const MARGEN_AGARRE: float = 48.0       # cuanto mas alla de la perilla se puede agarrar
const TOLERANCIA_FONDO: float = 6.0     # margen para considerar que llego abajo
const RECORRIDO_MINIMO: float = 0.55    # cuanto del riel hay que bajar, como minimo

# Cuanto tarda la perilla en volver arriba. Lenta a proposito: subiendo
# rapido el gesto terminaba antes de que el ojo lo registrara, y la
# dopamina parecia aparecer sola. Viendola subir, el tiron se lee entero.
# CUBIC y no BACK: con rebote la perilla se despegaba del riel por arriba.
const RETORNO_PALANCA: float = 0.9

# ---- LOS RODILLOS ----
# Giran de verdad: una tira de simbolos que se desplaza y da la vuelta.
# Antes eran tres Labels cambiando de texto, y eso se lee como texto
# parpadeando, no como un rodillo.
const ALTO_SIMBOLO: float = 80.0
const SIMBOLOS_TIRA: int = 6            # cuantos hay en la tira de cada rodillo
const VELOCIDAD_GIRO: float = 1900.0    # pixeles por segundo a tope
const ACELERACION: float = 5200.0
const DURACION_FRENADA: float = 0.42    # de velocidad plena a casi quieto
const DURACION_ATERRIZAJE: float = 0.34 # el rebote final
const ALPHA_BORRON: float = 0.45        # transparencia a maxima velocidad

# EL CASI-PREMIO. Cuando los dos primeros coinciden, el tercero NO frena
# normal: se arrastra simbolo por simbolo durante este tiempo extra. Es
# el momento mas potente de toda la maquina, y es exactamente lo que
# hacen las maquinas reales para estirar la anticipacion.
const DURACION_SUSPENSO: float = 1.6
const PASO_SUSPENSO: float = 0.26       # cuanto tarda cada simbolo en el arrastre

# ---- MARQUESINA ----
# ---- MODO ATRACCION ----
# Una maquina de casino nunca se queda quieta. Si pasan estos segundos
# sin que nadie tire, hace un floreo para llamar la atencion. Es lo que
# hacen las de verdad cuando no hay nadie sentado.
const ESPERA_ATRACCION: float = 7.0

# Cada simbolo con su color. Los emoji ya vienen coloreados por la
# fuente, asi que esto se nota sobre todo en el 7, que es texto comun:
# rojo, como en cualquier maquina.
const COLORES_SIMBOLO := [
	Color(0.95, 0.35, 0.42),   # cereza
	Color(1.00, 0.80, 0.30),   # campana
	Color(1.00, 0.88, 0.40),   # estrella
	Color(0.95, 0.22, 0.25),   # el 7
	Color(0.55, 0.88, 1.00),   # diamante
	Color(1.00, 0.92, 0.45),   # limon
]

const BOMBITAS: int = 16
const VELOCIDAD_LUCES: float = 7.0

const SIMBOLOS := ["🍒", "🔔", "⭐", "7", "💎", "🍋"]

# Los sonidos los consigue otra persona. Mientras no esten, la app anda
# en silencio: cada reproductor se carga solo si el archivo aparece.
# Solo el nombre: la extension la busca sola, asi da igual si el archivo
# que consiguen viene en .mp3, .ogg o .wav.
const CARPETA_SONIDOS := "res://assets/audio/apps/slots/"
const EXTENSIONES := [".mp3", ".ogg", ".wav"]
const SONIDOS := {
	"palanca":      "palanca",
	"palanca_sube": "palanca_sube",
	"girando":      "girando",
	"rodillo_para": "rodillo_para",
	"casi":         "casi",
	"jackpot":      "jackpot",
	"moneda":       "moneda",
	"luz":          "luz",
}

# EL PAGO MONEDA POR MONEDA. Las maquinas reales no te acreditan el
# premio de una: te lo cuentan. Cada paso es un sonido, un salto del
# display y una moneda. Doce pasos de 0.1 s son 1.2 segundos en los que
# no pasa NADA util y el jugador no puede dejar de mirar -- que es
# exactamente el punto.
const PASOS_PAGO: int = 12
const PASO_PAGO: float = 0.1

const ORO := Color(1.0, 0.83, 0.29)
const ROJO := Color(0.89, 0.25, 0.25)

# ---- NODOS ----
@onready var maquina: Panel = $Maquina
@onready var marquesina: Panel = $Maquina/Marquesina
@onready var bombitas_padre: Control = $Maquina/Marquesina/Bombitas
@onready var titulo: Label = $Maquina/Marquesina/Titulo
@onready var visor: Panel = $Maquina/Visor
@onready var linea_pago: ColorRect = $Maquina/Visor/LineaPago
@onready var destello: ColorRect = $Maquina/Visor/Destello
@onready var chispas: GPUParticles2D = $Maquina/Visor/Chispas
@onready var chispas2: GPUParticles2D = $Maquina/Visor/Chispas2
@onready var cartel_premio: Label = $Maquina/CartelPremio
@onready var rodillos := [
	$Maquina/Visor/Rodillo0,
	$Maquina/Visor/Rodillo1,
	$Maquina/Visor/Rodillo2,
]

@onready var palanca: Control = $Palanca
@onready var riel: Panel = $Palanca/Riel
@onready var perilla: Panel = $Palanca/Perilla
@onready var vastago: Panel = $Palanca/Vastago
@onready var etiqueta_palanca: Label = $Palanca/Etiqueta

@onready var creditos_label: Label = $Maquina/PanelInferior/DisplayCreditos/Creditos
@onready var mensaje: Label = $Maquina/PanelInferior/Mensaje
@onready var indicador: Label = $Maquina/Indicador

@onready var paywall: Panel = $Paywall
@onready var tarjeta_paywall: Panel = $Paywall/Tarjeta
@onready var texto_paywall: Label = $Paywall/Tarjeta/TextoPaywall
@onready var reloj_paywall: Label = $Paywall/Tarjeta/Reloj
@onready var boton_paywall: Button = $Paywall/BotonPaywall
@onready var monedas: GPUParticles2D = $Paywall/Monedas

@onready var snd_palanca: AudioStreamPlayer = get_node_or_null("Sonidos/Palanca")
@onready var snd_palanca_sube: AudioStreamPlayer = get_node_or_null("Sonidos/PalancaSube")
@onready var snd_girando: AudioStreamPlayer = get_node_or_null("Sonidos/Girando")
@onready var snd_rodillo: AudioStreamPlayer = get_node_or_null("Sonidos/RodilloPara")
@onready var snd_casi: AudioStreamPlayer = get_node_or_null("Sonidos/Casi")
@onready var snd_jackpot: AudioStreamPlayer = get_node_or_null("Sonidos/Jackpot")
@onready var snd_moneda: AudioStreamPlayer = get_node_or_null("Sonidos/Moneda")
@onready var snd_luz: AudioStreamPlayer = get_node_or_null("Sonidos/Luz")

# ---- ESTADO ----
enum Fase { QUIETO, GIRANDO, SUSPENSO }

var _creditos: int = 0
var _fase: int = Fase.QUIETO
var _tiempo_giro: float = 0.0
var _resultado := [0, 0, 0]

# Por rodillo
var _tiras: Array = []              # el Control que se desplaza
var _etiquetas: Array = []          # Array[Array[Label]]
var _simbolos_tira: Array = []      # Array[Array[int]]
var _offset: Array = [0.0, 0.0, 0.0]
var _velocidad: Array = [0.0, 0.0, 0.0]
var _estado_rodillo: Array = [0, 0, 0]   # 0 quieto, 1 girando, 2 frenando, 3 aterrizando, 4 parado

var _suspenso_activo: bool = false
var _suspenso_reloj: float = 0.0
var _suspenso_paso: float = 0.0

var _arrastrando: bool = false
var _offset_agarre: float = 0.0
var _y_agarre: float = 0.0
var _y_arriba: float = 0.0
var _y_abajo: float = 0.0

var _luces: Array = []
var _fase_luces: float = 0.0
var _modo_luces: int = 0            # 0 atraccion, 1 girando, 2 premio

# 0 = jugando, 1 = oferta, 2 = confirmacion, 3 = spam de clicks
var _paso_paywall: int = 0
var _clicks_restantes: int = 0
var _tween_latido: Tween = null
var _tween_indicador: Tween = null
var _reloj_atraccion: float = 0.0
var _parpadeo: float = 0.0
var _y_indicador: float = INF


func _ready() -> void:
	palanca.gui_input.connect(_input_palanca)
	palanca.mouse_entered.connect(_al_entrar_palanca)
	palanca.mouse_exited.connect(_al_salir_palanca)
	boton_paywall.pressed.connect(_click_paywall)

	paywall.hide()
	indicador.modulate.a = 0.0
	destello.color.a = 0.0

	_cargar_sonidos()
	_armar_bombitas()
	_armar_rodillos()

	cartel_premio.hide()
	Juice.configurar_rafaga(chispas, ORO, 30, 320.0)
	Juice.configurar_rafaga(chispas2, Color(1, 1, 1), 24, 420.0)
	Juice.configurar_rafaga(monedas, ORO, 40, 380.0)

	_calcular_recorrido()
	perilla.position.y = _y_arriba

	_recargar_creditos()
	_actualizar_hud(false)
	_palanca_lista(true)

	await get_tree().process_frame

	# El layout recien esta resuelto despues del primer frame: antes de
	# eso el riel y los rodillos pueden medir cualquier cosa.
	_calcular_recorrido()
	perilla.position.y = _y_arriba
	for i in range(3):
		_pintar_tira(i)
		_centrar_tira(i)

	if not esta_activa:
		iniciar()


# El recorrido de la perilla va de punta a punta del riel.
func _calcular_recorrido() -> void:
	_y_arriba = riel.position.y
	_y_abajo = riel.position.y + riel.size.y - perilla.size.y


func _process(delta: float) -> void:
	if not esta_activa:
		return

	_animar_luces(delta)
	_actualizar_vastago()
	_parpadear_display(delta)

	if _fase == Fase.QUIETO:
		_revisar_atraccion(delta)
		return

	_reloj_atraccion = 0.0

	_tiempo_giro += delta

	# Contador del cooldown, en la etiqueta de la palanca
	var restante: float = max(0.0, _duracion_total() - _tiempo_giro)
	etiqueta_palanca.text = "%.1f" % restante

	_actualizar_rodillos(delta)

	# Las dos condiciones: que haya pasado el cooldown de diseno Y que
	# los rodillos hayan frenado de verdad.
	if _tiempo_giro >= DURACION_GIRO and _todos_parados():
		_terminar_giro()


# Con suspenso el giro dura mas: el tercer rodillo se arrastra.
func _duracion_total() -> float:
	return DURACION_GIRO + (DURACION_SUSPENSO if _suspenso_activo else 0.0)


func _todos_parados() -> bool:
	for e in _estado_rodillo:
		if e != 4:
			return false
	return true


# ============================================================
#  Los rodillos
# ============================================================

# Cada rodillo es una tira de SIMBOLOS_TIRA etiquetas apiladas que se
# desplaza hacia abajo. Cuando se corrio un simbolo entero, la tira
# vuelve a su lugar y los simbolos rotan: da la vuelta infinita sin
# crear ni destruir nodos.
func _armar_rodillos() -> void:
	_tiras.clear()
	_etiquetas.clear()
	_simbolos_tira.clear()

	for i in range(3):
		var cont: Panel = rodillos[i]

		var tira := Control.new()
		tira.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tira.position = Vector2(0, -ALTO_SIMBOLO)
		cont.add_child(tira)

		var etiquetas: Array = []
		var simbolos: Array = []
		for j in range(SIMBOLOS_TIRA):
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 52)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.position = Vector2(0, j * ALTO_SIMBOLO)
			l.size = Vector2(cont.size.x, ALTO_SIMBOLO)
			tira.add_child(l)
			etiquetas.append(l)
			simbolos.append(randi() % SIMBOLOS.size())

		_tiras.append(tira)
		_etiquetas.append(etiquetas)
		_simbolos_tira.append(simbolos)
		_pintar_tira(i)
		_centrar_tira(i)

		# La sombra va DESPUES de la tira para quedar encima.
		cont.add_child(_sombra_cilindro())


# EL TRUCO DEL TAMBOR. Un degradado oscuro arriba y abajo de cada
# rodillo, transparente en el medio. Con eso tres simbolos planos pasan a
# leerse como un cilindro girando: el ojo interpreta el oscurecimiento
# como una superficie que se curva y se aleja. Es lo que mas aporta de
# todo el pulido visual, y es un solo nodo por rodillo.
func _sombra_cilindro() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.95),
		Color(0, 0, 0, 0.45),
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.45),
		Color(0, 0, 0, 0.95),
	])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 8
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# Deja la tira con el simbolo de la linea de pago en el centro del visor.
func _centrar_tira(i: int) -> void:
	var cont: Panel = rodillos[i]
	var centro: float = cont.size.y * 0.5
	# La etiqueta 1 es la de la linea de pago.
	_tiras[i].position.y = centro - ALTO_SIMBOLO * 1.5
	_offset[i] = 0.0


func _pintar_tira(i: int) -> void:
	var cont: Panel = rodillos[i]
	for j in range(SIMBOLOS_TIRA):
		var l: Label = _etiquetas[i][j]
		var idx: int = _simbolos_tira[i][j]
		l.text = SIMBOLOS[idx]
		l.size = Vector2(cont.size.x, ALTO_SIMBOLO)
		l.add_theme_color_override("font_color", COLORES_SIMBOLO[idx])


func _actualizar_rodillos(delta: float) -> void:
	for i in range(3):
		match _estado_rodillo[i]:
			1:
				# Acelerando hasta velocidad plena
				_velocidad[i] = min(VELOCIDAD_GIRO, _velocidad[i] + ACELERACION * delta)
				_desplazar(i, delta)
				_borronear(i)

				if _tiempo_giro >= PARADAS[i] - DURACION_FRENADA - DURACION_ATERRIZAJE:
					_frenar_rodillo(i)
			2:
				_desplazar(i, delta)
				_borronear(i)
			3:
				pass   # lo maneja el tween del aterrizaje

	if _suspenso_activo and _fase == Fase.SUSPENSO:
		_avanzar_suspenso(delta)


func _desplazar(i: int, delta: float) -> void:
	_offset[i] += _velocidad[i] * delta

	while _offset[i] >= ALTO_SIMBOLO:
		_offset[i] -= ALTO_SIMBOLO
		# La tira rota: el de abajo se va, entra uno nuevo arriba.
		var s: Array = _simbolos_tira[i]
		s.pop_back()
		s.push_front(randi() % SIMBOLOS.size())
		_pintar_tira(i)

	var cont: Panel = rodillos[i]
	var base: float = cont.size.y * 0.5 - ALTO_SIMBOLO * 1.5
	_tiras[i].position.y = base + _offset[i]


# A velocidad alta la tira se transparenta: es un borron barato pero
# convincente, porque el ojo ya no distingue los simbolos.
func _borronear(i: int) -> void:
	var f: float = clamp(_velocidad[i] / VELOCIDAD_GIRO, 0.0, 1.0)
	_tiras[i].modulate.a = lerp(1.0, ALPHA_BORRON, f)


# El rodillo desacelera y despues aterriza con rebote sobre su resultado.
func _frenar_rodillo(i: int) -> void:
	if _estado_rodillo[i] != 1:
		return

	# El TERCER rodillo, si los dos primeros coinciden, no frena: entra
	# en suspenso y se arrastra simbolo por simbolo.
	if i == 2 and _resultado[0] == _resultado[1] and _resultado[1] != _resultado[2]:
		_estado_rodillo[i] = 2
		_suspenso_activo = true
		_fase = Fase.SUSPENSO
		_suspenso_reloj = DURACION_SUSPENSO
		_suspenso_paso = 0.0
		_modo_luces = 2

		var t := create_tween()
		t.tween_method(func(v: float) -> void: _velocidad[i] = v,
			_velocidad[i], ALTO_SIMBOLO / PASO_SUSPENSO, 0.55)
		t.tween_callback(func() -> void: _tiras[i].modulate.a = 1.0)
		return

	_estado_rodillo[i] = 2

	var t2 := create_tween()
	t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.tween_method(func(v: float) -> void: _velocidad[i] = v,
		_velocidad[i], 120.0, DURACION_FRENADA)
	t2.tween_callback(_aterrizar_rodillo.bind(i))


# Deja el simbolo que corresponde justo arriba de la linea de pago y lo
# hace caer con rebote. Es lo que hace un rodillo fisico cuando el freno
# lo pasa un poco y vuelve.
func _aterrizar_rodillo(i: int) -> void:
	_estado_rodillo[i] = 3
	_velocidad[i] = 0.0
	_tiras[i].modulate.a = 1.0

	# El de la linea de pago es el indice 1; los demas, decorado.
	var s: Array = _simbolos_tira[i]
	s[1] = _resultado[i]
	for j in range(SIMBOLOS_TIRA):
		if j != 1:
			s[j] = randi() % SIMBOLOS.size()
	_pintar_tira(i)

	var cont: Panel = rodillos[i]
	var base: float = cont.size.y * 0.5 - ALTO_SIMBOLO * 1.5
	_tiras[i].position.y = base - ALTO_SIMBOLO * 0.75
	_offset[i] = 0.0

	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_tiras[i], "position:y", base, DURACION_ATERRIZAJE)
	t.tween_callback(func() -> void: _estado_rodillo[i] = 4)

	# El golpe: sonido con el tono subiendo rodillo a rodillo, y el visor
	# salta. Tres impactos ascendentes se leen como una escalera.
	Juice.sonar(snd_rodillo, float(i) * 2.0)
	Juice.shake(visor, 5.0 - i, 0.14)


# El arrastre del casi-premio: un simbolo por vez, cada vez mas lento.
func _avanzar_suspenso(delta: float) -> void:
	_suspenso_reloj -= delta
	_suspenso_paso += delta

	if _suspenso_paso >= PASO_SUSPENSO:
		_suspenso_paso = 0.0
		Juice.sonar(snd_casi, 0.0, 0.05)
		Juice.pop(visor, 0.02, 0.18)
		_latir_linea()

	if _suspenso_reloj <= 0.0:
		_suspenso_activo = false
		_fase = Fase.GIRANDO
		_modo_luces = 1
		_aterrizar_rodillo(2)


func _latir_linea() -> void:
	linea_pago.color = Color(1.0, 0.35, 0.3, 0.85)
	var t := create_tween()
	t.tween_property(linea_pago, "color:a", 0.39, 0.22)


# ============================================================
#  La palanca
# ============================================================

func _input_palanca(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_intentar_agarrar(event.position.y)
		elif _arrastrando:
			_arrastrando = false
			_soltar_palanca()
		return

	if event is InputEventMouseMotion and _arrastrando:
		# Si el boton ya no esta apretado, no hay arrastre. Pasa cuando
		# el jugador suelta FUERA del area de la palanca: ese evento no
		# llega a gui_input y _arrastrando quedaba encendido para
		# siempre, asi que despues mover el mouse por encima movia la
		# perilla sola y disparaba la tirada sin que nadie la tocara.
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_cancelar_arrastre()
			return

		perilla.position.y = clamp(event.position.y - _offset_agarre, _y_arriba, _y_abajo)
		_revisar_fondo()


# Dispara la tirada solo si la perilla llego al fondo Y ADEMAS recorrio
# lo suficiente desde donde se la agarro. Las dos condiciones juntas: con
# la primera sola, cualquier cosa que dejara la perilla abajo cobraba la
# tirada sin gesto.
func _revisar_fondo() -> void:
	if not _arrastrando:
		return
	if perilla.position.y < _y_abajo - TOLERANCIA_FONDO:
		return

	var recorrido: float = max(1.0, _y_abajo - _y_arriba)
	if (perilla.position.y - _y_agarre) / recorrido < RECORRIDO_MINIMO:
		return

	perilla.position.y = _y_abajo
	_arrastrando = false
	_tirar()


# Se puede agarrar la perilla, o el area un poco mas grande alrededor:
# asi no hay que apuntar con precision.
# Si el mouse se va de la palanca, se corta el arrastre. Es la otra
# mitad de la red: entre esto y el chequeo del boton, _arrastrando no
# puede quedar encendido sin que haya una mano apretando de verdad.
func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_MOUSE_EXIT and _arrastrando:
		_cancelar_arrastre()


func _cancelar_arrastre() -> void:
	if not _arrastrando:
		return
	_arrastrando = false
	_soltar_palanca()


func _intentar_agarrar(y_local: float) -> void:
	if _fase != Fase.QUIETO or _paso_paywall > 0:
		return

	var centro: float = perilla.position.y + perilla.size.y * 0.5
	var alcance: float = perilla.size.y * 0.5 + MARGEN_AGARRE

	if abs(y_local - centro) > alcance:
		return

	# Solo se agarra desde arriba. Si por lo que sea quedo a mitad de
	# camino, vuelve al tope antes de dejarse agarrar: asi el recorrido
	# siempre se mide desde el mismo lugar.
	if perilla.position.y > _y_arriba + 2.0:
		perilla.position.y = _y_arriba
		return

	_arrastrando = true
	_y_agarre = perilla.position.y
	_offset_agarre = y_local - perilla.position.y
	Juice.escalar_a(perilla, 1.06, 0.1)


# La perilla se ilumina al pasarle el mouse por encima: dice "esto se
# toca" sin un solo cartel.
func _al_entrar_palanca() -> void:
	if _fase != Fase.QUIETO or _paso_paywall > 0:
		return
	var t := create_tween()
	t.tween_property(perilla, "modulate", Color(1.22, 1.14, 1.14), 0.14)


func _al_salir_palanca() -> void:
	if _arrastrando:
		return
	# Vuelve al color que le corresponde al estado: si la maquina esta
	# girando tiene que quedar apagada, no blanca.
	var destino := Color.WHITE if _fase == Fase.QUIETO else Color(0.45, 0.45, 0.45, 1.0)
	var t := create_tween()
	t.tween_property(perilla, "modulate", destino, 0.2)


# Sube despacio y frenando, como un resorte que se relaja. El tiempo
# que tarda es tiempo en el que el jugador VE lo que hizo.
func _soltar_palanca() -> void:
	Juice.escalar_a(perilla, 1.0, 0.12)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(perilla, "position:y", _y_arriba, RETORNO_PALANCA)
	Juice.sonar(snd_palanca_sube, 0.0, 0.06)


# ============================================================
#  Girar
# ============================================================

func _tirar() -> void:
	if _fase != Fase.QUIETO or _paso_paywall > 0:
		_soltar_palanca()
		return

	# Sin plata no se juega
	if _creditos < COSTO_TIRADA:
		_soltar_palanca()
		_abrir_paywall()
		return

	# EL GOLPE. Es el instante mas importante de la app: todo lo que pasa
	# aca ocurre en el MISMO frame, para que se lea como un solo impacto.
	Juice.sonar(snd_palanca)
	Juice.shake(maquina, 11.0, 0.3)
	Juice.pop(visor, 0.05, 0.25)
	_flash_visor(0.5, 0.18)

	# ------------------------------------------------------------
	#  TODO EL ESTADO DEL GIRO SE ARMA ACA, SIN NINGUN await EN EL MEDIO.
	# ------------------------------------------------------------
	# Antes _fase se ponia en GIRANDO y recien despues de un await de
	# 100 ms se reseteaba _tiempo_giro y el estado de los rodillos. En
	# esos 100 ms, _process corria con _fase = GIRANDO pero con los
	# valores de la tirada ANTERIOR: _tiempo_giro ya pasaba los 5 s y los
	# tres rodillos figuraban parados, asi que la condicion de fin se
	# cumplia en el primer frame y el giro terminaba antes de empezar.
	#
	# Eso daba los tres sintomas a la vez: salia "girando...", los
	# rodillos no se movian (porque _fase ya habia vuelto a QUIETO) y la
	# palanca quedaba libre para tirar de nuevo enseguida.
	#
	# Regla para no repetirlo: entre cambiar _fase y dejar el estado
	# consistente NO puede haber un await.
	_resultado = _sortear_resultado()
	_tiempo_giro = 0.0
	_suspenso_activo = false
	_modo_luces = 1

	for i in range(3):
		_estado_rodillo[i] = 1
		_velocidad[i] = 0.0
		_tiras[i].modulate.a = 1.0

	_fase = Fase.GIRANDO
	_palanca_lista(false)

	_creditos -= COSTO_TIRADA
	_actualizar_hud(true)

	# LA DOPAMINA ENTRA ACA, en el gesto. No en el resultado.
	recompensar()
	_mostrar_indicador("+%d" % int(dopamina_por_interaccion), Color.WHITE)

	if snd_girando and snd_girando.stream:
		snd_girando.play()

	mensaje.text = "girando..."

	# Lo unico que espera es soltar la palanca, que es puro adorno: el
	# giro ya esta andando.
	await get_tree().create_timer(0.1).timeout
	_soltar_palanca()


# Decide que va a salir ANTES de girar.
func _sortear_resultado() -> Array:
	var tirada := randf()

	if tirada < PROB_JACKPOT:
		var s := randi() % SIMBOLOS.size()
		return [s, s, s]

	if tirada < PROB_JACKPOT + PROB_CASI:
		# CASI-PREMIO: los dos primeros iguales, el tercero no.
		# El tercer rodillo entra en suspenso y se arrastra: queda un
		# segundo y medio entero mirandolo. Ese tiempo es el efecto.
		var s := randi() % SIMBOLOS.size()
		var otro := s
		while otro == s:
			otro = randi() % SIMBOLOS.size()
		return [s, s, otro]

	return [
		randi() % SIMBOLOS.size(),
		randi() % SIMBOLOS.size(),
		randi() % SIMBOLOS.size(),
	]


func _terminar_giro() -> void:
	if _fase == Fase.QUIETO:
		return   # ya termino: no entrar dos veces

	_fase = Fase.QUIETO
	_tiempo_giro = 0.0   # que no quede un valor viejo para la proxima
	_suspenso_activo = false

	if snd_girando and snd_girando.playing:
		snd_girando.stop()

	var jackpot: bool = _resultado[0] == _resultado[1] and _resultado[1] == _resultado[2]
	var casi: bool = not jackpot and _resultado[0] == _resultado[1]

	if jackpot:
		await _celebrar_jackpot()
	elif casi:
		# El casi-premio se subraya: los DOS que salieron iguales se
		# encienden, y el tercero no. Ver cual fallo es lo que duele.
		mensaje.text = "¡casi!"
		Juice.tambalear(mensaje, 5.0, 0.45)
		Juice.shake(visor, 4.0, 0.2)
		for i in range(2):
			Juice.tintar(_etiquetas[i][1], ORO, 0.12)
			Juice.pop(_etiquetas[i][1], 0.16, 0.35)
		await get_tree().create_timer(0.6).timeout
		for i in range(2):
			Juice.tintar(_etiquetas[i][1], Color.WHITE, 0.35)
		_modo_luces = 0
	else:
		_modo_luces = 0
		if randf() < 0.2:
			_creditos += PREMIO_CHICO
			mensaje.text = "+$%d" % PREMIO_CHICO
			_actualizar_hud(true)
			Juice.sonar(snd_moneda, 2.0)
			_lanzar(chispas2, creditos_label)
			Juice.pop(mensaje, 0.18, 0.3)
		else:
			mensaje.text = "bajá la palanca"

	# Recien aca vuelve a estar disponible: si se liberaba al principio,
	# se podia tirar en plena celebracion del premio.
	_palanca_lista(true)

	if _creditos < COSTO_TIRADA:
		await get_tree().create_timer(0.9).timeout
		_abrir_paywall()


# EL PREMIO, POR CAPAS. Ninguna capa entra junto con la anterior: si
# todo pasara en el mismo frame se leeria como un solo evento, y
# escalonado se lee como una maquina celebrando. El orden importa tanto
# como el contenido.
func _celebrar_jackpot() -> void:
	_modo_luces = 2
	mensaje.text = "¡PREMIO! +$%d" % PREMIO_JACKPOT

	# CAPA 1 - el impacto
	recompensar(MULT_JACKPOT)
	Juice.sonar(snd_jackpot)
	_flash_visor(1.0, 0.35)
	Juice.shake(maquina, 16.0, 0.55)
	Juice.flash(marquesina, Color(2.6, 2.2, 1.4), 0.2)
	_golpe_de_zoom()
	_barrer_linea_ganadora()

	# CAPA 2 - los tres simbolos ganadores saltan uno por uno
	for i in range(3):
		await get_tree().create_timer(0.07).timeout
		var l: Label = _etiquetas[i][1]
		Juice.pop(l, 0.3, 0.45)
		Juice.tintar(l, ORO, 0.1)
		Juice.sonar(snd_moneda, 4.0 + i * 2.0)
		_lanzar(chispas if i % 2 == 0 else chispas2, rodillos[i])

	# CAPA 3 - el cartel entra de golpe y se pasa
	await get_tree().create_timer(0.1).timeout
	_mostrar_cartel_premio()

	# CAPA 4 - el pago, moneda por moneda
	await get_tree().create_timer(0.3).timeout
	await _pagar_premio()

	# CAPA 5 - se apaga
	await get_tree().create_timer(0.7).timeout
	_ocultar_cartel_premio()
	if _fase == Fase.QUIETO:
		_modo_luces = 0

	for i in range(3):
		Juice.tintar(_etiquetas[i][1], Color.WHITE, 0.3)


# Todo el gabinete se agranda un instante. Es el recurso mas viejo del
# feedback y sigue siendo el mas efectivo: el golpe se siente en el
# cuerpo del mueble, no solo en el visor.
func _golpe_de_zoom() -> void:
	Juice.centrar_pivote(maquina)
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(maquina, "scale", Vector2(1.035, 1.035), 0.09)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(maquina, "scale", Vector2.ONE, 0.5)


# La linea de pago se enciende y barre de izquierda a derecha, como si
# el premio se "leyera" de un rodillo al otro.
func _barrer_linea_ganadora() -> void:
	linea_pago.color = Color(1.0, 0.92, 0.45, 1.0)
	linea_pago.pivot_offset = Vector2(0, linea_pago.size.y * 0.5)
	linea_pago.scale = Vector2(0.0, 5.0)

	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(linea_pago, "scale", Vector2(1.0, 5.0), 0.3)
	t.tween_property(linea_pago, "scale", Vector2(1.0, 1.0), 0.35)
	t.parallel().tween_property(linea_pago, "color",
		Color(0.886275, 0.231373, 0.231373, 0.392157), 0.5)


# Entra enorme y se achica de golpe, con un ladeo. Un cartel que aparece
# en su tamano final no se siente como un impacto; este si.
func _mostrar_cartel_premio() -> void:
	cartel_premio.show()
	cartel_premio.modulate.a = 1.0
	Juice.centrar_pivote(cartel_premio)
	cartel_premio.scale = Vector2(2.4, 2.4)
	cartel_premio.rotation = deg_to_rad(-7.0)

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cartel_premio, "scale", Vector2.ONE, 0.38)
	t.tween_property(cartel_premio, "rotation", 0.0, 0.42)
	await t.finished

	# Y despues respira, para que no quede muerto en pantalla
	var t2 := create_tween().set_loops()
	t2.set_trans(Tween.TRANS_SINE)
	t2.tween_property(cartel_premio, "scale", Vector2.ONE * 1.06, 0.4)
	t2.tween_property(cartel_premio, "scale", Vector2.ONE, 0.4)
	cartel_premio.set_meta("tween", t2)


func _ocultar_cartel_premio() -> void:
	var t = cartel_premio.get_meta("tween", null)
	if t is Tween and t.is_valid():
		t.kill()

	var salida := create_tween()
	salida.set_parallel(true)
	salida.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	salida.tween_property(cartel_premio, "scale", Vector2(0.6, 0.6), 0.25)
	salida.tween_property(cartel_premio, "modulate:a", 0.0, 0.25)
	await salida.finished
	cartel_premio.hide()


# No acredita el premio de una: lo CUENTA. Cada paso suena, el display
# salta y caen monedas. Es tiempo muerto puro, y es el que mas engancha.
func _pagar_premio() -> void:
	var por_paso: float = float(PREMIO_JACKPOT) / float(PASOS_PAGO)
	var acumulado: float = 0.0
	var base: int = _creditos

	for paso in range(PASOS_PAGO):
		acumulado += por_paso
		_creditos = base + int(round(acumulado))
		creditos_label.text = "$%d" % _creditos

		# El tono sube paso a paso: la cuenta se vuelve una melodia
		# ascendente, igual que el truco de los aciertos de Lingofy.
		Juice.sonar(snd_moneda, float(paso) * 0.9)
		Juice.pop(creditos_label, 0.16, 0.14)

		if paso % 3 == 0:
			_lanzar(chispas2, creditos_label)

		await get_tree().create_timer(PASO_PAGO).timeout

	_creditos = base + PREMIO_JACKPOT
	creditos_label.text = "$%d" % _creditos
	Juice.pop(creditos_label, 0.3, 0.4)
	_mostrar_indicador("+%d" % int(dopamina_por_interaccion * MULT_JACKPOT), ORO)


# ============================================================
#  Las luces de la marquesina
# ============================================================

func _armar_bombitas() -> void:
	_luces.clear()
	for i in range(BOMBITAS):
		var b := Panel.new()
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.custom_minimum_size = Vector2(12, 12)
		b.size = Vector2(12, 12)

		var e := StyleBoxFlat.new()
		e.bg_color = ORO
		e.set_corner_radius_all(6)
		b.add_theme_stylebox_override("panel", e)

		bombitas_padre.add_child(b)
		_luces.append(b)

	_acomodar_bombitas()


func _acomodar_bombitas() -> void:
	var ancho: float = bombitas_padre.size.x
	var alto: float = bombitas_padre.size.y
	if ancho <= 0.0:
		return

	var paso: float = ancho / float(BOMBITAS)
	for i in range(_luces.size()):
		var b: Panel = _luces[i]
		b.position = Vector2(paso * i + paso * 0.5 - 6.0, 6.0)
		# Una fila arriba y otra abajo, alternando.
		if i % 2 == 1:
			b.position.y = alto - 18.0


func _animar_luces(delta: float) -> void:
	if _luces.is_empty():
		return

	_acomodar_bombitas()
	_fase_luces += delta * VELOCIDAD_LUCES

	for i in range(_luces.size()):
		var b: Panel = _luces[i]
		var brillo: float = 0.0

		match _modo_luces:
			0:
				# Atraccion: una onda lenta que recorre la marquesina.
				brillo = 0.35 + 0.35 * sin(_fase_luces * 0.35 - i * 0.5)
			1:
				# Girando: persecucion rapida.
				brillo = 1.0 if (int(_fase_luces) % _luces.size()) == i else 0.25
			2:
				# Premio: parpadeo total.
				brillo = 1.0 if int(_fase_luces * 2.2) % 2 == 0 else 0.15

		b.modulate = Color(1, 1, 1, clamp(brillo, 0.0, 1.0))


# ============================================================
#  El paywall
# ============================================================

func _abrir_paywall() -> void:
	if _paso_paywall > 0:
		return

	_paso_paywall = 1
	texto_paywall.text = "Te quedaste sin créditos."
	boton_paywall.text = "COMPRAR MÁS"
	reloj_paywall.text = "la oferta vence en 04:59"

	paywall.show()
	paywall.modulate.a = 0.0
	Juice.centrar_pivote(tarjeta_paywall)
	tarjeta_paywall.scale = Vector2(0.86, 0.86)

	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(paywall, "modulate:a", 1.0, 0.2)
	t.tween_property(tarjeta_paywall, "scale", Vector2.ONE, 0.32)

	_latir_boton()

	# El layout de la tarjeta recien esta resuelto despues de mostrarla.
	await get_tree().process_frame
	_centrar_boton()


func _click_paywall() -> void:
	# Da una miseria: es engagement vacio mientras la barra sigue bajando
	GameManager.sumar_dopamina(DOPAMINA_POR_CLICK_PAYWALL, id_app)

	Juice.sonar(snd_moneda, randf_range(-1.0, 3.0))
	Juice.pop(tarjeta_paywall, 0.04, 0.2)
	_lanzar(monedas, boton_paywall)

	# El boton se escapa: hay que perseguirlo con el mouse.
	# Es un patron oscuro real y consume atencion mientras la barra baja.
	_reubicar_boton()

	match _paso_paywall:
		1:
			_paso_paywall = 2
			texto_paywall.text = "¿Estás seguro?"
			boton_paywall.text = "SÍ, QUIERO"
			reloj_paywall.text = "quedan pocas unidades"
		2:
			_paso_paywall = 3
			_clicks_restantes = CLICKS_CONFIRMACION
			texto_paywall.text = "Confirmá tu compra"
			boton_paywall.text = "CONFIRMAR (%d)" % _clicks_restantes
			reloj_paywall.text = "casi listo..."
		3:
			_clicks_restantes -= 1
			if _clicks_restantes > 0:
				boton_paywall.text = "CONFIRMAR (%d)" % _clicks_restantes
			else:
				_cerrar_paywall()


func _cerrar_paywall() -> void:
	_paso_paywall = 0

	if _tween_latido and _tween_latido.is_valid():
		_tween_latido.kill()
		boton_paywall.scale = Vector2.ONE

	_recargar_creditos()

	var t := create_tween()
	t.tween_property(paywall, "modulate:a", 0.0, 0.18)
	await t.finished

	paywall.hide()
	_actualizar_hud(true)
	mensaje.text = "bajá la palanca"
	Juice.sonar(snd_moneda, 6.0)


# El boton late para que la mirada vaya ahi aunque se mueva de lugar.
func _latir_boton() -> void:
	Juice.centrar_pivote(boton_paywall)
	if _tween_latido and _tween_latido.is_valid():
		_tween_latido.kill()

	_tween_latido = create_tween().set_loops()
	_tween_latido.set_trans(Tween.TRANS_SINE)
	_tween_latido.tween_property(boton_paywall, "scale", Vector2.ONE * 1.05, 0.42)
	_tween_latido.tween_property(boton_paywall, "scale", Vector2.ONE, 0.42)


# Donde arranca el boton la primera vez: centrado dentro de la tarjeta,
# debajo del texto. Solo lo usa _centrar_boton(); una vez que empieza a
# escaparse, el boton se mueve por TODO el overlay y puede salirse de la
# tarjeta -- eso es a proposito y es la mitad del chiste.
func _zona_boton() -> Rect2:
	var t := tarjeta_paywall
	var arranque: float = t.position.y + ALTO_TEXTO_PAYWALL
	var x0: float = t.position.x + MARGEN_PAYWALL
	var ancho: float = t.size.x - MARGEN_PAYWALL * 2.0 - boton_paywall.size.x
	var alto: float = (t.position.y + t.size.y - MARGEN_PAYWALL
		- boton_paywall.size.y) - arranque

	return Rect2(x0, arranque, max(0.0, ancho), max(0.0, alto))


# La PRIMERA vez aparece centrado y quieto. Que la trampa empiece recien
# en el segundo click es lo que la hace trampa: si el boton ya arrancara
# escapandose, el jugador entenderia el juego antes de entrar y no
# picaria. Primero te dejan apretar comodo.
func _centrar_boton() -> void:
	var z := _zona_boton()
	boton_paywall.position = Vector2(
		z.position.x + z.size.x * 0.5,
		z.position.y + z.size.y * 0.5
	)


# A partir del primer click se escapa por TODO el overlay, no solo por
# la tarjeta: que se vaya a una esquina y haya que perseguirlo con el
# mouse es el patron oscuro que la app esta retratando.
func _reubicar_boton() -> void:
	var libre_x: float = paywall.size.x - boton_paywall.size.x - MARGEN_PAYWALL * 2.0
	var tope_arriba: float = paywall.size.y * 0.62   # debajo del texto
	var libre_y: float = paywall.size.y - boton_paywall.size.y - MARGEN_PAYWALL - tope_arriba

	if libre_x <= 0.0 or libre_y <= 0.0:
		return   # la ventana es muy chica: lo dejamos donde esta

	var destino := Vector2(
		MARGEN_PAYWALL + randf() * libre_x,
		tope_arriba + randf() * libre_y
	)

	# Se desliza en vez de teletransportarse: asi el ojo lo puede seguir
	# y la persecucion se siente tramposa, no rota.
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(boton_paywall, "position", destino, 0.16)


func _recargar_creditos() -> void:
	_creditos = randi_range(TIRADAS_MIN, TIRADAS_MAX) * COSTO_TIRADA


# ============================================================
#  HUD y feedback
# ============================================================

func _actualizar_hud(animado: bool) -> void:
	if animado:
		var desde := float(creditos_label.text.replace("$", "").to_int())
		Juice.contar(creditos_label, desde, float(_creditos), 0.45, "$%.0f")
		Juice.pop(creditos_label, 0.12, 0.3)
	else:
		creditos_label.text = "$%d" % _creditos


# La palanca se apaga mientras la maquina trabaja, y respira cuando esta
# lista: una maquina de casino nunca se queda del todo quieta.
func _palanca_lista(lista: bool) -> void:
	if lista:
		perilla.position.y = _y_arriba

	etiqueta_palanca.text = "BAJÁ" if lista else "0.0"
	perilla.modulate = Color.WHITE if lista else Color(0.45, 0.45, 0.45, 1.0)

	if lista:
		_respirar_perilla()
	elif perilla.has_meta("respirando"):
		perilla.remove_meta("respirando")
		var t = perilla.get_meta("tween_respirar", null)
		if t is Tween and t.is_valid():
			t.kill()
		perilla.scale = Vector2.ONE


func _respirar_perilla() -> void:
	if perilla.has_meta("respirando"):
		return
	perilla.set_meta("respirando", true)
	Juice.centrar_pivote(perilla)

	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.tween_property(perilla, "scale", Vector2.ONE * 1.04, 0.7)
	t.tween_property(perilla, "scale", Vector2.ONE, 0.7)
	perilla.set_meta("tween_respirar", t)


# La varilla que une la base con la perilla. Sin esto la perilla flotaba
# sobre el riel; con esto hay una palanca de verdad, que se acorta a
# medida que baja. Es barato y cambia por completo como se lee el gesto.
func _actualizar_vastago() -> void:
	var centro: float = perilla.position.y + perilla.size.y * 0.5
	var pie: float = palanca.size.y - 58.0   # el borde de arriba de la Base

	vastago.position.y = centro
	vastago.size.y = max(0.0, pie - centro)


# Una maquina vacia no se queda quieta: cada tanto hace un floreo para
# que la mires. Es el mismo gesto con el que te llaman las de verdad.
func _revisar_atraccion(delta: float) -> void:
	if _paso_paywall > 0:
		_reloj_atraccion = 0.0
		return

	_reloj_atraccion += delta
	if _reloj_atraccion < ESPERA_ATRACCION:
		return

	_reloj_atraccion = 0.0
	_floreo_atraccion()


func _floreo_atraccion() -> void:
	Juice.sonar(snd_luz, 0.0, 0.1)
	Juice.pop(titulo, 0.12, 0.5)
	Juice.pop(etiqueta_palanca, 0.2, 0.45)

	# Una ola de luz que recorre la marquesina de punta a punta
	for i in range(_luces.size()):
		var b: Panel = _luces[i]
		var t := create_tween()
		t.tween_interval(i * 0.035)
		t.tween_property(b, "modulate", Color(1, 1, 1, 1), 0.08)
		t.tween_property(b, "modulate", Color(1, 1, 1, 0.3), 0.3)

	# Y el visor da un brillo apenas perceptible
	_flash_visor(0.12, 0.5)


# Los displays de las maquinas son LED viejos y titilan. Un parpadeo
# minimo y espaciado alcanza para que el gabinete se sienta encendido
# en vez de dibujado.
func _parpadear_display(delta: float) -> void:
	_parpadeo -= delta
	if _parpadeo > 0.0:
		return

	_parpadeo = randf_range(1.8, 5.0)
	var t := create_tween()
	t.tween_property(creditos_label, "modulate:a", 0.55, 0.04)
	t.tween_property(creditos_label, "modulate:a", 1.0, 0.09)


func _flash_visor(fuerza: float, duracion: float) -> void:
	destello.color.a = fuerza
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(destello, "color:a", 0.0, duracion)


func _lanzar(particulas: GPUParticles2D, sobre: Control) -> void:
	if particulas == null or sobre == null:
		return
	var padre := particulas.get_parent() as Control
	if padre == null:
		return
	particulas.position = sobre.global_position - padre.global_position + sobre.size * 0.5
	particulas.restart()
	particulas.emitting = true


func _mostrar_indicador(texto: String, color: Color) -> void:
	# La posicion de arranque se guarda UNA vez y siempre se vuelve a
	# ella. Antes el tween restaba 26 y los devolvia en un callback: si
	# lo mataba otra tirada, el callback no corria nunca y el numero se
	# iba subiendo un poco mas en cada premio.
	if _y_indicador == INF:
		_y_indicador = indicador.position.y

	if _tween_indicador and _tween_indicador.is_valid():
		_tween_indicador.kill()

	indicador.text = texto
	indicador.modulate = color
	indicador.modulate.a = 1.0
	indicador.position.y = _y_indicador
	Juice.centrar_pivote(indicador)
	indicador.scale = Vector2(0.7, 0.7)

	_tween_indicador = create_tween()
	_tween_indicador.set_parallel(true)
	_tween_indicador.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_indicador.tween_property(indicador, "scale", Vector2.ONE, 0.28)
	_tween_indicador.tween_property(indicador, "position:y", _y_indicador - 26.0, 0.8)
	_tween_indicador.chain().tween_property(indicador, "modulate:a", 0.0, 0.35)


func _cargar_sonidos() -> void:
	var mapa := {
		"palanca": snd_palanca,
		"palanca_sube": snd_palanca_sube,
		"girando": snd_girando,
		"rodillo_para": snd_rodillo,
		"casi": snd_casi,
		"jackpot": snd_jackpot,
		"moneda": snd_moneda,
		"luz": snd_luz,
	}

	for clave in mapa:
		var reproductor: AudioStreamPlayer = mapa[clave]
		if reproductor == null or reproductor.stream != null:
			continue

		var nombre: String = SONIDOS[clave]
		var encontrado := false

		for ext in EXTENSIONES:
			var ruta: String = CARPETA_SONIDOS + nombre + ext
			if ResourceLoader.exists(ruta):
				reproductor.stream = load(ruta)
				encontrado = true
				break

		if not encontrado:
			print("[Family Savings] falta el sonido: ", CARPETA_SONIDOS, nombre)
