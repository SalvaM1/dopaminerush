extends Control

# ESCENA DE PRUEBA — DESCARTABLE
# Sirve para validar el Bloque 1 (GameManager + barra de dopamina).
# Se borra cuando el juego real este armado.

@onready var boton_sumar: Button = $BotonSumar
@onready var boton_fase: Button = $BotonFase
@onready var info: Label = $Info


func _ready() -> void:
	boton_sumar.pressed.connect(_al_sumar)
	boton_fase.pressed.connect(_al_avanzar_fase)

	# Escuchamos las señales para ver que se estan emitiendo
	GameManager.fase_cambio.connect(_al_cambiar_fase)
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)
	GameManager.fallo_temprano.connect(_al_fallar)
	GameManager.colapso.connect(_al_colapsar)

	# Arrancamos el juego: activa el drenaje y pasa a fase 1
	GameManager.iniciar_sesion_pc()


func _process(_delta: float) -> void:
	info.text = "Fase: %d\nDopamina: %.1f\nActivo: %s" % [
		GameManager.fase,
		GameManager.dopamina,
		str(GameManager.activo)
	]


func _al_sumar() -> void:
	GameManager.sumar_dopamina(10.0)


func _al_avanzar_fase() -> void:
	GameManager.avanzar_fase()


func _al_cambiar_fase(nueva: int) -> void:
	print(">>> CAMBIO DE FASE: ", nueva, " | drenaje: ", GameManager.FASES[nueva]["drenaje"])


func _al_desbloquear_app(indice: int) -> void:
	print(">>> APP DESBLOQUEADA: ", indice)


func _al_fallar() -> void:
	print(">>> FALLO TEMPRANO (no termina el juego)")
	GameManager.revivir(30.0)


func _al_colapsar() -> void:
	print(">>> COLAPSO: corte de luz")
