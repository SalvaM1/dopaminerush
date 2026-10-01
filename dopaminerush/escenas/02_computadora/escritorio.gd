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
	"res://escenas/03_apps/app_04_racha/app_racha.tscn",    # 2 - Preguntados (racha)
	"res://escenas/03_apps/app_03_subway/app_subway.tscn",  # 3 - Subway Slop
	"res://escenas/03_apps/app_05_ofertas/app_ofertas.tscn",  # 4 - Mercado Libre
	"",  # 5 - Loopify      (musica)
]

# ---- LINKEDOUT: LA QUE SE ABRE SOLA ----
# NO ES UNA APP DEL CATALOGO Y POR ESO NO ESTA ARRIBA. No se ofrece, no
# se desbloquea, no tiene icono y no cuenta para la etapa final: molesta
# desde que se abre el escritorio. Tiene su propia escena, su propio
# nombre y su propia funcion para abrirse, separadas de las otras seis.
#
# Toda la escalada vive aca y no en la app, porque la app se instancia
# de cero en cada aparicion y no podria acordarse de cuantas veces
# molesto.
#
# EL RITMO. Al principio cada 30 s, que es bastante: todavia hay una
# sola app y el jugador tiene aire. A medida que se desbloquean apps el
# intervalo se acorta hasta 15 s, asi que la app aparece mas seguido
# justo cuando ya hay varias ventanas peleando por la atencion. Son dos
# numeros y nada mas, para que el balanceo por playtest sea facil.
#
# Y hay dos frenos para que la app tense en vez de frustrar:
#   - mientras esta abierta el reloj se CONGELA: ignorarla no acumula
#     apariciones esperando en fila
#   - no aparece si la dopamina esta por el piso, y el reloj ni corre en
#     ese caso: perder la partida por una ventana que se abrio sola
#     seria frustrante, no tenso
const ESCENA_LINKEDOUT := "res://escenas/03_apps/app_07_linkedin/app_linkedin.tscn"
const NOMBRE_LINKEDOUT := "LinkedOut"

# Clave con la que se guarda su ventana en _ventanas. Es negativa para
# dejar claro que NO es un indice del catalogo: ahi solo hay 0..5.
const CLAVE_LINKEDOUT: int = -1

const INTERVALO_LINKEDOUT: float = 30.0     # al empezar
const INTERVALO_MINIMO_LINKEDOUT: float = 15.0   # con todas las apps
const UMBRAL_LINKEDOUT: float = 0.25        # no molesta bajo este % de dopamina

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

# Escalada de LinkedOut
var _reloj_linkedout: float = INTERVALO_LINKEDOUT
var _apariciones_linkedout: int = 0
var _hay_linkedout: bool = false

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

	_hay_linkedout = ResourceLoader.exists(ESCENA_LINKEDOUT)
	if not _hay_linkedout:
		push_warning("No se encontro la escena de LinkedOut: " + ESCENA_LINKEDOUT)

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

	_revisar_linkedout(delta)

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


# --- LinkedOut: la app que se abre sola ---

func _revisar_linkedout(delta: float) -> void:
	# Ojo: NO se comprueba esta_desbloqueada(). LinkedOut no se desbloquea
	# nunca: molesta desde el primer minuto.
	if not GameManager.activo or not _hay_linkedout:
		return

	# Ya esta abierta: el reloj se congela. Ignorarla no acumula
	# apariciones, asi que dejarla ahi nunca sale peor que cerrarla.
	if _ventanas.has(CLAVE_LINKEDOUT) and is_instance_valid(_ventanas[CLAVE_LINKEDOUT]):
		return

	# Con la dopamina por el piso no molesta, y el reloj tampoco corre:
	# no se le acumula una aparicion para el segundo en que se recupere.
	if GameManager.dopamina / GameManager.DOPAMINA_MAX < UMBRAL_LINKEDOUT:
		return

	_reloj_linkedout -= delta
	if _reloj_linkedout <= 0.0:
		_abrir_linkedout()


# Abre su ventana por su cuenta, sin pasar por _abrir_app(): esa funcion
# es para las apps del catalogo y lo primero que hace es comprobar que
# esten desbloqueadas, cosa que LinkedOut nunca va a estar.
func _abrir_linkedout() -> void:
	_apariciones_linkedout += 1
	_reloj_linkedout = _intervalo_linkedout_actual()

	var escena: PackedScene = load(ESCENA_LINKEDOUT)
	if escena == null:
		push_warning("No se pudo cargar LinkedOut: " + ESCENA_LINKEDOUT)
		return

	var ventana := VENTANA.instantiate()
	contenedor.add_child(ventana)
	ventana.abrir(escena)
	ventana.titulo.text = NOMBRE_LINKEDOUT

	if ventana.app.posicion_ventana.x >= 0.0:
		ventana.position = ventana.app.posicion_ventana
	else:
		ventana.position = POSICION_INICIAL

	# Por encima de todas las ventanas: para eso se abre sola.
	contenedor.move_child(ventana, -1)

	_ventanas[CLAVE_LINKEDOUT] = ventana
	ventana.cerrada.connect(_al_cerrar_ventana.bind(CLAVE_LINKEDOUT))

	# La app no sabe cuando le toca aparecer: se lo decimos. En la etapa
	# final la pagina agresiva sale siempre, es cuando deja de fingir.
	if ventana.app.has_method("mostrar_aparicion"):
		ventana.app.mostrar_aparicion(_apariciones_linkedout, GameManager.etapa_final)


# Cuanto falta para la proxima aparicion. Arranca en 30 s y se acorta
# hasta 15 a medida que el jugador desbloquea apps: la app aparece mas
# seguido justo cuando ya hay varias ventanas peleando por la atencion.
func _intervalo_linkedout_actual() -> float:
	var total: int = GameManager.APPS.size() - 1
	var progreso: float = 0.0
	if total > 0:
		progreso = float(GameManager.apps_desbloqueadas - 1) / float(total)
	if GameManager.etapa_final:
		progreso = 1.0

	return lerp(
		INTERVALO_LINKEDOUT,
		INTERVALO_MINIMO_LINKEDOUT,
		clamp(progreso, 0.0, 1.0)
	)


func _reiniciar_linkedout() -> void:
	_apariciones_linkedout = 0
	_reloj_linkedout = INTERVALO_LINKEDOUT


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
	_reiniciar_linkedout()
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
	_reiniciar_linkedout()

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

	# EL VAPE SE ENTERA POR LA SEÑAL, NO POR LA VARIABLE. Este atajo
	# escribia apps_desbloqueadas a mano y nadie se enteraba, asi que
	# desbloqueaba las apps pero dejaba el vape trabado.
	#
	# Se emite aunque ya estuvieran desbloqueadas: los tres que escuchan
	# (el vape, la barra y los iconos) se protegen solos, y asi el atajo
	# funciona siempre, incluso despues de haber usado el de colapso.
	GameManager.app_desbloqueada.emit(GameManager.apps_desbloqueadas - 1)

	print("[debug] todas las apps desbloqueadas + vape")


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
