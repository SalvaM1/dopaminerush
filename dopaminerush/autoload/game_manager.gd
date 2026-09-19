extends Node

# Autoload central del juego. Registrado como "GameManager".
# Es el unico que sabe cuanta dopamina hay, que apps estan desbloqueadas
# y cuando el juego colapsa. Los demas nodos hablan solo con este.
#
# ESCALADA (como funciona):
#   1. El drenaje sube CONTINUAMENTE con el tiempo (rampa). Nunca da un salto brusco.
#   2. Cuando la dopamina baja del umbral, el juego OFRECE una app nueva (cartel).
#   3. El jugador acepta -> la app se desbloquea y vuelve a flote, pero apenas.
#   4. Cuando ya no quedan apps que ofrecer, arranca la etapa final: imposible por diseño.

# ---- SEÑALES ----
signal dopamina_cambio(valor_actual: float, maximo: float)
signal oferta_app(indice: int, titulo: String, texto: String, boton: String)
signal app_desbloqueada(indice: int)
signal etapa_final_iniciada()
signal colapso()          # se llega a 0 en la etapa final -> corte de luz
signal fallo_temprano()   # primera vez que se llega a 0 -> tropiezo, se sigue
signal dia_arruinado()    # segunda vez -> game over, se reinicia el dia

# ---- CATALOGO DE APPS ----
# El orden es el orden en que se van ofreciendo.
const APPS := [
	{
		"id": "scroll",
		"nombre": "TikBrainRot",
		"titulo": "",
		"texto": "",
		"boton": "",
	},
	{
		"id": "slots",
		"nombre": "Family Savings™",
		"titulo": "¿Aburrido?",
		"texto": "Family Savings™ - ¡A que no te animas a apostar la casa de tu abuela!",
		"boton": "Jugar ahora",
	},
	{
		"id": "subway",
		"nombre": "Subway Slop",
		"titulo": "¿Te cuesta concentrarte?",
		"texto": "Poné algo de fondo. Todos lo hacen.",
		"boton": "Reproducir",
	},
	{
		"id": "chat",
		"nombre": "Chatly",
		"titulo": "3 personas te están hablando",
		"texto": "No los dejes esperando.",
		"boton": "Responder",
	},
	{
		"id": "musica",
		"nombre": "Loopify",
		"titulo": "Tu sesión se siente lenta",
		"texto": "Recomendado para vos: Loopify mientras navegás.",
		"boton": "Activar",
	},
	{
		"id": "notificaciones",
		"nombre": "PingMe",
		"titulo": "Te estás perdiendo cosas",
		"texto": "Activá PingMe para no perderte nada.",
		"boton": "Permitir",
	},
]

# ---- NUMEROS DE BALANCEO ----
# Estos son LOS UNICOS numeros que se tocan al balancear. Ver paso 45.
const DOPAMINA_MAX: float = 100.0

const DRENAJE_INICIAL: float = 2.0        # dopamina perdida por segundo al empezar
const RAMPA: float = 0.05                 # cuanto sube el drenaje por cada segundo
const DRENAJE_POR_APP: float = 1.4        # salto extra al desbloquear cada app

const UMBRAL_OFERTA: float = 0.35         # se ofrece app nueva bajo este % de dopamina
const TIEMPO_MIN_ENTRE_OFERTAS: float = 25.0   # para no encadenar carteles
const TIEMPO_MAX_SIN_OFERTA: float = 100.0     # tope: se ofrece igual aunque juegue bien

const ESPERA_ETAPA_FINAL: float = 30.0    # segundos tras la ultima app
const RAMPA_FINAL: float = 0.8            # rampa brutal de la etapa final

# ---- LUNA DE MIEL ----
# Al desbloquear una app, el drenaje baja de golpe y vuelve a su valor normal
# de a poco. Da un respiro y le pone ritmo al juego: tension -> alivio -> tension.
const LUNA_MIEL_DURACION: float = 20.0    # cuanto dura el alivio
const LUNA_MIEL_ALIVIO: float = 0.45      # el drenaje cae a este % al desbloquear

# ---- TOLERANCIA (capa opcional, ver paso 46) ----
# Con esto en false, todas las apps rinden siempre igual.
# Se enciende SOLO si tras balancear la rampa el juego no se siente bien.
const USAR_TOLERANCIA: bool = false
const TOLERANCIA_MINIMA: float = 0.35     # una app nunca rinde menos que esto
const TOLERANCIA_CAIDA: float = 0.004     # cuanto pierde por uso

# ---- ESTADO ----
var dopamina: float = DOPAMINA_MAX
var activo: bool = false
var tropiezos: int = 0                    # solo se permite UNO por partida
var apps_desbloqueadas: int = 1           # la primera arranca desbloqueada
var etapa_final: bool = false

var _tiempo_total: float = 0.0
var _tiempo_desde_oferta: float = 0.0
var _tiempo_sin_apps_nuevas: float = 0.0
var _tiempo_en_final: float = 0.0
var _luna_miel: float = 0.0
var _oferta_pendiente: bool = false
var _tolerancia: Dictionary = {}          # id de app -> multiplicador


