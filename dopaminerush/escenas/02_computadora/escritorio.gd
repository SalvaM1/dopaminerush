extends CanvasLayer

# Una sola hora para la barra de tareas y la luz natural de la habitacion.
signal hora_cambio(minutos: float)
# Se abrio una app. Lleva el id y no el indice porque LinkedOut tambien
# la usa, y LinkedOut no esta en el catalogo.
signal app_abierta(id_app: String)

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
	"res://escenas/03_apps/app_06_musica/app_musica.tscn",  # 5 - Loopify
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
# ---- EL ARRANQUE ----
# Sentarse y que el escritorio YA ESTE ahi no se siente como prender una
# computadora: se siente como abrir un menu. Estos cuatro segundos de
# BIOS, logo y "iniciando sesion" son lo que convierte el monitor en una
# maquina que estaba apagada.
#
# El drenaje NO corre durante el arranque: la habitacion llama a
# iniciar_sesion_pc() recien cuando esto termina.
const LINEAS_BIOS := [
	"dopamineOS BIOS v4.08  —  (C) Dopamine Systems",
	"",
	"CPU .................. 1 nucleo, sobrecargado",
	"Memoria .............. 8192 MB  OK",
	"Atencion disponible .. verificando...",
	"Atencion disponible .. 4 segundos  OK",
	"",
	"Detectando dispositivos de entretenimiento...",
	"  1. TikBrainRot              [listo]",
	"  2. Family Savings(TM)       [listo]",
	"  3. Preguntados              [listo]",
	"  4. Subway Slop              [listo]",
	"  5. Mercado Libre            [listo]",
	"  6. Loopify                  [listo]",
	"",
	"Arrancando dopamineOS...",
]
const DEMORA_LINEA: float = 0.055      # cuanto tarda en salir cada renglon
const DURACION_LOGO: float = 1.5
const DURACION_SESION: float = 0.9

# El golpe de la pantalla azul. Se carga solo si el archivo esta; si no,
# el fin del dia pasa en silencio.
const SONIDO_PANTALLA_AZUL := "res://assets/audio/ui/pantalla_azul.mp3"

const OFFSET_VENTANA := Vector2(38, 34)
const POSICION_INICIAL := Vector2(80, 70)

@onready var contenedor: Control = $Ventanas
@onready var reloj: Label = $FondoBarra/Bandeja/Reloj
@onready var fecha: Label = $FondoBarra/Bandeja/Fecha
@onready var barra_tareas: Panel = $FondoBarra
@onready var arranque: Control = $Arranque
@onready var arranque_negro: ColorRect = $Arranque/Negro
@onready var arranque_bios: Label = $Arranque/Bios
@onready var arranque_logo: Label = $Arranque/Logo
@onready var arranque_estado: Label = $Arranque/Estado
@onready var cartel: Panel = $CartelOferta
@onready var tropiezo: ColorRect = $Tropiezo
@onready var fin_dia: Panel = $FinDia

# Cuantos minutos del juego pasan por cada segundo real
const VELOCIDAD_RELOJ: float = 12.0
const FIN_DEL_DIA: float = 23 * 60.0 + 59.0
var _minutos: float = 8 * 60.0   # arranca a las 08:00
var _hora_notificada: float = -1.0

# indice de app -> ventana abierta
var _ventanas: Dictionary = {}
var _abiertas_historicas: int = 0

var _barra_iconos: Node
var _puntos_abierta: Dictionary = {}   # indice -> el puntito de la barra
var _arrancado: bool = false
var _spinner: Control = null
var _saltar_arranque: bool = false
var _snd_pantalla_azul: AudioStreamPlayer = null

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

	_armar_puntos_abierta()
	_preparar_sonido_azul()

	# Arranca tapado por la pantalla de encendido. Dentro de la
	# habitacion el arranque lo dispara el sentarse; con F6, el de abajo.
	arranque.visible = true
	arranque_bios.text = ""
	arranque_logo.modulate.a = 0.0
	arranque_estado.text = ""

	_crear_panel_debug()
	_actualizar_reloj()

	# Si esta escena se corre SOLA (F6), arrancamos el juego nosotros.
	# Dentro de la habitacion esto no pasa: lo dispara el sentarse.
	if get_parent() == get_tree().root:
		await arrancar()
		GameManager.iniciar_sesion_pc()


