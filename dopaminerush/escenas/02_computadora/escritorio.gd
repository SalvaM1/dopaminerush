extends CanvasLayer

# El "sistema operativo" falso. Maneja:
#   - la barra de iconos y que se desbloqueen
#   - abrir / cerrar / traer al frente las ventanas
#   - el reloj
#   - (paso 24) el cartel de oferta

const VENTANA := preload("res://escenas/02_computadora/ventana_app.tscn")
const PLACEHOLDER := "res://escenas/03_apps/app_placeholder.tscn"

# Ruta de la escena de cada app, en el MISMO ORDEN que GameManager.APPS.
# Vacio = todavia no existe, se usa la app de prueba.
const ESCENAS_APPS := [
	"res://escenas/03_apps/app_01_scroll/app_scroll.tscn",  # 0 - TikBrainRot
	"res://escenas/03_apps/app_02_slots/app_slots.tscn",    # 1 - Family Savings
	"res://escenas/03_apps/app_03_subway/app_subway.tscn",  # 2 - Youtube Slop
	"res://escenas/03_apps/app_04_racha/app_racha.tscn",  # 3 - Lingofy (racha)
	"",  # 4 - Kompralo!    (ofertas)
	"",  # 5 - Loopify      (musica)
	"",  # 6 - LinkedOut    (linkedin)
]

# Cuanto se corre cada ventana nueva respecto de la anterior,
# para que no aparezcan todas apiladas en el mismo lugar.
const OFFSET_VENTANA := Vector2(38, 34)
const POSICION_INICIAL := Vector2(80, 70)

@onready var contenedor: Control = $Ventanas
@onready var reloj: Label = $Reloj
@onready var cartel: Panel = $CartelOferta
@onready var tropiezo: ColorRect = $Tropiezo
@onready var fin_dia: Panel = $FinDia

# Cuantos minutos del juego pasan por cada segundo real
const VELOCIDAD_RELOJ: float = 12.0
var _minutos: float = 8 * 60.0   # arranca a las 08:00

# indice de app -> ventana abierta
var _ventanas: Dictionary = {}
var _abiertas_historicas: int = 0

var _barra_iconos: Node

# --- SOLO PARA PROBAR: estado de las teclas de debug ---
var _tecla_u: bool = false
var _tecla_p: bool = false
var _tecla_d: bool = false
var _panel_debug: Label = null


func _ready() -> void:
	# find_child busca en todo el arbol, asi funciona este o no dentro
	# de un Panel de fondo.
	_barra_iconos = find_child("BarraIconos", true, false)

	_conectar_iconos()

	GameManager.app_desbloqueada.connect(_al_desbloquear_app)
	GameManager.oferta_app.connect(_al_ofrecer_app)

	GameManager.fallo_temprano.connect(_al_fallar)
	GameManager.dia_arruinado.connect(_al_arruinar_dia)

	cartel.get_node("BotonAceptar").pressed.connect(_al_aceptar_oferta)
	fin_dia.get_node("BotonReiniciar").pressed.connect(_al_empezar_nuevo_dia)

	cartel.hide()
	tropiezo.hide()
	fin_dia.hide()

	_crear_panel_debug()

	# Si esta escena se corre SOLA (F6), arrancamos el juego nosotros.
	# Dentro de la habitacion esto no pasa: lo dispara el sentarse.
	if get_parent() == get_tree().root:
		GameManager.iniciar_sesion_pc()


func _process(delta: float) -> void:
	_minutos += delta * VELOCIDAD_RELOJ
	var h := int(_minutos / 60.0) % 24
	var m := int(_minutos) % 60
	reloj.text = "%02d:%02d" % [h, m]

	# --- SOLO PARA PROBAR — sacar antes de la entrega ---
	# O = saltar al colapso
	if Input.is_physical_key_pressed(KEY_O) and not GameManager.etapa_final:
		_forzar_colapso()

	# U = desbloquear todas las apps
	var u := Input.is_physical_key_pressed(KEY_U)
	if u and not _tecla_u:
		_desbloquear_todo()
	_tecla_u = u

	# P = frenar / reanudar el drenaje de dopamina
	var pp := Input.is_physical_key_pressed(KEY_P)
	if pp and not _tecla_p:
		_alternar_drenaje()
	_tecla_p = pp

	# D = mostrar / ocultar el panel de balanceo
	var dd := Input.is_physical_key_pressed(KEY_D)
	if dd and not _tecla_d:
		_panel_debug.visible = not _panel_debug.visible
	_tecla_d = dd

	if _panel_debug.visible:
		_actualizar_debug()


