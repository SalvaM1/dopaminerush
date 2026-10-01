extends AppBase

# ============================================================
#  LinkedOut — la app que no pediste abrir
# ============================================================
#
# Es la unica app que NO se abre desde su icono, y la unica que no se
# desbloquea: no esta en el catalogo de GameManager.APPS. La abre el
# escritorio, sola, por encima de todas las ventanas, desde el primer
# minuto. Toda la escalada (cada cuanto aparece) vive en escritorio.gd.
#
# QUE APORTA: interrupcion. No da dopamina (da una miga al cerrarla) ni
# tiene nada para hacer adentro. Lo que te saca no es lo que muestra:
# es el tiempo y la atencion que te roba mientras las otras seis apps
# se siguen cayendo.
#
# LO QUE MUESTRA: capturas reales de LinkedIn, que van rotando al azar.
# Usar capturas de verdad en vez de recrear la interfaz con nodos es lo
# que hace que se reconozca en un segundo. Las imagenes viven en
# assets/ui/ y se pueden agregar o cambiar sin tocar el codigo: alcanza
# con sumar el nombre del archivo a CAPTURAS.
#
# DOS CONCESIONES AL JUGADOR. Perder por algo que no depende de vos
# frustra en vez de tensar, asi que mientras esta abierta:
#   - el drenaje corre 25% mas lento (GameManager.mult_drenaje_externo)
#   - el reloj de la proxima aparicion esta congelado (lo hace el escritorio)

# ---- BALANCEO ----
# Lo importante no es lo que da, es el tiempo que te robo.
const ALIVIO_DRENAJE: float = 0.75        # -25% de drenaje mientras esta abierta

# ---- LAS CAPTURAS ----
# Los nombres de archivo (sin .png) dentro de CARPETA_CAPTURAS. Si una
# falta, sale sola de la rotacion y la app sigue andando.
const CARPETA_CAPTURAS := "res://assets/ui/"
const CAPTURAS := ["feed", "empleo", "mensajes", "login"]

const SONIDOS := {
	"aparecer": "res://assets/audio/ui/popup.wav",
}

# ---- NODOS ----
@onready var captura: TextureRect = $Captura

# Sonido opcional: si el nodo no existe o no tiene archivo, silencio.
@onready var snd_aparecer: AudioStreamPlayer = get_node_or_null("Sonidos/Aparecer")

# ---- ESTADO ----
# Estatica: la app se instancia de cero en cada aparicion, asi que una
# variable normal se olvidaria de todo. Con esta no repite dos veces
# seguidas la misma captura en toda la partida.
static var _ultima_captura: String = ""

var _alivio_puesto: bool = false
var _miga_dada: bool = false


func _ready() -> void:
	_cargar_sonidos()

	# Si la abrio el escritorio, enseguida llama a mostrar_aparicion() y
	# rota de nuevo; pasa en el mismo frame, asi que no se ve ningun
	# parpadeo. Corriendo sola con F6 esto es todo lo que hay, y alcanza
	# para probar.
	_mostrar_captura()

	await get_tree().process_frame
	if not esta_activa:
		iniciar()


# ============================================================
#  Contrato de AppBase
# ============================================================

func iniciar() -> void:
	super()
	_poner_alivio()
	Juice.sonar(snd_aparecer)


# La miga de dopamina se da ACA y no en un boton propio porque la accion
# premiada de esta app es cerrarla: es la unica que te paga por irte.
# Va antes de super(), que es lo que apaga esta_activa y bloquea
# recompensar().
func detener() -> void:
	_dar_miga()
	_soltar_alivio()
	super()


# Red de seguridad: el escritorio tiene caminos que liberan la ventana
# sin pasar por detener() (el fin del dia, por ejemplo). Si el alivio
# quedara puesto, el drenaje seguiria 25% mas lento para siempre.
func _exit_tree() -> void:
	_soltar_alivio()


# ============================================================
#  Las capturas
# ============================================================

# La llama el escritorio justo despues de abrir la ventana. Los
# parametros son la cuenta de apariciones y si es la etapa final: hoy no
# cambian nada, pero es el punto donde engancharia cualquier variacion
# por aparicion que quieran agregar mas adelante.
func mostrar_aparicion(_numero: int = 0, _final: bool = false) -> void:
	_mostrar_captura()


# Elige una captura al azar, evitando repetir la ultima que se vio.
func _mostrar_captura() -> void:
	var disponibles := _capturas_disponibles()
	if disponibles.is_empty():
		push_warning("[LinkedOut] no hay capturas en " + CARPETA_CAPTURAS)
		return

	var elegida: String = disponibles[randi() % disponibles.size()]
	if disponibles.size() > 1:
		while elegida == _ultima_captura:
			elegida = disponibles[randi() % disponibles.size()]
	_ultima_captura = elegida

	captura.texture = load(CARPETA_CAPTURAS + elegida + ".png")
	captura.show()


func _capturas_disponibles() -> Array:
	var lista: Array = []
	for id in CAPTURAS:
		if ResourceLoader.exists(CARPETA_CAPTURAS + id + ".png"):
			lista.append(id)
	return lista


# ============================================================
#  Alivio de drenaje y miga
# ============================================================

func _poner_alivio() -> void:
	if _alivio_puesto:
		return
	_alivio_puesto = true
	GameManager.mult_drenaje_externo = ALIVIO_DRENAJE


func _soltar_alivio() -> void:
	if not _alivio_puesto:
		return
	_alivio_puesto = false
	GameManager.mult_drenaje_externo = 1.0


func _dar_miga() -> void:
	if _miga_dada:
		return
	_miga_dada = true
	recompensar()


# ============================================================
#  Audio
# ============================================================

func _cargar_sonidos() -> void:
	if snd_aparecer == null or snd_aparecer.stream != null:
		return

	var ruta: String = SONIDOS["aparecer"]
	if ResourceLoader.exists(ruta):
		snd_aparecer.stream = load(ruta)
	else:
		print("[LinkedOut] falta el sonido: ", ruta)
