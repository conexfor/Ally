# Ejemplos de comandos del asistente

Todos estos comandos se interpretan con el motor de reglas (sin IA). Antes de ejecutar cualquier operación que modifique datos, el asistente muestra un resumen y pide confirmación.

## Crear alarmas

| Escribes | Entiende |
|---|---|
| Crea una alarma mañana a las 8 para Nicolás | ⏰ 08:00 · 📅 mañana · 👤 Nicolás |
| Pon una alarma hoy a las 2:30 pm para Nicolás y Juan | ⏰ 14:30 · hoy · Nicolás, Juan |
| Alarma para María a las 2:30 pm | ⏰ 14:30 · María |
| Recuérdale a Nicolás a las 5 de la tarde | ⏰ 17:00 · Nicolás |
| Programa una alarma para Pedro mañana a las 9 | ⏰ 09:00 · mañana · Pedro |
| Despiértame el próximo lunes a las 6:45 am | ⏰ 06:45 · lunes · tú |
| Recuérdame mañana a las 4 de la tarde tomar la pastilla | ⏰ 16:00 · 📝 Tomar la pastilla |
| Crea una alarma mañana a las 8 para Juan que diga "Reunión de proyecto" | 📝 Reunión de proyecto |
| Recuérdale a Juan que llame al médico mañana a las 4 | 👤 Juan · 📝 Llame al médico |
| Pon una alarma en 10 minutos | ahora + 10 min |
| Avísame dentro de una hora y media | ahora + 90 min |
| Pon una alarma esta noche a las 9 | hoy 21:00 |
| Pon una alarma el 3 de octubre a las 7 | 3 de octubre (año siguiente si ya pasó) |
| Pon una alarma el 25/12 a las 9 · el 2026-10-20 a las 9 | fechas numéricas |

## Varios destinatarios y grupos

| Escribes | Entiende |
|---|---|
| Pon una alarma mañana a las 7 para Nicolás, Juan y María | 3 personas |
| Programa una alarma para todo el equipo a las 9 | 👥 grupo cuyo nombre contiene "equipo" |
| Pon una alarma mañana a las 9 para la familia | 👥 grupo "Familia" |
| Pon una alarma para @juan mañana a las 10 | por nombre de usuario |

## Recurrencias

| Escribes | Regla |
|---|---|
| Todos los días a las 8 | diaria |
| Todos los lunes a las 9 | semanal: lunes |
| Cada lunes y miércoles a las 7 | semanal: lunes, miércoles |
| De lunes a viernes a las 8 · Entre semana a las 8 | lunes a viernes |
| Los fines de semana a las 10 | sábado y domingo |
| Cada 2 días a las 9 pm | cada 2 días |
| Todas las mañanas a las 6 | diaria, 06:00 |
| El 5 de cada mes a las 9 | mensual, día 5 |

## Consultas

- ¿Qué alarmas tengo mañana?
- Muéstrame mis alarmas · Muéstrame las alarmas de la tarde
- ¿Quiénes son mis contactos? · ¿Qué grupos tengo?
- Ayuda · ¿Qué puedes hacer?

## Modificar, cancelar, posponer

| Escribes | Acción |
|---|---|
| Cambia la alarma de las 8 a las 9 | EDIT_ALARM (conserva AM/PM de la original) |
| Mueve la alarma de mañana al lunes | EDIT_ALARM |
| Cancela la alarma de las 3 · Elimina la alarma de mañana | DELETE_ALARM (pregunta si hay varias) |
| Desactiva la alarma de mañana · Apaga la alarma | CANCEL_ALARM (solo la próxima vez / la que suena) |
| Posponer 10 minutos · Pospón la alarma media hora · Dame 5 minutos más | SNOOZE_ALARM |

## Grupos

- Crea un grupo llamado Familia con Juan y María
- Agrega a Pedro al grupo Familia · Añade a María al equipo
- Saca a Juan del equipo Desarrollo

## Ambigüedades (el asistente pregunta)

- **"Pon una alarma a las 8"** (siendo las 10:00) → *¿Quieres programarla a las 8:00 PM (hoy) o a las 8:00 AM (mañana)?* Puedes tocar una opción o responder "pm", "de la mañana"…
- **"Crea una alarma para Carlos"** con varios Carlos → *Encontré varios usuarios llamados Carlos: Carlos Pérez · Carlos Torres · Carlos Gómez. ¿A cuál deseas enviar la alarma?* (también puedes escribir "el segundo" o el apellido).
- **"…para Roberto"** sin ese contacto → *No encontré a "Roberto" entre tus contactos.* [Buscar usuarios] [Invitar a Roberto] [Cancelar]
- **"…para Pedor"** → *¿Quisiste decir Pedro?*
- **Hora que ya pasó** → propone mañana a la misma hora.
- **Texto parcialmente entendido** → *No entendí completamente la instrucción. Encontré: … ¿Quieres continuar?* [Editar] [Confirmar]
