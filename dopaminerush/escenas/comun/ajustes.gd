class_name Ajustes
extends RefCounted

# Lo que el juego recuerda MIENTRAS ESTA ABIERTO:
#   - los volumenes que elige el jugador en el menu (pestaña Sonido)
#   - si ya termino el juego (el menu pasa a mostrar el parque)
#
# No se guarda nada en disco, a proposito: el juego se juega una sola vez,
# y cada vez que se abre arranca de cero (la habitacion de fondo, todo al
# 100 %). Volver al menu desde los creditos si muestra el parque.
#
# Todo estatico: se usa como Ajustes.volumen("musica"), sin instancias.
#
# LOS VOLUMENES NO PISAN LA MEZCLA. Cada bus tiene su volumen afinado en
# default_bus_layout.tres (Apps -3, Ambiente -4...). El jugador elige un
# porcentaje por grupo, y eso se SUMA a la mezcla: 100 % es la mezcla tal
# cual, 50 % es 6 dB menos, 0 % es mudo.

# Los grupos que ve el jugador, con los buses que mueve cada uno. Loopify
# va por Musica, asi que el control de musica tambien la baja.
const GRUPOS := [
	{"id": "general", "nombre": "General", "buses": ["Master"]},
	{"id": "musica", "nombre": "Música", "buses": ["Musica"]},
	{"id": "videos", "nombre": "Videos", "buses": ["Video", "Slop"]},
	{"id": "tele", "nombre": "Televisión", "buses": ["Tele"]},
	{"id": "apps", "nombre": "Efectos de apps", "buses": ["Apps"]},
	{"id": "ambiente", "nombre": "Ambiente", "buses": ["Ambiente"]},
	{"id": "interfaz", "nombre": "Interfaz", "buses": ["UI"]},
]

static var _config: ConfigFile = null
static var _base := {}          # bus -> volumen de la mezcla original
static var _aplicado := false   # ya se aplicaron los volumenes del jugador


static func _cfg() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()   # vacio: todo por defecto
	return _config


# ---- VOLUMEN ----

# 0 a 1 (1 = la mezcla original)
static func volumen(grupo: String) -> float:
	return clampf(float(_cfg().get_value("audio", grupo, 1.0)), 0.0, 1.0)


static func poner_volumen(grupo: String, valor: float) -> void:
	_cfg().set_value("audio", grupo, clampf(valor, 0.0, 1.0))
	_aplicar_grupo(grupo)


# Pone todos los buses segun lo guardado. Lo llama el menu al arrancar.
static func aplicar_audio() -> void:
	_recordar_base()
	_aplicado = true
	for g in GRUPOS:
		_aplicar_grupo(g["id"])


# Cuanto le suma el jugador a un bus, en dB. Lo usa el AudioManager para
# que su agache vuelva al volumen del jugador y no al de la mezcla.
# Hasta que el menu aplica los ajustes es 0: los tests, que no pasan por
# el menu, ven siempre la mezcla original.
static func db_usuario(bus: String) -> float:
	if not _aplicado:
		return 0.0
	for g in GRUPOS:
		if bus in g["buses"]:
			var v := volumen(g["id"])
			return -80.0 if v <= 0.001 else linear_to_db(v)
	return 0.0


static func _recordar_base() -> void:
	if not _base.is_empty():
		return
	for g in GRUPOS:
		for bus in g["buses"]:
			var i := AudioServer.get_bus_index(bus)
			if i >= 0:
				_base[bus] = AudioServer.get_bus_volume_db(i)


static func _aplicar_grupo(grupo: String) -> void:
	_recordar_base()
	for g in GRUPOS:
		if g["id"] != grupo:
			continue
		var v := volumen(grupo)
		for bus in g["buses"]:
			var i := AudioServer.get_bus_index(bus)
			if i < 0 or not _base.has(bus):
				continue
			AudioServer.set_bus_mute(i, v <= 0.001)
			AudioServer.set_bus_volume_db(i, _base[bus] + (0.0 if v <= 0.001 else linear_to_db(v)))


# ---- PROGRESO ----

static func juego_completado() -> bool:
	return bool(_cfg().get_value("progreso", "completado", false))


static func marcar_completado() -> void:
	_cfg().set_value("progreso", "completado", true)
