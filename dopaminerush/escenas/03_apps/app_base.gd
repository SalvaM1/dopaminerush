class_name AppBase
extends Control

# Clase madre de TODAS las apps del escritorio.
# La escribe una persona, una sola vez, y despues NADIE la toca.
#
# Cada app hereda de esta clase:
#     extends AppBase
#
# y solo tiene que hacer tres cosas:
#   1. Definir sus datos (nombre, icono, tamaño, rendimiento)
#   2. Llamar a recompensar() cuando el jugador hace "la accion buena"
#   3. Sobrescribir iniciar() / detener() si necesita arrancar o parar algo

# ---- DATOS QUE DEFINE CADA APP (desde el Inspector) ----
@export var id_app: String = "app"                  # identificador interno, sin espacios
@export var nombre_app: String = "App"              # lo que se ve en la barra de titulo
@export var icono: Texture2D
@export var tamano_ventana: Vector2 = Vector2(400, 300)
@export var dopamina_por_interaccion: float = 8.0

var esta_activa: bool = false


# La llama la ventana al abrirse. Si una app necesita arrancar algo
# (un timer, una animacion), sobrescribe esta funcion y llama a super().
func iniciar() -> void:
	esta_activa = true
	AudioManager.iniciar_capa(id_app)


# La llama la ventana al cerrarse.
func detener() -> void:
	esta_activa = false
	AudioManager.detener_capa(id_app)


# TODAS las apps llaman a esto cuando el jugador hace la accion que la app premia.
# Es el unico punto de contacto con el nucleo del juego.
func recompensar(multiplicador: float = 1.0) -> void:
	if not esta_activa:
		return
	GameManager.sumar_dopamina(dopamina_por_interaccion * multiplicador, id_app)
