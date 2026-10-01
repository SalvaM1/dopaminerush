class_name Interactuable
extends StaticBody3D

# Script reutilizable: se pega a cualquier objeto del mundo con el que
# se pueda interactuar (despertador, monitor, puerta, etc.)

# Texto que aparece en el cartel. Se edita desde el Inspector.
@export var texto_interaccion: String = "Usar"

# Un objeto apagado no muestra cartel ni responde a la E.
# Sirve para que las cosas dejen de estar disponibles cuando ya
# cumplieron su funcion (el despertador una vez apagado, por ejemplo)
# o todavia no corresponde usarlas (la puerta antes del colapso).
@export var activo: bool = true

signal usado()


# El jugador llama a esta funcion cuando aprieta E mirando este objeto.
func interactuar() -> void:
	if not activo:
		return
	usado.emit()
