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
# LA PALANCA:
#   El arrastre es POSICIONAL, no acumulativo: la perilla sigue al mouse
#   por el riel. Es mucho mas tolerante que acumular movimiento relativo
#   y se siente como una palanca de verdad. El area de agarre es mas ancha
#   que la perilla para que no haya que apuntar con precision.

# ---- BALANCEO (provisorio, se ajusta en la fase G) ----
const DURACION_GIRO: float = 5.0
const PARADAS := [2.6, 3.6, 4.6]        # cuando frena cada rodillo
const VELOCIDAD_RODILLO: float = 0.06   # cada cuanto cambia de simbolo

const COSTO_TIRADA: int = 25
const PREMIO_CHICO: int = 3
const PREMIO_JACKPOT: int = 12
const TIRADAS_MIN: int = 3
const TIRADAS_MAX: int = 7

const PROB_JACKPOT: float = 0.10        # tres iguales
const PROB_CASI: float = 0.35           # dos iguales y el tercero no
const MULT_JACKPOT: float = 3.0

const CLICKS_CONFIRMACION: int = 5
const DOPAMINA_POR_CLICK_PAYWALL: float = 0
const MARGEN_PAYWALL: float = 24.0      # cuanto respeta los bordes al reubicarse

const MARGEN_AGARRE: float = 40.0       # cuanto mas alla de la perilla se puede agarrar
const TOLERANCIA_FONDO: float = 4.0     # margen para considerar que llego abajo

const SIMBOLOS := ["🍒", "🔔", "⭐", "7", "💎", "🍋"]

# ---- NODOS ----
@onready var simbolos := [
	$Maquina/Rodillos/Simbolo0,
	$Maquina/Rodillos/Simbolo1,
	$Maquina/Rodillos/Simbolo2,
]
@onready var palanca: Control = $Palanca
@onready var riel: ColorRect = $Palanca/Riel
@onready var perilla: Panel = $Palanca/Perilla
@onready var etiqueta_palanca: Label = $Palanca/Etiqueta
@onready var creditos_label: Label = $Maquina/PanelInferior/Creditos
@onready var mensaje: Label = $Maquina/PanelInferior/Mensaje
@onready var indicador: Label = $Maquina/Indicador
@onready var paywall: Panel = $Paywall
@onready var texto_paywall: Label = $Paywall/TextoPaywall
@onready var boton_paywall: Button = $Paywall/BotonPaywall

# ---- ESTADO ----
var _creditos: int = 0
var _girando: bool = false
var _tiempo_giro: float = 0.0
var _acumulador_simbolo: float = 0.0
var _resultado := [0, 0, 0]
var _rodillo_parado := [false, false, false]

var _arrastrando: bool = false
var _offset_agarre: float = 0.0
var _y_arriba: float = 0.0
var _y_abajo: float = 0.0

# 0 = jugando, 1 = oferta, 2 = confirmacion, 3 = spam de clicks
var _paso_paywall: int = 0
var _clicks_restantes: int = 0


func _ready() -> void:
	palanca.gui_input.connect(_input_palanca)
	boton_paywall.pressed.connect(_click_paywall)

	paywall.hide()
	indicador.modulate.a = 0.0

	_calcular_recorrido()
	perilla.position.y = _y_arriba

	_recargar_creditos()
	_actualizar_hud()
	_palanca_lista(true)

	for i in range(3):
		simbolos[i].text = SIMBOLOS[randi() % SIMBOLOS.size()]

	# Si la app se abre sola (F6) nadie llama a iniciar(), asi que
	# la arrancamos nosotros. Dentro del escritorio esto no hace nada.
	await get_tree().process_frame
	if not esta_activa:
		iniciar()


# El recorrido de la perilla va de punta a punta del riel.
func _calcular_recorrido() -> void:
	_y_arriba = riel.position.y
	_y_abajo = riel.position.y + riel.size.y - perilla.size.y


func _process(delta: float) -> void:
	if not esta_activa or not _girando:
		return

	_tiempo_giro += delta
	_acumulador_simbolo += delta

	# Contador del cooldown, en la etiqueta de la palanca
	var restante: float = max(0.0, DURACION_GIRO - _tiempo_giro)
	etiqueta_palanca.text = "%.1f s" % restante

	# Los rodillos que siguen girando cambian de simbolo rapido
	if _acumulador_simbolo >= VELOCIDAD_RODILLO:
		_acumulador_simbolo = 0.0
		for i in range(3):
			if not _rodillo_parado[i]:
				simbolos[i].text = SIMBOLOS[randi() % SIMBOLOS.size()]

	# Cada rodillo frena en su momento
	for i in range(3):
		if not _rodillo_parado[i] and _tiempo_giro >= PARADAS[i]:
			_rodillo_parado[i] = true
			simbolos[i].text = SIMBOLOS[_resultado[i]]

	if _tiempo_giro >= DURACION_GIRO:
		_terminar_giro()


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
		var destino: float = clamp(event.position.y - _offset_agarre, _y_arriba, _y_abajo)
		perilla.position.y = destino

		if destino >= _y_abajo - TOLERANCIA_FONDO:
			_arrastrando = false
			_tirar()


# Se puede agarrar la perilla, o el area un poco mas grande alrededor:
# asi no hay que apuntar con precision.
func _intentar_agarrar(y_local: float) -> void:
	if _girando or _paso_paywall > 0:
		return

	var centro: float = perilla.position.y + perilla.size.y * 0.5
	var alcance: float = perilla.size.y * 0.5 + MARGEN_AGARRE

	if abs(y_local - centro) > alcance:
		return

	_arrastrando = true
	_offset_agarre = y_local - perilla.position.y