func _conectar_iconos() -> void:
	for i in range(GameManager.APPS.size()):
		var boton := _barra_iconos.get_node_or_null("Icono%d" % i) as Button
		if boton == null:
			push_warning("No se encontro el nodo Icono%d en BarraIconos" % i)
			continue
		# bind(i) le pasa el indice a la funcion cuando se aprieta el boton
		boton.pressed.connect(_abrir_app.bind(i))
		_actualizar_icono(i)


func _actualizar_icono(indice: int) -> void:
	var boton := _barra_iconos.get_node_or_null("Icono%d" % indice) as Button
	if boton == null:
		return
	var libre := GameManager.esta_desbloqueada(indice)
	boton.disabled = not libre
	boton.modulate = Color.WHITE if libre else Color(0.4, 0.4, 0.4, 1.0)


func _al_desbloquear_app(indice: int) -> void:
	_actualizar_icono(indice)


func _abrir_app(indice: int) -> void:
	if not GameManager.esta_desbloqueada(indice):
		return

	# Si ya esta abierta, no abrimos otra: la traemos al frente.
	if _ventanas.has(indice) and is_instance_valid(_ventanas[indice]):
		contenedor.move_child(_ventanas[indice], -1)
		return

	var ruta: String = ESCENAS_APPS[indice]
	if ruta == "":
		ruta = PLACEHOLDER

	var escena: PackedScene = load(ruta)
	if escena == null:
		push_warning("No se pudo cargar la escena: " + ruta)
		return

	var ventana := VENTANA.instantiate()
	contenedor.add_child(ventana)
	ventana.abrir(escena)

	# El nombre que ve el jugador sale del catalogo del GameManager,
	# que es la unica fuente de verdad.
	ventana.titulo.text = GameManager.APPS[indice]["nombre"]

	# Cada app puede definir donde se abre (posicion_ventana en su Inspector).
	# Si no lo hace, se escalona automaticamente.
	if ventana.app.posicion_ventana.x >= 0.0:
		ventana.position = ventana.app.posicion_ventana
	else:
		ventana.position = POSICION_INICIAL + OFFSET_VENTANA * _abiertas_historicas
		_abiertas_historicas += 1

	_ventanas[indice] = ventana
	ventana.cerrada.connect(_al_cerrar_ventana.bind(indice))


func _al_cerrar_ventana(_app, indice: int) -> void:
	_ventanas.erase(indice)


# --- Cartel de oferta ---
# El juego no te esta ayudando: te esta vendiendo algo.

func _al_ofrecer_app(_indice: int, titulo: String, texto: String, boton: String) -> void:
	cartel.get_node("Titulo").text = titulo
	cartel.get_node("Texto").text = texto
	cartel.get_node("BotonAceptar").text = boton
	cartel.show()


func _al_aceptar_oferta() -> void:
	cartel.hide()
	GameManager.aceptar_oferta()


# --- Perder ---
# Primera caida a 0: un tropiezo, se sigue jugando.
# Segunda caida: se acabo el dia y se empieza de nuevo.

func _al_fallar() -> void:
	tropiezo.show()
	# TODO: sonido feo aca (fase de audio)
	await get_tree().create_timer(3.0).timeout
	tropiezo.hide()
	GameManager.revivir(30.0)


func _al_arruinar_dia() -> void:
	_cerrar_todas_las_ventanas()
	cartel.hide()
	tropiezo.hide()
	fin_dia.show()


func _al_empezar_nuevo_dia() -> void:
	fin_dia.hide()
	GameManager.reiniciar()

	# Dentro de la habitacion recargamos la escena entera: el jugador
	# vuelve a despertarse con el despertador, y todo se resetea solo.
	if get_parent() != get_tree().root:
		await SceneLoader.cambiar_escena("res://escenas/01_habitacion/habitacion.tscn")
		return

	# Corriendo el escritorio solo (F6), reseteamos a mano para poder probar
	for i in range(GameManager.APPS.size()):
		_actualizar_icono(i)

	_abiertas_historicas = 0
	_minutos = 8 * 60.0
	GameManager.iniciar_sesion_pc()


