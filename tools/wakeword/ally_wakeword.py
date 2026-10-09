"""Herramientas para entrenar «Hey Ally» con acentos hispanos (openWakeWord).

Se usa desde `entrenar_hey_ally.ipynb` (Google Colab), que copia este archivo
tal cual. Las funciones también se pueden probar en local.

Fuentes de ejemplos positivos (la persona dice la palabra clave):
  1. Voces abiertas en español de Piper (España, México, Argentina).
  2. El generador en inglés de openWakeWord con escrituras que suenan como en
     español («hey ah lee»): cientos de voces distintas.
  3. Grabaciones reales (notas de voz de WhatsApp, etc.): imprescindibles para
     los acentos sin voz sintética (Perú, Colombia, Chile...).
"""

from __future__ import annotations

import json
import random
import shutil
import subprocess
import tempfile
import urllib.request
import uuid
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 16000

# Lo que la gente dice para activar la app. Leído por voces en español: «Ally»
# sale como «a-yi», «Alli» como «a-lli»/«a-yi», «Ali» como «á-li».
FRASES_POSITIVAS_ES = [
    'Hey Ali',
    'Hey Ally',
    'Hey Alli',
    'Ey Ali',
    'Jey Ali',
    'Hei Ali',
    'Hey, Ali',
    '¡Hey Ali!',
]

# Para el generador en inglés de openWakeWord (target_phrase): escrituras que
# las voces en inglés pronuncian como lo diría alguien que habla español.
# Todas las palabras deben estar en el diccionario CMU (el modelo que predice
# las demás, DeepPhonemizer, ya no se puede descargar). «ali» = /Á-li/.
FRASES_POSITIVAS_EN = ['hey ali', 'hey alley', 'hey ah lee']

# Lo que NO debe activarla. Lo más peligroso es «allí»/«ahí», que suenan casi
# igual que «Ali» sin el «hey».
FRASES_NEGATIVAS_ES = [
    'allí', 'ahí', 'aquí', 'allá', 'Ali', 'hay', 'hey', 'oye', 'Alicia', 'aliado',
    'ahí está', 'allí nomás', 'déjalo allí', 'ponlo ahí', 'hay alguien', 'hay que ir',
    'hey, ¿qué tal?', 'oye, ven acá', 'a ver', 'ojalá', 'jalar', 'hey amigo',
    'hey, mira', 'hey, Alicia', 'oye Siri', 'Ok Google', 'Alexa', 'hey Google',
    'hey hola', 'a la izquierda', 'al lado', 'a las once', 'hay leche', 'Aliexpress',
    'el aliento', 'qué alegría', 'vamos allá', 'allí está la alarma', 'pon una alarma a las cuatro',
]

# Negativos para el generador en inglés (custom_negative_phrases).
FRASES_NEGATIVAS_EN = ['hey', 'alley', 'hey all', 'hey ollie', 'hey alexa', 'hey google', 'ali', 'hey alice']

PIPER_URL = 'https://huggingface.co/rhasspy/piper-voices/resolve/main'
VOCES_PIPER = [
    'es/es_AR/daniela/high/es_AR-daniela-high',
    'es/es_ES/carlfm/x_low/es_ES-carlfm-x_low',
    'es/es_ES/davefx/medium/es_ES-davefx-medium',
    'es/es_ES/mls_10246/low/es_ES-mls_10246-low',
    'es/es_ES/mls_9972/low/es_ES-mls_9972-low',
    'es/es_ES/sharvard/medium/es_ES-sharvard-medium',
    'es/es_MX/ald/medium/es_MX-ald-medium',
    'es/es_MX/claude/high/es_MX-claude-high',
]

AUDIO_EXT = {'.wav', '.mp3', '.m4a', '.ogg', '.opus', '.aac', '.flac', '.webm', '.3gp', '.amr', '.mp4'}


# ------------------------------------------------------------------- audio


def leer_wav(path: str | Path) -> tuple[np.ndarray, int]:
    """WAV PCM16 → (muestras int16 mono, frecuencia)."""
    with wave.open(str(path), 'rb') as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2')
        if w.getnchannels() > 1:
            data = data.reshape(-1, w.getnchannels()).mean(axis=1).astype(np.int16)
        return data, w.getframerate()


