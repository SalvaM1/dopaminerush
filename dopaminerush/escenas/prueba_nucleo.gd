extends Control

# ESCENA DE PRUEBA — DESCARTABLE
# Valida el GameManager nuevo: rampa de drenaje, ofertas y desbloqueos.
# Se borra cuando el escritorio real este armado (fase B).

@onready var boton_sumar: Button = $BotonSumar
@onready var boton_aceptar: Button = $BotonAceptar
@onready var info: Label = $Info


func _ready() -> void:
	boton_sumar.pressed.connect(_al_sumar)
	boton_aceptar.pressed.connect(_al_aceptar)
	boton_aceptar.disabled = true

	# Escuchamos las señales para verificar que se emiten
	GameManager.oferta_app.connect(_al_ofrecer_app)
	GameManager.app_desbloqueada.connect(_al_desbloquear_app)
	GameManager.etapa_final_iniciada.connect(_al_iniciar_etapa_final)
	GameManager.fallo_temprano.connect(_al_fallar)
	GameManager.colapso.connect(_al_colapsar)

	# Arrancamos el juego
	GameManager.iniciar_sesion_pc()


func _process(_delta: float) -> void:
	info.text = "Dopamina: %.1f\nDrenaje: %.2f /seg\nApps desbloqueadas: %d de %d\nEtapa final: %s" % [
		GameManager.dopamina,
		GameManager.drenaje_actual(),
		GameManager.apps_desbloqueadas,
		GameManager.APPS.size(),
		str(GameManager.etapa_final)
	]


func _al_sumar() -> void:
	GameManager.sumar_dopamina(10.0, "prueba")


func _al_aceptar() -> void:
	GameManager.aceptar_oferta()
	boton_aceptar.disabled = true
	boton_aceptar.text = "Aceptar oferta"


func _al_ofrecer_app(indice: int, titulo: String, texto: String, boton: String) -> void:
	print(">>> OFERTA de la app ", indice, ": [", titulo, "] ", texto, " -> ", boton)
	boton_aceptar.disabled = false
	boton_aceptar.text = boton


func _al_desbloquear_app(indice: int) -> void:
	print(">>> DESBLOQUEADA app ", indice, ": ", GameManager.APPS[indice]["nombre"])


func _al_iniciar_etapa_final() -> void:
	print(">>> ETAPA FINAL: ya no se puede ganar")


func _al_fallar() -> void:
	#print(">>> FALLO TEMPRANO (no termina el juego)") #sacando estos comentarios el juego no termina hasta llegar a la ultima fase
	#GameManager.revivir(30.0)
	print(">>> FALLO TEMPRANO — juego terminado")


func _al_colapsar() -> void:
	print(">>> COLAPSO: corte de luz")