func _process(delta: float) -> void:
	# El reloj solo corre con la sesion de la PC en marcha. Antes corria
	# desde que cargaba la habitacion: un minuto explorando la pieza eran
	# doce horas de juego, y se hacia de noche antes de sentarse.
	if GameManager.activo:
		_minutos = minf(FIN_DEL_DIA, _minutos + delta * VELOCIDAD_RELOJ)
	_actualizar_reloj()

	# La fecha no avanza nunca. Es el mismo dia siempre, y es a proposito.
	fecha.text = "lun 3"

	# Se puede saltear con un click o con E. El encendido esta para que
	# la primera vez se sienta una maquina de verdad, no para hacerte
	# esperar cada vez que empezas un dia nuevo.
	if arranque.visible and not _saltar_arranque:
		if (Input.is_action_just_pressed("interactuar")
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			_saltar_arranque = true

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


func obtener_minutos_del_dia() -> float:
	return _minutos


func _actualizar_reloj() -> void:
	var h := int(_minutos / 60.0) % 24
	var m := int(_minutos) % 60
	reloj.text = "%02d:%02d" % [h, m]
	if _minutos != _hora_notificada:
		_hora_notificada = _minutos
		hora_cambio.emit(_minutos)


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
	_actualizar_foco()

	_ventanas[CLAVE_LINKEDOUT] = ventana
	ventana.cerrada.connect(_al_cerrar_ventana.bind(CLAVE_LINKEDOUT))

	# La app no sabe cuando le toca aparecer: se lo decimos. En la etapa
	# final la pagina agresiva sale siempre, es cuando deja de fingir.
	if ventana.app.has_method("mostrar_aparicion"):
		ventana.app.mostrar_aparicion(_apariciones_linkedout, GameManager.etapa_final)

	app_abierta.emit("linkedout")


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
		_actualizar_foco()
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
	ventana.traida_al_frente.connect(_al_traer_al_frente)
	app_abierta.emit(GameManager.APPS[indice]["id"])

	_actualizar_puntos()
	_actualizar_foco()


func _al_cerrar_ventana(_app, indice: int) -> void:
	_ventanas.erase(indice)
	_actualizar_puntos()
	_actualizar_foco()


func _al_traer_al_frente(_ventana) -> void:
	_actualizar_foco()


# --- Cartel de oferta ---
# El juego no te esta ayudando: te esta vendiendo algo.

# Ya no es un cartel rojo en el medio: es la notificacion del sistema de
# que algo "se termino de instalar". Toda la logica de mostrarse, sonar e
# insistir esta en cartel_oferta.gd.
func _al_ofrecer_app(indice: int, titulo: String, texto: String, boton: String) -> void:
	var datos: Dictionary = GameManager.APPS[indice]
	cartel.mostrar(datos["id"], datos["nombre"], titulo, texto, boton)


func _al_aceptar_oferta() -> void:
	cartel.cerrar()
	var indice: int = GameManager.apps_desbloqueadas
	GameManager.aceptar_oferta()
	# "Se termino de instalar" + "Jugar ahora": lo natural es que la abra.
	# Antes solo la desbloqueaba, y el boton prometia algo que no hacia.
	if GameManager.esta_desbloqueada(indice):
		_abrir_app(indice)


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

	# Primero el silencio, despues el golpe. Que todo el ruido de las
	# apps se corte de una y recien ahi suene la pantalla azul es lo que
	# hace que se sienta como que algo se rompio.
	AudioManager.silenciar_todo()
	if _snd_pantalla_azul and _snd_pantalla_azul.stream:
		_snd_pantalla_azul.play()


func _preparar_sonido_azul() -> void:
	if not ResourceLoader.exists(SONIDO_PANTALLA_AZUL):
		print("[Escritorio] falta el sonido: ", SONIDO_PANTALLA_AZUL)
		return

	_snd_pantalla_azul = AudioStreamPlayer.new()
	_snd_pantalla_azul.stream = load(SONIDO_PANTALLA_AZUL)
	_snd_pantalla_azul.bus = "UI"
	add_child(_snd_pantalla_azul)


func _al_empezar_nuevo_dia() -> void:
	fin_dia.hide()
	GameManager.reiniciar()

	# Dentro de la habitacion recargamos la escena entera: el jugador
	# vuelve a despertarse con el despertador, y todo se resetea solo.
	if get_parent() != get_tree().root:
		# EXACTAMENTE lo mismo que hace el menu al empezar la partida, y a
		# proposito: el dia nuevo tiene que sentirse igual que el primero.
		# Antes usaba cambiar_escena(), que ademas funde de vuelta a la
		# vista y le pisaba el negro inicial al despertar.
		await SceneLoader.fundir_y_cambiar(
			"res://escenas/01_habitacion/habitacion.tscn", Color.BLACK, 1.0)
		return

	# Corriendo el escritorio solo (F6), reseteamos a mano para poder probar
	for i in range(GameManager.APPS.size()):
		_actualizar_icono(i)

	_abiertas_historicas = 0
	_minutos = 8 * 60.0
	_actualizar_reloj()
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
	_actualizar_puntos()

	cartel.hide()
	tropiezo.hide()
	fin_dia.hide()

	_crear_panel_debug()

	AudioManager.silenciar_todo()



# ============================================================
#  El arranque
# ============================================================
#
# Lo llama la habitacion cuando el jugador se sienta, y espera a que
# termine antes de arrancar el drenaje. Esos cuatro segundos son gratis
# a proposito: el juego todavia no empezo.

func arrancar() -> void:
	if _arrancado:
		return
	_arrancado = true

	arranque.visible = true
	arranque_negro.color.a = 1.0
	arranque_bios.text = ""
	arranque_logo.modulate.a = 0.0
	arranque_estado.text = ""

	# El escritorio todavia no se ve: entra despues.
	barra_tareas.modulate.a = 0.0
	_saltar_arranque = false

	# 1. El BIOS, renglon por renglon. Que el texto se escriba solo es
	#    lo que hace que parezca una maquina pensando y no una imagen.
	for linea in LINEAS_BIOS:
		arranque_bios.text += linea + "\n"
		await get_tree().create_timer(DEMORA_LINEA).timeout
		if _saltar_arranque:
			break

	if not _saltar_arranque:
		await get_tree().create_timer(0.35).timeout

	# 2. Se apaga el BIOS y aparece el logo con el spinner
	var t1 := create_tween()
	t1.tween_property(arranque_bios, "modulate:a", 0.0, 0.25)
	await t1.finished
	arranque_bios.visible = false

	_crear_spinner()
	var t2 := create_tween()
	t2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t2.tween_property(arranque_logo, "modulate:a", 1.0, 0.5)

	if not _saltar_arranque:
		await get_tree().create_timer(DURACION_LOGO).timeout

	# 3. Iniciando sesion
	arranque_estado.text = "Iniciando sesión..."
	arranque_estado.modulate.a = 0.0
	var t3 := create_tween()
	t3.tween_property(arranque_estado, "modulate:a", 1.0, 0.3)
	if not _saltar_arranque:
		await get_tree().create_timer(DURACION_SESION).timeout

	# 4. Se descubre el escritorio
	if _spinner:
		_spinner.queue_free()
		_spinner = null

	var t4 := create_tween()
	t4.set_parallel(true)
	t4.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t4.tween_property(arranque_logo, "modulate:a", 0.0, 0.4)
	t4.tween_property(arranque_estado, "modulate:a", 0.0, 0.4)
	t4.tween_property(arranque_negro, "color:a", 0.0, 0.6)
	await t4.finished

	arranque.visible = false

	# 5. La barra sube desde abajo y los iconos entran escalonados
	barra_tareas.position.y += 70.0
	barra_tareas.modulate.a = 1.0

	var t5 := create_tween()
	t5.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t5.tween_property(barra_tareas, "position:y", barra_tareas.position.y - 70.0, 0.45)

	for i in range(GameManager.APPS.size()):
		var boton := _barra_iconos.get_node_or_null("Icono%d" % i) as Button
		if boton == null:
			continue
		Juice.entrar(boton, 14.0, 0.26, 0.06 * i)

	# 6. La primera vez, el tutorial de la barra. arrancar() no devuelve
	#    hasta que el jugador lo cierra, y la sesion (el drenaje, el reloj)
	#    recien empieza despues: no hace falta congelar nada a la fuerza.
	await _tutorial_barra()


# ============================================================
#  Tutorial: la barra de dopamina
# ============================================================
# La unica cosa que hay que entender para jugar, y la unica que el juego
# no explicaba: hay una barra, baja sola, y las apps la suben.
#
# Es un "coach mark" como el de cualquier app: se oscurece todo menos la
# barra, una flecha le apunta, y un cartel dice que es. Sale una sola vez
# por partida (ver GameManager.tutoriales_vistos).

const COLOR_TUTORIAL := Color(1.0, 0.72, 0.25)
const BLOQUEO_TUTORIAL: float = 0.45


func _tutorial_barra() -> void:
	if not GameManager.tutorial_pendiente("barra_dopamina"):
		return
	var barra := get_node_or_null("BarraDopamina") as Control
	if barra == null:
		return
	GameManager.marcar_tutorial("barra_dopamina")

	# Que termine de entrar la barra de tareas antes de taparlo todo.
	await get_tree().create_timer(0.5).timeout

	var capa := Control.new()
	capa.name = "TutorialBarra"
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bloquea el mouse: mientras se explica no se clickea lo de atras.
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.z_index = 50
	capa.modulate.a = 0.0
	add_child(capa)

	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.62)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(sombra)

	# La barra queda POR ENCIMA de la sombra: es lo unico iluminado.
	var z_previo := barra.z_index
	barra.z_index = 60

	var rect := barra.get_global_rect()
	var origen := capa.get_global_rect().position
	var arriba := rect.position - origen
	var centro_x := rect.get_center().x - origen.x
	var abajo := rect.end.y - origen.y

	# Un aro alrededor de la barra, que late.
	var aro := Panel.new()
	var estilo_aro := StyleBoxFlat.new()
	estilo_aro.bg_color = Color(0, 0, 0, 0)
	estilo_aro.set_border_width_all(4)
	estilo_aro.border_color = COLOR_TUTORIAL
	estilo_aro.set_corner_radius_all(12)
	aro.add_theme_stylebox_override("panel", estilo_aro)
	aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aro.position = arriba - Vector2(12, 10)
	aro.size = rect.size + Vector2(24, 20)
	aro.z_index = 20
	capa.add_child(aro)

	# La flecha se dibuja: Open Sans no tiene glifos de flechas.
	var flecha := Polygon2D.new()
	flecha.color = COLOR_TUTORIAL
	flecha.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-30, 38), Vector2(-11, 38),
		Vector2(-11, 84), Vector2(11, 84), Vector2(11, 38), Vector2(30, 38),
	])
	var punta := Vector2(centro_x, abajo + 22.0)
	flecha.position = punta
	flecha.z_index = 20
	capa.add_child(flecha)

	# --- el cartel ---
	var tarjeta := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.1, 0.15, 0.97)
	estilo.set_border_width_all(3)
	estilo.border_color = COLOR_TUTORIAL
	estilo.set_corner_radius_all(22)
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 20
	estilo.shadow_offset = Vector2(0, 8)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.size = Vector2(700, 250)
	tarjeta.position = Vector2(centro_x - 350.0, punta.y + 104.0)
	tarjeta.z_index = 20
	capa.add_child(tarjeta)

	tarjeta.add_child(_texto_tutorial("TU DOPAMINA", 20, COLOR_TUTORIAL, 26.0, 52.0))
	tarjeta.add_child(_texto_tutorial("Baja sola, todo el tiempo.", 40, Color(1, 1, 1), 60.0, 116.0))
	tarjeta.add_child(_texto_tutorial(
		"Usá las apps para que vuelva a subir.", 26, Color(0.78, 0.82, 0.9), 118.0, 158.0))
	var pie := _texto_tutorial("[E]  Entendido", 24, COLOR_TUTORIAL, 192.0, 228.0)
	tarjeta.add_child(pie)

	# --- entrada ---
	tarjeta.pivot_offset = tarjeta.size * 0.5
	tarjeta.scale = Vector2(0.85, 0.85)
	var entrada := capa.create_tween()
	entrada.set_parallel(true)
	entrada.tween_property(capa, "modulate:a", 1.0, 0.3)
	entrada.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_property(tarjeta, "scale", Vector2.ONE, 0.45)

	# La flecha va y viene hacia la barra, y el aro y el pie laten.
	var vaiven := capa.create_tween().set_loops()
	vaiven.set_trans(Tween.TRANS_SINE)
	vaiven.tween_property(flecha, "position:y", punta.y + 16.0, 0.5)
	vaiven.tween_property(flecha, "position:y", punta.y, 0.5)

	var latido := capa.create_tween().set_loops()
	latido.set_trans(Tween.TRANS_SINE)
	latido.tween_property(aro, "modulate:a", 0.35, 0.6)
	latido.parallel().tween_property(pie, "modulate:a", 0.45, 0.6)
	latido.tween_property(aro, "modulate:a", 1.0, 0.6)
	latido.parallel().tween_property(pie, "modulate:a", 1.0, 0.6)

	# Una ventana muerta: la misma E (o el click) que salteo el arranque no
	# tiene que cerrar el cartel en el mismo instante en que aparece.
	await get_tree().create_timer(BLOQUEO_TUTORIAL).timeout
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interactuar"):
			break

	# --- salida ---
	var salida := capa.create_tween()
	salida.tween_property(capa, "modulate:a", 0.0, 0.25)
	await salida.finished
	barra.z_index = z_previo
	capa.queue_free()