func _soltar_palanca() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(perilla, "position:y", _y_arriba, 0.45)


# ============================================================
#  Girar
# ============================================================

func _tirar() -> void:
	if _girando or _paso_paywall > 0:
		_soltar_palanca()
		return

	# Sin plata no se juega
	if _creditos < COSTO_TIRADA:
		_soltar_palanca()
		_abrir_paywall()
		return

	_soltar_palanca()

	_creditos -= COSTO_TIRADA
	_actualizar_hud()

	# LA DOPAMINA ENTRA ACA, en el gesto. No en el resultado.
	recompensar()
	_mostrar_indicador("+%d" % int(dopamina_por_interaccion), Color.WHITE)

	_resultado = _sortear_resultado()
	_girando = true
	_tiempo_giro = 0.0
	_acumulador_simbolo = 0.0
	_rodillo_parado = [false, false, false]
	mensaje.text = "girando..."
	_palanca_lista(false)


# Decide que va a salir ANTES de girar.
func _sortear_resultado() -> Array:
	var tirada := randf()

	if tirada < PROB_JACKPOT:
		var s := randi() % SIMBOLOS.size()
		return [s, s, s]

	if tirada < PROB_JACKPOT + PROB_CASI:
		# CASI-PREMIO: los dos primeros iguales, el tercero no.
		# Como los rodillos frenan escalonados, queda un segundo entero
		# mirando el tercero girar. Ese segundo es el efecto.
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
	_girando = false
	_palanca_lista(true)

	var jackpot: bool = _resultado[0] == _resultado[1] and _resultado[1] == _resultado[2]
	var casi: bool = not jackpot and _resultado[0] == _resultado[1]

	if jackpot:
		# Bonus grande de dopamina... y una devolucion de dinero ridicula.
		recompensar(MULT_JACKPOT)
		_creditos += PREMIO_JACKPOT
		_mostrar_indicador("+%d" % int(dopamina_por_interaccion * MULT_JACKPOT), Color.YELLOW)
		mensaje.text = "¡PREMIO! +$%d" % PREMIO_JACKPOT
	elif casi:
		mensaje.text = "¡casi!"
	else:
		if randf() < 0.2:
			_creditos += PREMIO_CHICO
			mensaje.text = "+$%d" % PREMIO_CHICO
		else:
			mensaje.text = "bajá la palanca"

	_actualizar_hud()

	if _creditos < COSTO_TIRADA:
		_abrir_paywall()


# ============================================================
#  El paywall
# ============================================================

func _abrir_paywall() -> void:
	_paso_paywall = 1
	texto_paywall.text = "Te quedaste sin créditos."
	boton_paywall.text = "Comprar más"
	paywall.show()
	_reubicar_boton()


func _click_paywall() -> void:
	# Da una miseria: es engagement vacio mientras la barra sigue bajando
	GameManager.sumar_dopamina(DOPAMINA_POR_CLICK_PAYWALL, id_app)

	# El boton se escapa: hay que perseguirlo con el mouse.
	# Es un patron oscuro real y consume atencion mientras la barra baja.
	_reubicar_boton()

	match _paso_paywall:
		1:
			_paso_paywall = 2
			texto_paywall.text = "¿Estás seguro?"
			boton_paywall.text = "Sí"
		2:
			_paso_paywall = 3
			_clicks_restantes = CLICKS_CONFIRMACION
			texto_paywall.text = "Confirmá tu compra"
			boton_paywall.text = "Sí (%d)" % _clicks_restantes
		3:
			_clicks_restantes -= 1
			if _clicks_restantes > 0:
				boton_paywall.text = "Sí (%d)" % _clicks_restantes
			else:
				_cerrar_paywall()


func _cerrar_paywall() -> void:
	_paso_paywall = 0
	paywall.hide()
	_recargar_creditos()
	_actualizar_hud()
	mensaje.text = "bajá la palanca"


# Lo manda a un lugar al azar, siempre adentro del cuadro y por debajo
# del texto, para que nunca quede tapandolo ni se salga de la app.
func _reubicar_boton() -> void:
	var libre_x: float = paywall.size.x - boton_paywall.size.x - MARGEN_PAYWALL * 2.0
	var tope_arriba: float = paywall.size.y * 0.45   # debajo del texto
	var libre_y: float = paywall.size.y - boton_paywall.size.y - MARGEN_PAYWALL - tope_arriba

	if libre_x <= 0.0 or libre_y <= 0.0:
		return   # la ventana es muy chica: lo dejamos donde esta

	boton_paywall.position = Vector2(
		MARGEN_PAYWALL + randf() * libre_x,
		tope_arriba + randf() * libre_y
	)


func _recargar_creditos() -> void:
	_creditos = randi_range(TIRADAS_MIN, TIRADAS_MAX) * COSTO_TIRADA


# ============================================================
#  HUD y feedback
# ============================================================

func _actualizar_hud() -> void:
	creditos_label.text = "$%d" % _creditos


# La palanca se apaga visualmente mientras la maquina trabaja
func _palanca_lista(lista: bool) -> void:
	etiqueta_palanca.text = "bajá" if lista else "0.0 s"
	perilla.modulate = Color.WHITE if lista else Color(0.45, 0.45, 0.45, 1.0)


func _mostrar_indicador(texto: String, color: Color) -> void:
	indicador.text = texto
	indicador.modulate = color
	indicador.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(indicador, "modulate:a", 0.0, 0.8)
