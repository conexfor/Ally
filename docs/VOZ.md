# Asistente por voz: «Hey Ally»

Flujo (Android):

1. El usuario activa **Configuración → Asistente por voz → Activar con «Hey Ally»**.
2. Con el teléfono encendido (incluso con la app cerrada) dice **«Hey Ally»** y oye un pitido.
3. Dice la orden: *«establece una alarma a las 4:00 pm con Ana, Luis y Pedro»*.
4. La alarma se crea **sin pedir confirmación** (solo si se entendió toda la orden) y la app responde en voz alta:
   *«Listo. Alarma creada, hoy, a las 4 de la tarde, para ti, Ana, Luis y Pedro. Ana, Luis y Pedro deben aceptarla.»*
   Quien crea la alarma siempre la recibe; a los demás les suena cuando la aceptan.
5. Si falta algo (p. ej. «a las 6»: ¿de la mañana o de la tarde?, o hay dos contactos llamados Carlos),
   lo pregunta en voz alta y vuelve a escuchar. Eliminar o cambiar alarmas siempre pide un «sí».

La conversación queda guardada en el historial de **Alarma AI**. Dentro del chat también hay un botón
de micrófono que hace lo mismo.

## Arquitectura

| Parte | Archivo | Qué hace |
|---|---|---|
| Palabra clave | `android/.../voice/WakeWordDetector.kt` | [openWakeWord](https://github.com/dscripka/openWakeWord) con ONNX Runtime, 100% en el teléfono |
| Servicio en primer plano | `android/.../voice/VoiceService.kt` | Escucha el micrófono (16 kHz) con una notificación fija |
| Sesión | `android/.../voice/VoiceSession.kt` | Pitido → voz a texto (reconocedor del sistema) → Dart → texto a voz |
| Dart sin interfaz | `lib/services/voice_entrypoint.dart` | Motor Flutter sin interfaz con los mismos `AppServices` |
| Reglas de voz | `lib/application/assistant/voice_policy.dart` | Cuándo crear directamente y cómo leer las respuestas |
| Conversación sin interfaz | `lib/application/assistant/voice_assistant.dart` | Interpretar → ejecutar → respuesta hablada |

El intérprete es el mismo del chat (`ally_core`), así que todo lo que entiende el chat también
funciona por voz.

## Modelo de la palabra clave (obligatorio)

> **Estado actual:** `app/assets/wakeword/hey_ally.onnx` es una **primera versión entrenada solo con
> voces sintéticas** (sin grabaciones reales). Con una voz de prueba que nunca oyó detecta «Hey Ali»,
> «Ey Ali» y «Jey Ali» con puntuaciones de ~0,98 y no se activa con «allí», «ahí» ni «Ali» solo.
> Falla más con «Hey Ally» pronunciado «a-yi» y al hablar muy rápido. Mejorará con grabaciones reales.

`assets/wakeword/` debe contener tres archivos:

- `melspectrogram.onnx` y `embedding_model.onnx`: ya incluidos (publicación v0.5.1 de openWakeWord;
  son comunes a cualquier palabra clave).
- `hey_ally.onnx`: **hay que entrenarlo una vez**. Mientras no exista, el interruptor de
  Configuración aparece desactivado.

### Entrenar `hey_ally.onnx` para varios acentos (gratis, 1,5–3 horas)

No todos lo pronunciamos igual: «Hey Ali» (Perú), «Hey Ally», «Hey Alli», «Ey Ali»...
El notebook [tools/wakeword/entrenar_hey_ally.ipynb](../tools/wakeword/entrenar_hey_ally.ipynb)
combina tres fuentes de ejemplos:

| Fuente | Qué aporta |
|---|---|
| Voces abiertas en español (Piper) | 10 voces de España, México y Argentina leyendo todas las variantes |
| Generador en inglés de openWakeWord | Cientos de voces distintas con escrituras que suenan en español («hey ah lee») |
| **Grabaciones reales** | Los acentos sin voz sintética (Perú, Colombia, Chile...). **Lo más importante** |

También aprende lo que **no** debe activarla: «allí», «ahí», «hay», «Ali» sin el «hey», «Ok Google»...
Las voces de Microsoft Edge (~20 países, incluido Perú) se pueden activar en el notebook, con
la advertencia de licencia que allí se explica.

**Pasos**

1. Reúne grabaciones (ver abajo) en Google Drive: `ally_wakeword/grabaciones/<pais_nombre>/`.
2. Sube `tools/wakeword/entrenar_hey_ally.ipynb` a [Google Colab](https://colab.research.google.com)
   (*Archivo → Subir notebook*), elige *GPU T4* y *Ejecutar todas*.
3. La sección 9 muestra, con voces que el modelo nunca oyó, qué porcentaje detecta y cuántas
   activaciones falsas por hora tiene con cada umbral.
4. Copia `ally_wakeword/resultado/hey_ally.onnx` a `app/assets/wakeword/` y ajusta el umbral en
   `WakeWordDetector.create(context, threshold = ...)`. Compila de nuevo (no basta con hot reload).

Para cambiar frases, voces o parámetros edita `tools/wakeword/ally_wakeword.py` o
`construir_notebook.py` y regenera el notebook con `python tools/wakeword/construir_notebook.py`.

### Cómo pedir grabaciones (texto para enviar)

> ¡Hola! Estoy entrenando el asistente de voz de mi app y necesito tu voz.
> Envíame **una nota de voz de WhatsApp** diciendo **«Hey Ally» 15 veces**, con una pausa de
> 2 segundos entre cada una. Dilo como te salga natural, y varía un poco: más rápido, más
> lento, más bajo, más alto, cerca y lejos del teléfono. Si puedes, graba algunas con ruido
> de fondo (tele, calle). ¡Gracias!

Opcional, para que no se active sin querer: una nota de 1 minuto **hablando normal** que
incluya palabras como «allí», «ahí», «hay» y nombres como «Alicia», sin decir «Hey Ally».
Va en `ally_wakeword/grabaciones_negativas/`.

**Cuántas:** con 10 personas ya mejora mucho; lo ideal son 30 o más, mezclando países, edades
y hombres/mujeres. Las personas se reparten solas entre entrenamiento y prueba, para medir el
modelo con voces que no ha oído. Pide permiso para usar su voz con este fin.

### Probar la tubería antes de entrenar

Descarga un modelo preentrenado, p. ej. `hey_jarvis_v0.1.onnx` de la
[publicación v0.5.1](https://github.com/dscripka/openWakeWord/releases/tag/v0.5.1), renómbralo a
`hey_ally.onnx` y di «hey Jarvis». **Solo para pruebas**: los modelos preentrenados tienen
licencia CC BY-NC-SA 4.0 (no comercial). El modelo que entrenes tú es tuyo.

## Limitaciones en Android

- **Notificación fija**: Android la exige siempre que una app usa el micrófono en segundo plano.
  Tiene un botón «Desactivar».
- **Tras reiniciar el teléfono** (Android 11+): Android no deja que el micrófono se active solo, así
  que aparece el aviso «Activa «Hey Ally»» y basta con tocarlo una vez. Abrir la app también lo
  reactiva.
- **Batería**: el detector procesa audio cada 80 ms; el consumo es moderado, pero no es cero.
- **Voz a texto** usa el reconocedor del teléfono (Google en la mayoría). Normalmente necesita
  internet, salvo que esté descargado el paquete de español sin conexión.
- **Tamaño de la APK**: ONNX Runtime añade varios MB por arquitectura. Publica como App Bundle
  (`.aab`) para que cada teléfono descargue solo la suya.
- **Llamada u otra app usando el micrófono**: la detección se pausa y se reintenta cada pocos segundos.

## iOS

iOS no permite que una app de terceros escuche una palabra clave en segundo plano. Lo equivalente
sería Siri con App Intents («Oye Siri, crear alarma en Ally…»), que todavía no está
implementado. El botón de micrófono del chat también es solo para Android por ahora.
