extends Node

# Autoload central del juego. Registrado como "GameManager".
# Es el unico que sabe cuanta dopamina hay y en que fase esta el juego.
# Los demas nodos NO se hablan entre si: hablan con este.

# ---- SEÑALES: los demas nodos se "suscriben" a estas ----
signal dopamina_cambio(valor_actual: float, maximo: float)
signal fase_cambio(nueva_fase: int)
signal app_desbloqueada(indice_app: int)
signal colapso()          # se llega a 0 en la fase final -> corte de luz
signal fallo_temprano()   # se llega a 0 antes de tiempo -> no termina el juego

# ---- ESTADO ----
const DOPAMINA_MAX: float = 100.0
var dopamina: float = 100.0
var fase: int = 0
var activo: bool = false   # el drenaje solo corre cuando esto es true

# ---- CONFIGURACION DE FASES ----
# drenaje  = cuanta dopamina se pierde por segundo
# duracion = cuantos segundos dura la fase antes de pasar a la siguiente
# apps     = cuantas apps estan desbloqueadas en esta fase
#
# ESTOS NUMEROS ESTAN INVENTADOS Y VAN A ESTAR MAL.
# Se ajustan en playtesting (paso 31 y paso 50). Ese es su unico proposito.
const FASES := [
	{ "drenaje": 0.0,  "duracion": 0.0,   "apps": 0 },  # fase 0: habitacion, sin drenaje
	{ "drenaje": 2.0,  "duracion": 120.0, "apps": 1 },  # fase 1: una app alcanza
	{ "drenaje": 4.5,  "duracion": 150.0, "apps": 2 },  # fase 2: hace falta la segunda
	{ "drenaje": 7.5,  "duracion": 180.0, "apps": 3 },  # fase 3: las tres, justo
	{ "drenaje": 14.0, "duracion": 120.0, "apps": 3 },  # fase 4: imposible por diseño
]

var _tiempo_en_fase: float = 0.0


func _process(delta: float) -> void:
	if not activo:
		return

	# 1. Drenaje continuo
	dopamina -= FASES[fase]["drenaje"] * delta
	dopamina = clamp(dopamina, 0.0, DOPAMINA_MAX)
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)

	# 2. Chequeo de fin
	if dopamina <= 0.0:
		activo = false
		if fase >= FASES.size() - 1:
			colapso.emit()        # final previsto: corte de luz
		else:
			fallo_temprano.emit() # tropiezo: se sigue jugando
		return

	# 3. Avance de fase por tiempo
	_tiempo_en_fase += delta
	if _tiempo_en_fase >= FASES[fase]["duracion"] and fase < FASES.size() - 1:
		avanzar_fase()


func avanzar_fase() -> void:
	if fase >= FASES.size() - 1:
		return

	fase += 1
	_tiempo_en_fase = 0.0
	fase_cambio.emit(fase)

	# Si esta fase habilita una app nueva, avisamos
	var apps_ahora: int = FASES[fase]["apps"]
	var apps_antes: int = FASES[fase - 1]["apps"]
	if apps_ahora > apps_antes:
		app_desbloqueada.emit(apps_ahora - 1)


# Las apps llaman a esto. Es su UNICA forma de comunicarse con el nucleo.
func sumar_dopamina(cantidad: float) -> void:
	if not activo:
		return
	dopamina = clamp(dopamina + cantidad, 0.0, DOPAMINA_MAX)
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)


# Se llama cuando el jugador se sienta en la computadora (paso 38).
func iniciar_sesion_pc() -> void:
	activo = true
	avanzar_fase()   # pasa de fase 0 a fase 1


# Se usa despues del fallo temprano, para retomar el juego.
func revivir(valor: float = 30.0) -> void:
	dopamina = valor
	activo = true
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)


func reiniciar() -> void:
	dopamina = DOPAMINA_MAX
	fase = 0
	_tiempo_en_fase = 0.0
	activo = false
