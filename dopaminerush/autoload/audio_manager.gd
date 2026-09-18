extends Node

# ============================================================
#  AudioManager  (autoload)
# ============================================================
#
# Maneja los sonidos NO DIEGETICOS: las capas de las apps, los efectos de
# interfaz y la musica. Son sonidos sin posicion en el mundo.
#
# Los sonidos DIEGETICOS (el despertador, el zumbido de la compu, los
# pajaros del parque) NO van aca: van como AudioStreamPlayer3D puestos en
# la escena, sobre el objeto que los produce, para que se oigan segun donde
# este parado el jugador. Para esos, este script ofrece igual las funciones
# de fundido (fundir_entrada / fundir_salida), que sirven para cualquier
# reproductor.
#
# COMO AGREGAR UN SONIDO NUEVO:
#   1. Poner el archivo en assets/audio/<carpeta>/
#   2. Agregar una entrada al catalogo SONIDOS de abajo
#   3. Llamar a iniciar_capa("id") o reproducir("id")
#   Si el archivo todavia no existe, el juego avisa por consola y sigue
#   andando en silencio: no rompe nada.

# ---- BUSES ----
const BUS_MUSICA := "Musica"
const BUS_APPS := "Apps"
const BUS_AMBIENTE := "Ambiente"
const BUS_UI := "UI"

const FUNDIDO_DEFAULT: float = 0.4
const SILENCIO_DB: float = -60.0

# ---- CATALOGO ----
# id -> ruta, bus, volumen (en dB, 0 = original), loop
# Las entradas pueden apuntar a archivos que todavia no existen.
const SONIDOS := {
	# --- capas de las apps (una por app, en loop) ---
	"scroll":          { "ruta": "res://assets/audio/apps/scroll.ogg",   "bus": BUS_APPS, "vol": -6.0 },
	"slots":           { "ruta": "res://assets/audio/apps/slots.ogg",    "bus": BUS_APPS, "vol": -6.0 },
	"subway":          { "ruta": "res://assets/audio/apps/subway.ogg",   "bus": BUS_APPS, "vol": -6.0 },
	"chat":            { "ruta": "res://assets/audio/apps/chat.ogg",     "bus": BUS_APPS, "vol": -8.0 },
	"musica":          { "ruta": "res://assets/audio/apps/musica.ogg",   "bus": BUS_MUSICA, "vol": -4.0 },
	"notificaciones":  { "ruta": "res://assets/audio/apps/pingme.ogg",   "bus": BUS_APPS, "vol": -6.0 },
	"serie":           { "ruta": "res://assets/audio/apps/serie.ogg",    "bus": BUS_APPS, "vol": -6.0 },

	# --- efectos de interfaz (cortos, no loop) ---
	"click":           { "ruta": "res://assets/audio/ui/click.wav",         "bus": BUS_UI, "vol": -4.0 },
	"oferta":          { "ruta": "res://assets/audio/ui/notificacion.wav",  "bus": BUS_UI, "vol": -2.0 },
	"error":           { "ruta": "res://assets/audio/ui/error.wav",         "bus": BUS_UI, "vol": 0.0 },
	"abrir_ventana":   { "ruta": "res://assets/audio/ui/abrir.wav",         "bus": BUS_UI, "vol": -6.0 },
	"cerrar_ventana":  { "ruta": "res://assets/audio/ui/cerrar.wav",        "bus": BUS_UI, "vol": -6.0 },
}

# id -> reproductor de la capa que esta sonando
var _capas: Dictionary = {}


# ============================================================
#  Capas (loop): las apps
# ============================================================

func iniciar_capa(id: String, fundido: float = FUNDIDO_DEFAULT) -> void:
	if _capas.has(id) and is_instance_valid(_capas[id]):
		return   # ya esta sonando

	var stream := _cargar(id)
	if stream == null:
		return

	var datos: Dictionary = SONIDOS[id]
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	reproductor.bus = datos["bus"]
	reproductor.volume_db = SILENCIO_DB
	add_child(reproductor)
	reproductor.play()

	_capas[id] = reproductor
	fundir_entrada(reproductor, fundido, datos["vol"])


func detener_capa(id: String, fundido: float = FUNDIDO_DEFAULT) -> void:
	if not _capas.has(id) or not is_instance_valid(_capas[id]):
		return

	var reproductor: AudioStreamPlayer = _capas[id]
	_capas.erase(id)
	await fundir_salida(reproductor, fundido)
	if is_instance_valid(reproductor):
		reproductor.queue_free()


# Corta TODO de golpe. Se usa en el corte de luz: de ruido maximo a
# silencio absoluto en un frame, sin fundido.
func silenciar_todo() -> void:
	for id in _capas.keys():
		if is_instance_valid(_capas[id]):
			_capas[id].queue_free()
	_capas.clear()


func esta_sonando(id: String) -> bool:
	return _capas.has(id) and is_instance_valid(_capas[id])


# ============================================================
#  Efectos cortos (no loop)
# ============================================================

func reproducir(id: String) -> void:
	var stream := _cargar(id)
	if stream == null:
		return

	var datos: Dictionary = SONIDOS[id]
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	reproductor.bus = datos["bus"]
	reproductor.volume_db = datos["vol"]
	add_child(reproductor)
	reproductor.play()
	# se borra solo al terminar
	reproductor.finished.connect(reproductor.queue_free)


# ============================================================
#  Fundidos — sirven para CUALQUIER reproductor,
#  incluidos los AudioStreamPlayer3D puestos en las escenas.
# ============================================================

func fundir_entrada(reproductor: Node, duracion: float, volumen_final: float = 0.0) -> void:
	if reproductor == null or not is_instance_valid(reproductor):
		return
	reproductor.volume_db = SILENCIO_DB
	if not reproductor.playing:
		reproductor.play()
	var tween := create_tween()
	tween.tween_property(reproductor, "volume_db", volumen_final, duracion)
	await tween.finished


func fundir_salida(reproductor: Node, duracion: float) -> void:
	if reproductor == null or not is_instance_valid(reproductor):
		return
	var tween := create_tween()
	tween.tween_property(reproductor, "volume_db", SILENCIO_DB, duracion)
	await tween.finished
	if is_instance_valid(reproductor):
		reproductor.stop()


# ============================================================
#  Volumen por bus
# ============================================================

func volumen_bus(nombre_bus: String, db: float) -> void:
	var indice := AudioServer.get_bus_index(nombre_bus)
	if indice >= 0:
		AudioServer.set_bus_volume_db(indice, db)


# ============================================================
#  Interno
# ============================================================

func _cargar(id: String) -> AudioStream:
	if not SONIDOS.has(id):
		push_warning("[AudioManager] id desconocido: " + id)
		return null

	var ruta: String = SONIDOS[id]["ruta"]
	if not ResourceLoader.exists(ruta):
		# Todavia no existe el archivo. No es un error: el juego sigue
		# funcionando en silencio hasta que alguien lo agregue.
		print("[AudioManager] falta el archivo: ", ruta)
		return null

	return load(ruta)