func _texto_tutorial(texto: String, tamano: int, color: Color,
		arriba: float, abajo: float) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	etiqueta.offset_top = arriba
	etiqueta.offset_bottom = abajo
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


# La rueda de carga: el mismo arco que gira de cualquier arranque.
func _crear_spinner() -> void:
	if _spinner:
		return
	_spinner = AnilloCarga.new()
	_spinner.set_anchors_preset(Control.PRESET_CENTER)
	_spinner.offset_left = -26.0
	_spinner.offset_right = 26.0
	_spinner.offset_top = 10.0
	_spinner.offset_bottom = 62.0
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arranque.add_child(_spinner)


class AnilloCarga extends Control:
	var _angulo: float = 0.0

	func _process(delta: float) -> void:
		_angulo += delta * 4.2
		queue_redraw()

	func _draw() -> void:
		var centro := size * 0.5
		var radio: float = min(size.x, size.y) * 0.5 - 3.0
		draw_arc(centro, radio, _angulo, _angulo + TAU * 0.7, 36,
			Color(0.75, 0.78, 0.88, 0.95), 3.5, true)


# ============================================================
#  Estado de las ventanas en la barra de tareas
# ============================================================
#
# El puntito debajo del icono dice "esta app esta abierta". Es la pieza
# de interfaz que mas barata sale y mas ordena: con seis ventanas
# encimadas, es lo unico que te dice que ya la tenes abierta en algun
# lado y no hace falta volver a abrirla.