func _cerrar_todas_las_ventanas() -> void:
	for indice in _ventanas.keys():
		if is_instance_valid(_ventanas[indice]):
			_ventanas[indice].queue_free()
	_ventanas.clear()


# La llama la habitacion en el corte de luz.
# Ocultar el escritorio NO alcanza: las apps siguen vivas adentro del
# SubViewport, sus scripts corren y sus reproductores siguen sonando.
# Hay que cerrarlas de verdad.
func cortar_todo() -> void:
	for indice in _ventanas.keys():
		var v = _ventanas[indice]
		if not is_instance_valid(v):
			continue
		# detener() apaga la capa de audio de esa app en el AudioManager
		if v.app and is_instance_valid(v.app):
			v.app.detener()
		v.queue_free()

	_ventanas.clear()
	_abiertas_historicas = 0

	cartel.hide()
	tropiezo.hide()
	fin_dia.hide()

	_crear_panel_debug()

	AudioManager.silenciar_todo()


# ============================================================
#  SOLO PARA PROBAR — sacar antes de la entrega (fase I)
# ============================================================

# Salta directo al colapso, sin jugar la partida entera.
func _forzar_colapso() -> void:
	GameManager.apps_desbloqueadas = GameManager.APPS.size()
	GameManager.etapa_final = true
	GameManager.dopamina = 1.0


# Desbloquea las 7 apps de una y llena la barra, para poder probar
# las mecanicas sin la presion del drenaje acumulado.
func _desbloquear_todo() -> void:
	GameManager.apps_desbloqueadas = GameManager.APPS.size()
	GameManager.dopamina = GameManager.DOPAMINA_MAX
	for i in range(GameManager.APPS.size()):
		_actualizar_icono(i)
	cartel.hide()
	print("[debug] todas las apps desbloqueadas")


# Frena o reanuda el drenaje, para mirar una app con calma.
func _alternar_drenaje() -> void:
	GameManager.activo = not GameManager.activo
	print("[debug] drenaje ", "activo" if GameManager.activo else "FRENADO")


# ============================================================
#  PANEL DE BALANCEO — sacar antes de la entrega (fase I)
# ============================================================
#
# Sin estos dos numeros, balancear es adivinar. Con ellos es leer:
#
#   DRENAJE   = cuanto se pierde por segundo
#   PRODUCE   = cuanto genera el jugador por segundo
#   BALANCE   = produce / drenaje
#
# El objetivo es que BALANCE ronde 1.15 - 1.20 (o sea, el drenaje es
# ~85% de lo que se produce). Arriba de 1.4 le sobra al jugador;
# abajo de 1.0 es imposible.

func _crear_panel_debug() -> void:
	_panel_debug = Label.new()
	_panel_debug.add_theme_font_size_override("font_size", 18)
	_panel_debug.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	_panel_debug.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel_debug.add_theme_constant_override("outline_size", 6)
	_panel_debug.position = Vector2(24, 96)
	_panel_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_debug.visible = false
	add_child(_panel_debug)


func _actualizar_debug() -> void:
	var drenaje := GameManager.drenaje_actual()
	var produce := GameManager.produccion_por_segundo
	var balance := produce / drenaje if drenaje > 0.01 else 0.0

	var veredicto := "IMPOSIBLE"
	if balance >= 1.40:
		veredicto = "le sobra"
	elif balance >= 1.05:
		veredicto = "OK"
	elif balance >= 0.95:
		veredicto = "al limite"

	_panel_debug.text = "\n".join([
		"[D] debug",
		"dopamina   %.0f" % GameManager.dopamina,
		"drenaje    %.2f /s" % drenaje,
		"produce    %.2f /s" % produce,
		"balance    %.2f  (%s)" % [balance, veredicto],
		"apps       %d de %d" % [GameManager.apps_desbloqueadas, GameManager.APPS.size()],
		"final      %s" % str(GameManager.etapa_final),
	])