func _process(delta: float) -> void:
	if not activo:
		return

	_tiempo_total += delta

	# La luna de miel se va agotando sola
	if _luna_miel > 0.0:
		_luna_miel = max(0.0, _luna_miel - delta)

	# 1. Drenaje continuo
	dopamina -= drenaje_actual() * delta
	dopamina = clamp(dopamina, 0.0, DOPAMINA_MAX)
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)

	# 2. ¿Se acabo?
	if dopamina <= 0.0:
		activo = false
		if etapa_final:
			colapso.emit()
		elif tropiezos == 0:
			tropiezos += 1
			fallo_temprano.emit()
		else:
			# Segunda caida: se acabo el dia.
			dia_arruinado.emit()
		return

	# 3. ¿Corresponde ofrecer una app nueva?
	_revisar_oferta(delta)

	# 4. ¿Arranca la etapa final?
	_revisar_etapa_final(delta)


# Cuanta dopamina se pierde por segundo AHORA MISMO.
func drenaje_actual() -> float:
	var d := DRENAJE_INICIAL
	d += _tiempo_total * RAMPA                          # rampa continua
	d += (apps_desbloqueadas - 1) * DRENAJE_POR_APP     # cada app sube el piso
	if etapa_final:
		d += _tiempo_en_final * RAMPA_FINAL             # ya no hay vuelta

	# Luna de miel: arranca en LUNA_MIEL_ALIVIO y sube suave hasta 1.0.
	# El retorno es gradual para que no se sienta "se acabo el bonus",
	# sino "esta app tambien dejo de alcanzar".
	if _luna_miel > 0.0:
		var t := _luna_miel / LUNA_MIEL_DURACION   # va de 1.0 a 0.0
		d *= lerp(1.0, LUNA_MIEL_ALIVIO, t)

	return d


func _revisar_oferta(delta: float) -> void:
	if _oferta_pendiente or apps_desbloqueadas >= APPS.size():
		return

	_tiempo_desde_oferta += delta
	if _tiempo_desde_oferta < TIEMPO_MIN_ENTRE_OFERTAS:
		return

	var en_problemas := (dopamina / DOPAMINA_MAX) < UMBRAL_OFERTA
	var demasiado_tiempo := _tiempo_desde_oferta >= TIEMPO_MAX_SIN_OFERTA

	if en_problemas or demasiado_tiempo:
		_oferta_pendiente = true
		var datos: Dictionary = APPS[apps_desbloqueadas]
		oferta_app.emit(
			apps_desbloqueadas,
			datos["titulo"],
			datos["texto"],
			datos["boton"]
		)


func _revisar_etapa_final(delta: float) -> void:
	if etapa_final:
		_tiempo_en_final += delta
		return

	if apps_desbloqueadas < APPS.size():
		return

	_tiempo_sin_apps_nuevas += delta
	if _tiempo_sin_apps_nuevas >= ESPERA_ETAPA_FINAL:
		etapa_final = true
		_tiempo_en_final = 0.0
		etapa_final_iniciada.emit()


# La llama el escritorio cuando el jugador aprieta el boton del cartel.
func aceptar_oferta() -> void:
	if not _oferta_pendiente:
		return
	var indice := apps_desbloqueadas
	apps_desbloqueadas += 1
	_oferta_pendiente = false
	_tiempo_desde_oferta = 0.0
	_luna_miel = LUNA_MIEL_DURACION
	app_desbloqueada.emit(indice)


# Las apps llaman a esto. Es su UNICA forma de comunicarse con el nucleo.
# id_app sirve para la tolerancia; si no se pasa, no se aplica.
func sumar_dopamina(cantidad: float, id_app: String = "") -> void:
	if not activo:
		return

	var real := cantidad
	if USAR_TOLERANCIA and id_app != "":
		real *= _consumir_tolerancia(id_app)

	dopamina = clamp(dopamina + real, 0.0, DOPAMINA_MAX)
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)


# Devuelve el multiplicador actual de una app y lo baja un poco.
func _consumir_tolerancia(id_app: String) -> float:
	if not _tolerancia.has(id_app):
		_tolerancia[id_app] = 1.0
	var factor: float = _tolerancia[id_app]
	_tolerancia[id_app] = max(TOLERANCIA_MINIMA, factor - TOLERANCIA_CAIDA)
	return factor


func esta_desbloqueada(indice: int) -> bool:
	return indice < apps_desbloqueadas


# Se llama cuando el jugador se sienta en la computadora.
func iniciar_sesion_pc() -> void:
	activo = true


# Se usa despues del fallo temprano, para retomar el juego.
func revivir(valor: float = 30.0) -> void:
	dopamina = valor
	activo = true
	dopamina_cambio.emit(dopamina, DOPAMINA_MAX)


func reiniciar() -> void:
	dopamina = DOPAMINA_MAX
	activo = false
	apps_desbloqueadas = 1
	etapa_final = false
	tropiezos = 0
	_tiempo_total = 0.0
	_tiempo_desde_oferta = 0.0
	_tiempo_sin_apps_nuevas = 0.0
	_tiempo_en_final = 0.0
	_luna_miel = 0.0
	_oferta_pendiente = false
	_tolerancia.clear()