func _armar_puntos_abierta() -> void:
	for i in range(GameManager.APPS.size()):
		var boton := _barra_iconos.get_node_or_null("Icono%d" % i) as Button
		if boton == null:
			continue

		var punto := Panel.new()
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		punto.custom_minimum_size = Vector2(18, 3)
		punto.size = Vector2(18, 3)

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.45, 0.72, 1.0)
		estilo.set_corner_radius_all(2)
		punto.add_theme_stylebox_override("panel", estilo)
		punto.modulate.a = 0.0

		boton.add_child(punto)
		_puntos_abierta[i] = punto


func _actualizar_puntos() -> void:
	for i in _puntos_abierta:
		var punto: Panel = _puntos_abierta[i]
		var boton: Control = punto.get_parent()
		if not is_instance_valid(boton):
			continue

		punto.position = Vector2(boton.size.x * 0.5 - 9.0, boton.size.y - 4.0)

		var abierta: bool = _ventanas.has(i) and is_instance_valid(_ventanas[i])
		var objetivo: float = 1.0 if abierta else 0.0
		if abs(punto.modulate.a - objetivo) > 0.01:
			var t := create_tween()
			t.tween_property(punto, "modulate:a", objetivo, 0.2)


# Solo la de adelante se ve "encendida". Con seis ventanas abiertas,
# saber cual tiene el foco no es decoracion.
func _actualizar_foco() -> void:
	var frente: Node = null
	for hijo in contenedor.get_children():
		if hijo.has_method("marcar_activa"):
			frente = hijo

	for hijo in contenedor.get_children():
		if hijo.has_method("marcar_activa"):
			hijo.marcar_activa(hijo == frente)

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
