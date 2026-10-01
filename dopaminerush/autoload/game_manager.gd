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

# El codigo de verificacion de Mercado Libre. La app lo genera y el
# CELULAR DE LA HABITACION lo muestra, asi que tienen que hablarse —
# pero son dos escenas distintas que no se conocen. Pasa por aca, que
# es el unico punto de contacto que las apps tienen permitido.
signal codigo_pedido(codigo: String)   # llego un codigo al telefono
signal codigo_resuelto()               # ya se uso: el telefono se apaga

# ---- CATALOGO DE APPS ----
# El orden es el orden en que se van ofreciendo.
#
# LINKEDOUT NO ESTA ACA, A PROPOSITO. Este catalogo es de apps que se
# OFRECEN y se desbloquean: el juego te las vende, vos aceptas, suben el
# drenaje. LinkedOut no se ofrece ni se desbloquea — se abre sola desde
# el primer minuto y no tiene icono. Meterla aca obligaba a ofrecerte
# "activar tu perfil" para una app que hacia diez minutos que te
# molestaba, y ataba la etapa final a aceptar esa oferta fantasma.
# Vive entera en escritorio.gd, con su propio reloj.
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
		"nombre": "Family Savings\u2122",
		"titulo": "¿Aburrido?",
		"texto": "Family Savings\u2122 — tu primer giro es gratis.",
		"boton": "Jugar ahora",
	},
	{
		"id": "racha",
		"nombre": "Preguntados",
		"titulo": "5 minutos por día",
		"texto": "Aprendé algo nuevo. No rompas tu racha.",
		"boton": "Empezar",
	},
	{
		"id": "subway",
		"nombre": "Subway Slop",
		"titulo": "¿Te cuesta concentrarte?",
		"texto": "Poné algo de fondo. Todos lo hacen.",
		"boton": "Reproducir",
	},
	{
		"id": "ofertas",
		"nombre": "Mercado Libre",
		"titulo": "Ofertas por tiempo limitado",
		"texto": "Se están agotando. No te lo pierdas.",
		"boton": "Ver ofertas",
	},
	{
		"id": "musica",
		"nombre": "Loopify",
		"titulo": "Tu sesión se siente lenta",
		"texto": "Recomendado para vos: Loopify mientras navegás.",
		"boton": "Activar",
	},
]

# ---- NUMEROS DE BALANCEO ----
# Estos son LOS UNICOS numeros que se tocan al balancear. Ver paso 45.
const DOPAMINA_MAX: float = 100.0

# EL MARCO PARA BALANCEAR:
# el drenaje tiene que ser ~85% de lo que el jugador produce si atiende
# bien TODO lo que tiene abierto. Arriba de 100% es imposible; abajo de
# 70% le sobra. Y "lo que produce" se mide en dopamina por segundo de
# RELOJ, no por click.
#
# La escalada la produce el DESBLOQUEO DE APPS, no el paso del tiempo.
# Antes la rampa temporal sumaba 30/seg a los 10 minutos y tapaba todo
# lo demas, incluida la luna de miel. Ahora es solo un empujoncito.
const DRENAJE_INICIAL: float = 3.5        # dopamina perdida por segundo al empezar
const RAMPA: float = 0.008                # cuanto sube el drenaje por cada segundo
const DRENAJE_POR_APP: float = 3.2        # salto extra al desbloquear cada app

const UMBRAL_OFERTA: float = 0.35         # se ofrece app nueva bajo este % de dopamina
const TIEMPO_MIN_ENTRE_OFERTAS: float = 25.0   # para no encadenar carteles
const TIEMPO_MAX_SIN_OFERTA: float = 100.0     # tope: se ofrece igual aunque juegue bien

const ESPERA_ETAPA_FINAL: float = 30.0    # segundos tras la ultima app
const RAMPA_FINAL: float = 0.8            # rampa brutal de la etapa final

# ---- BUFF DEL VAPE ----
# Mientras dura, el drenaje se multiplica por esto (menos de 1 = alivio).
# El vape no es un power-up: es una forma de dejar de tocar el mouse
# unos segundos. El alivio es chico a proposito. Lo que de verdad
# ayuda es que el drenaje se congela mientras dura la animacion.
const BUFF_VAPE_MULT: float = 0.9         # -10% de drenaje
const BUFF_VAPE_DURACION: float = 15.0

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
var buff_vape: float = 0.0        # segundos que le quedan al buff
var _oferta_pendiente: bool = false
var _tolerancia: Dictionary = {}          # id de app -> multiplicador

# Congela el drenaje sin terminar la partida. Lo usa el vape: si no,
# los segundos de animacion te dejan sin barra y nunca conviene usarlo.
var drenaje_pausado: bool = false

# Multiplicador de drenaje que puede pisar una app mientras esta abierta.
# Lo usa LinkedOut, que se abre sola: perder por algo que no depende de
# vos frustra en vez de tensar, asi que mientras molesta el drenaje corre
# mas lento. Cada app que lo toca tiene que devolverlo a 1.0 al cerrarse.
var mult_drenaje_externo: float = 1.0

# Y otro para cuando el jugador esta mirando el celular. Va SEPARADO del
# de arriba a proposito: si los dos escribieran la misma variable, abrir
# LinkedOut mientras mirás el codigo pisaria el alivio del celular y al
# terminar la animacion se restauraria el valor equivocado.
var mult_drenaje_celular: float = 1.0

# Cuanta dopamina esta generando el jugador por segundo. Es el dato que
# hace falta para balancear: sin esto, ajustar numeros es adivinar.
const VENTANA_MEDICION: float = 2.0
var produccion_por_segundo: float = 0.0
var _produccion_acumulada: float = 0.0
var _tiempo_medicion: float = 0.0


func _process(delta: float) -> void:
	if not activo:
		return

	# Medicion de produccion, para el panel de debug
	_tiempo_medicion += delta
	if _tiempo_medicion >= VENTANA_MEDICION:
		produccion_por_segundo = _produccion_acumulada / _tiempo_medicion
		_produccion_acumulada = 0.0
		_tiempo_medicion = 0.0

	# Mientras esta pausado no corre nada: ni drenaje, ni rampa, ni ofertas
	if drenaje_pausado:
		return

	_tiempo_total += delta

	# La luna de miel se va agotando sola
	if _luna_miel > 0.0:
		_luna_miel = max(0.0, _luna_miel - delta)

	# El buff del vape tambien
	if buff_vape > 0.0:
		buff_vape = max(0.0, buff_vape - delta)

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

	# El vape alivia el drenaje un rato
	if buff_vape > 0.0:
		d *= BUFF_VAPE_MULT

	# Y una app abierta puede aliviarlo tambien (LinkedOut), igual que
	# el rato que pasas mirando el celular (Mercado Libre). Se multiplican
	# los dos: si pasan a la vez, los dos alivios valen.
	d *= mult_drenaje_externo * mult_drenaje_celular

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

	if real > 0.0:
		_produccion_acumulada += real

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


# La llama la habitacion cuando el jugador termina de vapear.
func aplicar_buff_vape(duracion: float = BUFF_VAPE_DURACION) -> void:
	buff_vape = duracion


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
	buff_vape = 0.0
	_oferta_pendiente = false
	drenaje_pausado = false
	mult_drenaje_externo = 1.0
	mult_drenaje_celular = 1.0
	produccion_por_segundo = 0.0
	_produccion_acumulada = 0.0
	_tiempo_medicion = 0.0
	_tolerancia.clear()