def guardar_wav(path: str | Path, audio: np.ndarray, sr: int = SR) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(np.asarray(audio, dtype=np.int16).tobytes())


def remuestrear(audio: np.ndarray, sr_origen: int, sr_destino: int = SR) -> np.ndarray:
    if sr_origen == sr_destino:
        return audio.astype(np.int16)
    n = int(round(len(audio) * sr_destino / sr_origen))
    x = np.interp(np.linspace(0, len(audio) - 1, n), np.arange(len(audio)), audio.astype(np.float64))
    return np.clip(x, -32768, 32767).astype(np.int16)


def cargar_audio(path: str | Path) -> np.ndarray:
    """Cualquier formato (nota de voz de WhatsApp, m4a, mp3...) → int16 mono 16 kHz.

    Los formatos distintos de WAV necesitan ffmpeg (incluido en Colab).
    """
    path = Path(path)
    if path.suffix.lower() == '.wav':
        try:
            audio, sr = leer_wav(path)
            return remuestrear(audio, sr)
        except wave.Error:
            pass  # WAV no PCM16: que lo convierta ffmpeg.
    out = subprocess.run(
        ['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        check=True,
        capture_output=True,
    ).stdout
    return np.frombuffer(out, dtype='<i2').copy()


def _energia(audio: np.ndarray, ventana: int) -> np.ndarray:
    n = len(audio) // ventana
    if n == 0:
        return np.zeros(0)
    frames = audio[: n * ventana].astype(np.float64).reshape(n, ventana)
    return np.sqrt((frames**2).mean(axis=1))


def dividir_en_frases(
    audio: np.ndarray,
    min_seg: float = 0.35,
    max_seg: float = 3.0,
    pausa: float = 0.35,
    margen: float = 0.15,
) -> list[np.ndarray]:
    """Separa una grabación con varias repeticiones («Hey Ally… Hey Ally…»)
    en un clip por repetición, cortando por los silencios."""
    ventana = int(0.03 * SR)
    energia = _energia(audio, ventana)
    if len(energia) == 0:
        return []
    ruido = np.percentile(energia, 20)
    pico = np.percentile(energia, 99)
    umbral = max(ruido * 3, ruido + (pico - ruido) * 0.12, 60)
    voz = energia > umbral

    # Une tramos separados por pausas cortas (entre «hey» y «Ali» hay una).
    segmentos: list[list[int]] = []
    for i, v in enumerate(voz):
        if not v:
            continue
        if segmentos and i - segmentos[-1][1] <= pausa / 0.03:
            segmentos[-1][1] = i
        else:
            segmentos.append([i, i])

    clips = []
    pad = int(margen * SR)
    for ini, fin in segmentos:
        dur = (fin - ini + 1) * 0.03
        if dur < min_seg or dur > max_seg:
            continue
        a = max(0, ini * ventana - pad)
        b = min(len(audio), (fin + 1) * ventana + pad)
        clips.append(audio[a:b].copy())
    return clips


def recortar_silencio(audio: np.ndarray, margen: float = 0.15) -> np.ndarray:
    """Quita el silencio inicial y final (los clips de voces sintéticas)."""
    clips = dividir_en_frases(audio, min_seg=0.1, max_seg=10, pausa=0.6, margen=margen)
    return max(clips, key=len) if clips else audio


def variaciones(audio: np.ndarray, n: int, semilla: int = 0) -> list[np.ndarray]:
    """Copias con velocidad/tono (±12 %) y volumen distintos, para que pocas
    grabaciones reales pesen más en el entrenamiento."""
    rnd = random.Random(semilla)
    out = []
    for _ in range(n):
        factor = rnd.uniform(0.88, 1.12)
        x = remuestrear(audio, SR, int(SR * factor)).astype(np.float64)
        x *= rnd.uniform(0.5, 1.4)
        out.append(np.clip(x, -32768, 32767).astype(np.int16))
    return out


# ---------------------------------------------------------- voces sintéticas


def _descargar(url: str, destino: Path) -> Path:
    if not destino.exists():
        destino.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(url, destino)
    return destino


def _elegir_destino(rnd: random.Random, destino: Path, destino_test: Path | None, fraccion_test: float) -> Path:
    return destino_test if destino_test is not None and rnd.random() < fraccion_test else destino


def generar_con_piper(
    destino: str | Path,
    frases: list[str],
    voces: list[str] = VOCES_PIPER,
    variantes_por_frase: int = 20,
    cache: str | Path = 'piper_voces',
    destino_test: str | Path | None = None,
    fraccion_test: float = 0.15,
    semilla: int = 0,
) -> int:
    """Lee cada frase con cada voz en español, variando velocidad y entonación.

    Crea WAV de 16 kHz en `destino` (y una fracción en `destino_test`, si se
    indica). Devuelve el número de clips creados."""
    from piper import PiperVoice, SynthesisConfig

    rnd = random.Random(semilla)
    destino = Path(destino)
    test = Path(destino_test) if destino_test else None
    for d in (destino, test):
        if d:
            d.mkdir(parents=True, exist_ok=True)
    total = 0
    for voz in voces:
        nombre = voz.rsplit('/', 1)[-1]
        modelo = _descargar(f'{PIPER_URL}/{voz}.onnx', Path(cache) / f'{nombre}.onnx')
        config = _descargar(f'{PIPER_URL}/{voz}.onnx.json', Path(cache) / f'{nombre}.onnx.json')
        hablantes = json.loads(config.read_text(encoding='utf-8')).get('num_speakers', 1)
        piper = PiperVoice.load(modelo, config_path=config)
        sr = piper.config.sample_rate
        for frase in frases:
            for _ in range(variantes_por_frase):
                cfg = SynthesisConfig(
                    speaker_id=rnd.randrange(hablantes) if hablantes > 1 else None,
                    length_scale=rnd.uniform(0.8, 1.35),
                    noise_scale=rnd.uniform(0.4, 0.9),
                    noise_w_scale=rnd.uniform(0.5, 1.0),
                )
                audio = np.concatenate([
                    np.frombuffer(chunk.audio_int16_bytes, dtype=np.int16)
                    for chunk in piper.synthesize(frase, syn_config=cfg)
                ])
                clip = recortar_silencio(remuestrear(audio, sr))
                carpeta = _elegir_destino(rnd, destino, test, fraccion_test)
                guardar_wav(carpeta / f'piper_{nombre}_{uuid.uuid4().hex[:10]}.wav', clip)
                total += 1
    return total


async def _edge_tts_async(
    destino: Path, test: Path | None, fraccion_test: float, frases: list[str], variantes: int, semilla: int
) -> int:
    import edge_tts

    rnd = random.Random(semilla)
    voces = [v['ShortName'] for v in await edge_tts.list_voices() if v['Locale'].startswith('es-')]
    total = 0
    # Fuera de las carpetas de clips: train.py cuenta todos sus archivos.
    tmp = Path(tempfile.gettempdir()) / f'edge_{uuid.uuid4().hex}.mp3'
    for voz in voces:
        for frase in frases:
            for _ in range(variantes):
                rate = f'{rnd.randint(-20, 25):+d}%'
                pitch = f'{rnd.randint(-15, 15):+d}Hz'
                await edge_tts.Communicate(frase, voz, rate=rate, pitch=pitch).save(str(tmp))
                clip = recortar_silencio(cargar_audio(tmp))
                carpeta = _elegir_destino(rnd, destino, test, fraccion_test)
                guardar_wav(carpeta / f'edge_{voz}_{uuid.uuid4().hex[:10]}.wav', clip)
                total += 1
    tmp.unlink(missing_ok=True)
    return total


def generar_con_edge_tts(
    destino: str | Path,
    frases: list[str],
    variantes: int = 3,
    destino_test: str | Path | None = None,
    fraccion_test: float = 0.15,
    semilla: int = 0,
) -> int:
    """Voces neuronales de Microsoft Edge en ~20 países hispanohablantes
    (incluye Perú: es-PE). Ver la advertencia de uso en el notebook."""
    import asyncio

    destino = Path(destino)
    test = Path(destino_test) if destino_test else None
    for d in (destino, test):
        if d:
            d.mkdir(parents=True, exist_ok=True)
    coro = _edge_tts_async(destino, test, fraccion_test, frases, variantes, semilla)
    try:
        return asyncio.run(coro)
    except RuntimeError:
        # Jupyter/Colab ya tiene un bucle de eventos en marcha.
        import nest_asyncio

        nest_asyncio.apply()
        return asyncio.get_event_loop().run_until_complete(coro)


# ------------------------------------------------------- grabaciones reales


def importar_grabaciones(
    carpeta: str | Path,
    destino_train: str | Path,
    destino_test: str | Path,
    copias: int = 20,
    fraccion_test: float = 0.2,
    semilla: int = 0,
) -> dict[str, int]:
    """Importa grabaciones reales organizadas por persona:

        carpeta/peru_maria/nota1.opus
        carpeta/peru_maria/nota2.m4a
        carpeta/mexico_juan/hey_ally.wav

    Cada archivo puede tener varias repeticiones: se separan por silencios.
    Algunas personas completas se reservan para la prueba (así se mide con
    voces que el modelo nunca oyó). En entrenamiento cada clip se copia con
    variaciones de velocidad y volumen.
    """
    carpeta = Path(carpeta)
    personas = sorted(p for p in carpeta.iterdir() if p.is_dir()) if carpeta.exists() else []
    sueltos = [f for f in carpeta.iterdir() if f.suffix.lower() in AUDIO_EXT] if carpeta.exists() else []
    grupos = {p.name: sorted(f for f in p.rglob('*') if f.suffix.lower() in AUDIO_EXT) for p in personas}
    if sueltos:
        grupos['_sin_carpeta'] = sorted(sueltos)

    rnd = random.Random(semilla)
    nombres = sorted(grupos)
    rnd.shuffle(nombres)
    n_test = round(len(nombres) * fraccion_test) if len(nombres) >= 3 else 0
    personas_test = set(nombres[:n_test])

    resumen = {'personas': len(nombres), 'personas_test': n_test, 'clips': 0, 'train': 0, 'test': 0}
    for nombre, archivos in grupos.items():
        clips = []
        for f in archivos:
            try:
                clips += dividir_en_frases(cargar_audio(f))
            except Exception as e:  # Archivo dañado o formato raro: se informa y se sigue.
                print(f'  No se pudo leer {f}: {e}')
        resumen['clips'] += len(clips)
        for i, clip in enumerate(clips):
            # Con menos de 3 personas se reserva una parte de los clips de cada una.
            a_test = nombre in personas_test or (n_test == 0 and rnd.random() < fraccion_test)
            if a_test:
                guardar_wav(Path(destino_test) / f'real_{nombre}_{i}.wav', clip)
                resumen['test'] += 1
            else:
                for j, v in enumerate([clip, *variaciones(clip, copias - 1, semilla=zlib.crc32(f'{nombre}{i}'.encode()))]):
                    guardar_wav(Path(destino_train) / f'real_{nombre}_{i}_{j}.wav', v)
                    resumen['train'] += 1
    return resumen


def importar_negativas(
    carpeta: str | Path,
    destino_train: str | Path,
    destino_test: str | Path,
    duracion: float = 2.0,
    fraccion_test: float = 0.15,
    semilla: int = 0,
) -> int:
    """Conversación normal SIN la palabra clave (notas de voz hablando de
    cualquier cosa, diciendo «allí», «ahí»...). Se corta en trozos de
    `duracion` segundos con voz. Devuelve el número de trozos."""
    carpeta = Path(carpeta)
    if not carpeta.exists():
        return 0
    rnd = random.Random(semilla)
    n = int(duracion * SR)
    total = 0
    for f in sorted(p for p in carpeta.rglob('*') if p.suffix.lower() in AUDIO_EXT):
        try:
            audio = cargar_audio(f)
        except Exception as e:
            print(f'  No se pudo leer {f}: {e}')
            continue
        umbral = max(np.percentile(_energia(audio, 480), 50) * 2, 60) if len(audio) > 480 else 60
        for i in range(0, len(audio) - n + 1, n):
            trozo = audio[i : i + n]
            if np.sqrt((trozo.astype(np.float64) ** 2).mean()) < umbral:
                continue  # Silencio: no aporta.
            destino = destino_test if rnd.random() < fraccion_test else destino_train
            guardar_wav(Path(destino) / f'real_neg_{f.stem}_{i // n}.wav', trozo)
            total += 1
    return total


# -------------------------------------------------------------- evaluación


class Detector:
    """Misma tubería que la app (WakeWordDetector.kt), para medir un modelo."""

    def __init__(self, modelo: str | Path, melspec: str | Path, embedding: str | Path):
        import onnxruntime as ort

        self.ww = ort.InferenceSession(str(modelo))
        self.mel = ort.InferenceSession(str(melspec))
        self.emb = ort.InferenceSession(str(embedding))
        self.ww_input = self.ww.get_inputs()[0].name
        self.frames = self.ww.get_inputs()[0].shape[1]

    def puntuaciones(self, audio: np.ndarray) -> np.ndarray:
        """Puntuación cada 80 ms (con 1 s de silencio delante y detrás)."""
        audio = np.concatenate([np.zeros(SR, np.int16), audio, np.zeros(SR, np.int16)])
        contexto = np.zeros(1760, np.float32)
        mel = [np.ones(32, np.float32)] * 76
        feats: list[np.ndarray] = []
        out = []
        for i in range(0, len(audio) - 1279, 1280):
            contexto = np.concatenate([contexto[1280:], audio[i : i + 1280].astype(np.float32)])
            m = self.mel.run(None, {self.mel.get_inputs()[0].name: contexto[None]})[0].ravel() / 10 + 2
            mel = (mel + list(m.reshape(-1, 32)))[-970:]
            ventana = np.stack(mel[-76:])[None, :, :, None].astype(np.float32)
            feats = (feats + [self.emb.run(None, {self.emb.get_inputs()[0].name: ventana})[0].ravel()])[-120:]
            if len(feats) < self.frames:
                out.append(0.0)
                continue
            x = np.stack(feats[-self.frames :])[None].astype(np.float32)
            out.append(float(self.ww.run(None, {self.ww_input: x})[0].ravel()[0]))
        return np.array(out)


def evaluar(
    detector: Detector,
    positivos: str | Path,
    negativos: str | Path | None = None,
    umbrales: tuple[float, ...] = (0.3, 0.4, 0.5, 0.6, 0.7),
) -> dict:
    """Porcentaje de «Hey Ally» detectados y activaciones falsas por umbral.

    `positivos`: clips con la palabra clave (p. ej. grabaciones reales de prueba).
    `negativos`: audios de conversación normal (sin la palabra clave).
    """
    pos = [detector.puntuaciones(cargar_audio(f)).max() for f in sorted(Path(positivos).glob('*.wav'))]
    resultado: dict = {'clips_positivos': len(pos), 'umbral': {}}
    horas = 0.0
    neg_scores = []
    if negativos:
        for f in sorted(p for p in Path(negativos).rglob('*') if p.suffix.lower() in AUDIO_EXT):
            audio = cargar_audio(f)
            horas += len(audio) / SR / 3600
            neg_scores.append(detector.puntuaciones(audio))
    for u in umbrales:
        fila = {'detectados': round(100 * np.mean([s >= u for s in pos]), 1) if pos else None}
        if neg_scores:
            # Activaciones separadas al menos 2 s (como en la app).
            falsas = 0
            for s in neg_scores:
                ultimo = -999
                for i in np.flatnonzero(s >= u):
                    if i - ultimo > 25:
                        falsas += 1
                        ultimo = i
            fila['falsas_por_hora'] = round(falsas / horas, 2) if horas else None
        resultado['umbral'][u] = fila
    resultado['horas_negativas'] = round(horas, 3)
    return resultado


def copiar_modelo(origen: str | Path, destino: str | Path) -> Path:
    destino = Path(destino)
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(origen, destino)
    return destino
