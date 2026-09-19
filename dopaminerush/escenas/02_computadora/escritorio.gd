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
	"",  # 1 - Family Savings  (slots)
	"",  # 2 - Subway Slop     (subway)
	"",  # 3 - Chatly          (chat)
	"",  # 4 - Loopify         (musica)
	"",  # 5 - PingMe          (notificaciones)
	"",  # 6 - StreamPlus      (serie)
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
const VELOCIDAD_RELOJ: float = 2
var _minutos: float = 8 * 60.0   # arranca a las 08:00

# indice de app -> ventana abierta
var _ventanas: Dictionary = {}
var _abiertas_historicas: int = 0

var _barra_iconos: Node


func _ready() -> void:
	# find_child busca en todo el arbol, asi funciona este o no dentro
	# de un Panel de fondo.
	print("Viewport: ", get_viewport().get_visible_rect().size)
	print("Ventana OS: ", DisplayServer.window_get_size())
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

	if get_parent() == get_tree().root:
		GameManager.iniciar_sesion_pc()


func _process(delta: float) -> void:
	_minutos += delta * VELOCIDAD_RELOJ
	var h := int(_minutos / 60.0) % 24
	var m := int(_minutos) % 60
	reloj.text = "%02d:%02d" % [h, m]

	# --- SOLO PARA PROBAR — sacar antes de la entrega ---
	if Input.is_physical_key_pressed(KEY_O) and not GameManager.etapa_final:
		_forzar_colapso()

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
	print("Abriendo app ", indice, " -> ruta: '", ruta, "'")
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

	# Si estamos dentro de la habitación, recargamos la escena entera:
	# el jugador vuelve a despertarse con el despertador.
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
	
# SOLO PARA PROBAR. Salta directo al colapso.
func _forzar_colapso() -> void:
	GameManager.apps_desbloqueadas = GameManager.APPS.size()
	GameManager.etapa_final = true
	GameManager.dopamina = 1.0
