"""Genera `entrenar_hey_ally.ipynb` (Google Colab) a partir de este archivo y
de `ally_wakeword.py`. Ejecuta `python construir_notebook.py` tras cambiar
cualquiera de los dos."""

import json
from pathlib import Path

AQUI = Path(__file__).parent


def md(texto: str) -> dict:
    return {'cell_type': 'markdown', 'metadata': {}, 'source': texto.strip('\n').splitlines(keepends=True)}


def code(texto: str) -> dict:
    return {
        'cell_type': 'code',
        'execution_count': None,
        'metadata': {},
        'outputs': [],
        'source': texto.strip('\n').splitlines(keepends=True),
    }


modulo = (AQUI / 'ally_wakeword.py').read_text(encoding='utf-8')

celdas = [
    md('''
# Entrenar «Hey Ally» para varios acentos

Genera `hey_ally.onnx`, el modelo que detecta la palabra clave en la app.

**Antes de empezar**

1. *Entorno de ejecución → Cambiar tipo de entorno de ejecución → GPU T4* (gratis).
2. En tu Google Drive crea la carpeta `ally_wakeword` con esta estructura:

```
ally_wakeword/
├── grabaciones/            ← personas diciendo «Hey Ally» (una carpeta por persona)
│   ├── peru_maria/         ← cualquier formato: notas de voz de WhatsApp, m4a, mp3...
│   ├── mexico_juan/
│   └── ...
└── grabaciones_negativas/  ← opcional: gente hablando normal, SIN decir «Hey Ally»
```

Cada nota de voz puede tener varias repeticiones con pausas: se separan solas.
Pon el país en el nombre de la carpeta (`peru_...`) para saber qué acentos tienes.

3. *Entorno de ejecución → Ejecutar todas*. Tarda entre 1,5 y 3 horas.
   Si se corta, vuelve a ejecutar todo: retoma donde se quedó.

El resultado queda en `ally_wakeword/resultado/hey_ally.onnx`.
'''),
    md('## 1. Configuración'),
    code('''
CARPETA_DRIVE = '/content/drive/MyDrive/ally_wakeword'
MODELO = 'hey_ally'

N_SAMPLES = 20000          # clips positivos de entrenamiento (más = más preciso y más lento)
N_SAMPLES_VAL = 2000       # clips de validación
STEPS = 50000              # pasos de entrenamiento

VARIANTES_PIPER = 50       # por voz en español y frase (8 voces × 8 frases × 50 = 3.200 clips)
COPIAS_POR_GRABACION = 20  # cada repetición real se copia con variaciones de velocidad/volumen

# Voces de Microsoft Edge: ~45 voces de ~20 países (incluye Perú, Colombia, Chile...).
# ⚠️ Usa el servicio de lectura en voz alta de Edge mediante la librería no oficial
# `edge-tts`; Microsoft no ofrece una licencia explícita para este uso. Actívalo solo
# si aceptas ese riesgo. Sin esto, los acentos sin voz abierta dependen de las grabaciones reales.
USAR_EDGE_TTS = False
VARIANTES_EDGE = 4
'''),
    md('## 2. Google Drive'),
    code('''
from google.colab import drive
from pathlib import Path

try:
    drive.mount('/content/drive')
    USANDO_DRIVE = True
except Exception as e:
    # Suele pasar si se cierra la ventana de permisos o no se marcan todos.
    # Se sigue sin Drive: el modelo se descargará al final al navegador.
    print(f'⚠️  No se pudo conectar Google Drive ({e}). Para usarlo, vuelve a ejecutar esta celda'
          ' y acepta TODOS los permisos. Mientras tanto se continúa sin grabaciones.')
    USANDO_DRIVE = False
    CARPETA_DRIVE = '/content/ally_wakeword'
drive_dir = Path(CARPETA_DRIVE)
for sub in ['grabaciones', 'grabaciones_negativas', 'resultado']:
    (drive_dir / sub).mkdir(parents=True, exist_ok=True)

personas = sorted(p.name for p in (drive_dir / 'grabaciones').iterdir() if p.is_dir())
print(f'Personas con grabaciones: {len(personas)}')
for p in personas:
    print('  ·', p)
if len(personas) < 3:
    print('\\n⚠️  Con menos de 3 personas el modelo dependerá casi solo de voces sintéticas.')
'''),
    md('## 3. Instalación'),
    code('''
%cd /content
import subprocess, sys, sysconfig

# Generador de voces en inglés: v2.0.0 (las versiones 3.x ya no son compatibles con train.py).
!git clone -q --branch v2.0.0 --depth 1 https://github.com/rhasspy/piper-sample-generator || true
!wget -q -nc -O piper-sample-generator/models/en_US-libritts_r-medium.pt 'https://github.com/rhasspy/piper-sample-generator/releases/download/v2.0.0/en_US-libritts_r-medium.pt'
# PyTorch 2.6+ ya no carga modelos completos por defecto.
!sed -i 's/model = torch.load(model_path)$/model = torch.load(model_path, weights_only=False)/' piper-sample-generator/generate_samples.py

!git clone -q https://github.com/dscripka/openwakeword || true
!pip install -q -e ./openwakeword --no-deps
# La validación de activaciones falsas cargaba ~3 GB de una vez y se quedaba sin memoria.
!sed -i 's/batch_size=len(X_val_fp_labels)/batch_size=8192/' openwakeword/openwakeword/train.py
# Error de openWakeWord: default="False" (texto) cuenta como verdadero y siempre intenta
# convertir a .tflite, lo que falla sin TensorFlow y detiene «Ejecutar todas».
!sed -i 's/default="False",/default=False,/' openwakeword/openwakeword/train.py
# Versiones que funcionan con Python 3.12/3.13. No se instala TensorFlow (solo servía para
# .tflite; la app usa el .onnx), pero sí `onnx`, que PyTorch necesita para exportar el modelo.
!pip install -q onnxruntime "scipy<1.15" scikit-learn tqdm requests pyyaml mutagen torchinfo==1.8.0 "torchmetrics<1.5" speechbrain audiomentations==0.33.0 torch-audiomentations==0.11.0 acoustics==0.2.6 pronouncing==0.2.0 "datasets<3" deep-phonemizer==0.0.19 webrtcvad-wheels piper-tts soundfile onnx onnxscript
if USAR_EDGE_TTS:
    !pip install -q edge-tts nest_asyncio

# piper-phonemize no tiene versión para Python 3.13: se sustituye por el fonemizador de
# piper-tts (mismo código de espeak-ng). Solo hace falta phonemize_espeak().
Path(sysconfig.get_paths()['purelib'], 'piper_phonemize.py').write_text(
    'from piper.phonemize_espeak import EspeakPhonemizer\\n'
    '_p = None\\n'
    'def phonemize_espeak(text, voice):\\n'
    '    global _p\\n'
    '    _p = _p or EspeakPhonemizer()\\n'
    '    return _p.phonemize(voice, text)\\n'
)

import os
os.makedirs('./openwakeword/openwakeword/resources/models', exist_ok=True)
for f in ['embedding_model.onnx', 'melspectrogram.onnx']:
    !wget -q -nc https://github.com/dscripka/openWakeWord/releases/download/v0.5.1/{f} -O ./openwakeword/openwakeword/resources/models/{f}
'''),
    md('## 4. Herramientas para acentos hispanos (`ally_wakeword.py`)'),
    code('%%writefile ally_wakeword.py\n' + modulo),
    md('''
## 5. Datos de fondo (ruido, música, eco) y negativos generales

Como el notebook oficial de openWakeWord (sin el dataset de música FMA: AudioSet ya
incluye música). Es la descarga más grande (~17 GB).
'''),
    code('''
import io, numpy as np, soundfile as sf
from math import gcd
from scipy.signal import resample_poly
from huggingface_hub import hf_hub_download, snapshot_download
from tqdm import tqdm

def guardar_16k(path, data, sr):
    data = data.mean(axis=1) if data.ndim > 1 else data
    if sr != 16000:
        g = gcd(16000, sr)
        data = resample_poly(data, 16000 // g, sr // g)
    sf.write(path, (np.clip(data, -1, 1) * 32767).astype(np.int16), 16000, subtype='PCM_16')

# Ecos de habitaciones reales (MIT)
if not os.path.exists('mit_rirs'):
    repo = snapshot_download('davidscripka/MIT_environmental_impulse_responses', repo_type='dataset',
                             allow_patterns=['16khz/*'], local_dir='mit_rirs_repo')
    os.mkdir('mit_rirs')
    for f in tqdm(sorted(Path(repo, '16khz').glob('*.wav'))):
        guardar_16k(f'mit_rirs/{f.name}', *sf.read(f))

# Ruido ambiente y música (AudioSet, un bloque de ~690 MB)
if not os.path.exists('audioset_16k'):
    import pyarrow.parquet as pq
    os.mkdir('audioset_16k')
    tabla = pq.read_table(hf_hub_download('agkphysics/AudioSet', 'data/bal_train/09.parquet',
                                          repo_type='dataset', local_dir='audioset_repo'))
    for i, audio in enumerate(tqdm(tabla.column('audio').to_pylist())):
        try:
            guardar_16k(f'audioset_16k/{i}.wav', *sf.read(io.BytesIO(audio['bytes'])))
        except Exception:
            pass

# Características precalculadas: ~2.000 h de audio general (negativos) y validación
!wget -q -nc https://huggingface.co/datasets/davidscripka/openwakeword_features/resolve/main/openwakeword_features_ACAV100M_2000_hrs_16bit.npy
!wget -q -nc https://huggingface.co/datasets/davidscripka/openwakeword_features/resolve/main/validation_set_features.npy
'''),
    md('''
## 6. Voces en español y grabaciones reales

Se añaden **antes** que las voces en inglés: `train.py` solo genera los clips que falten
hasta `N_SAMPLES`.
'''),
    code('''
import importlib, ally_wakeword as aw
importlib.reload(aw)

base = Path('salida') / MODELO
pos_train, pos_test = base / 'positive_train', base / 'positive_test'
neg_train, neg_test = base / 'negative_train', base / 'negative_test'
for d in (pos_train, pos_test, neg_train, neg_test):
    d.mkdir(parents=True, exist_ok=True)

hecho = base / 'espanol_listo.txt'   # fuera de las carpetas de clips
if hecho.exists():
    print(hecho.read_text())
else:
    resumen = []
    n = aw.generar_con_piper(pos_train, aw.FRASES_POSITIVAS_ES, variantes_por_frase=VARIANTES_PIPER, destino_test=pos_test)
    resumen.append(f'Piper positivos: {n}')
    n = aw.generar_con_piper(neg_train, aw.FRASES_NEGATIVAS_ES, variantes_por_frase=8, destino_test=neg_test)
    resumen.append(f'Piper negativos: {n}')
    if USAR_EDGE_TTS:
        n = aw.generar_con_edge_tts(pos_train, aw.FRASES_POSITIVAS_ES, variantes=VARIANTES_EDGE, destino_test=pos_test)
        resumen.append(f'Edge positivos: {n}')
        n = aw.generar_con_edge_tts(neg_train, aw.FRASES_NEGATIVAS_ES, variantes=1, destino_test=neg_test)
        resumen.append(f'Edge negativos: {n}')
    r = aw.importar_grabaciones(drive_dir / 'grabaciones', pos_train, pos_test, copias=COPIAS_POR_GRABACION)
    resumen.append(f'Grabaciones reales: {r}')
    n = aw.importar_negativas(drive_dir / 'grabaciones_negativas', neg_train, neg_test)
    resumen.append(f'Trozos negativos reales: {n}')
    hecho.write_text('\\n'.join(resumen))
    print('\\n'.join(resumen))
'''),
    md('## 7. Configuración del entrenamiento'),
    code('''
import yaml

config = yaml.load(open('openwakeword/examples/custom_model.yml').read(), yaml.Loader)
config.update({
    'model_name': MODELO,
    'target_phrase': aw.FRASES_POSITIVAS_EN,
    'custom_negative_phrases': aw.FRASES_NEGATIVAS_EN,
    'n_samples': N_SAMPLES,
    'n_samples_val': N_SAMPLES_VAL,
    'steps': STEPS,
    'layer_size': 64,   # el doble que el valor por defecto: más voces y acentos distintos
    'output_dir': './salida',
    'piper_sample_generator_path': './piper-sample-generator',
    'rir_paths': ['./mit_rirs'],
    'background_paths': ['./audioset_16k'],
    'background_paths_duplication_rate': [1],
    'false_positive_validation_data_path': 'validation_set_features.npy',
    'feature_data_files': {'ACAV100M_sample': 'openwakeword_features_ACAV100M_2000_hrs_16bit.npy'},
})
with open('hey_ally.yaml', 'w') as f:
    yaml.dump(config, f)
print(yaml.dump(config, allow_unicode=True))
'''),
    md('''
## 8. Entrenamiento

1. Genera con voces en inglés los clips que falten (~15-30 min; si falla, vuelve a ejecutar la celda).
2. Añade ruido, música y eco a todos los clips.
3. Entrena (~1 hora).
'''),
    code('!{sys.executable} openwakeword/openwakeword/train.py --training_config hey_ally.yaml --generate_clips'),
    code('!{sys.executable} openwakeword/openwakeword/train.py --training_config hey_ally.yaml --augment_clips'),
    code('!{sys.executable} openwakeword/openwakeword/train.py --training_config hey_ally.yaml --train_model'),
    md('''
## 9. Evaluación con voces que el modelo nunca oyó

Mide el porcentaje de «Hey Ally» detectados en las grabaciones reales reservadas para prueba
y en las voces en español de prueba, y las activaciones falsas por hora en conversación normal.
'''),
    code('''
import shutil
importlib.reload(aw)
modelos = Path('openwakeword/openwakeword/resources/models')
det = aw.Detector(f'salida/{MODELO}.onnx', modelos / 'melspectrogram.onnx', modelos / 'embedding_model.onnx')

def subconjunto(prefijo, nombre):
    carpeta = Path('evaluacion') / nombre
    shutil.rmtree(carpeta, ignore_errors=True)
    carpeta.mkdir(parents=True)
    for f in pos_test.glob(f'{prefijo}*.wav'):
        shutil.copy(f, carpeta / f.name)
    return carpeta if any(carpeta.iterdir()) else None

negativos = drive_dir / 'grabaciones_negativas'
negativos = negativos if any(negativos.rglob('*.*')) else None
for nombre, prefijo in [('grabaciones reales', 'real_'), ('voces en español', 'piper_'), ('voces Edge', 'edge_')]:
    carpeta = subconjunto(prefijo, prefijo.strip('_'))
    if not carpeta:
        continue
    r = aw.evaluar(det, carpeta, negativos)
    print(f'\\n{nombre}: {r["clips_positivos"]} clips' + (f', {r["horas_negativas"]} h de conversación' if negativos else ''))
    for umbral, fila in r['umbral'].items():
        print(f'  umbral {umbral}: detecta {fila["detectados"]} %' +
              (f' · {fila["falsas_por_hora"]} activaciones falsas/hora' if 'falsas_por_hora' in fila else ''))
'''),
    md('''
## 10. Guardar en Drive

Copia `resultado/hey_ally.onnx` a `app/assets/wakeword/hey_ally.onnx` y recompila la app.
Elige el umbral con la tabla anterior (el que detecte ≥ 90 % con menos de 1 activación
falsa por hora) y ajústalo en `WakeWordDetector.create(context, threshold = ...)`.
'''),
    code('''
destino = aw.copiar_modelo(f'salida/{MODELO}.onnx', drive_dir / 'resultado' / f'{MODELO}.onnx')
shutil.copy('hey_ally.yaml', drive_dir / 'resultado' / 'hey_ally.yaml')
print('Guardado en', destino)
if not USANDO_DRIVE:
    from google.colab import files
    files.download(str(destino))
'''),
]

notebook = {
    'cells': celdas,
    'metadata': {
        'accelerator': 'GPU',
        'colab': {'provenance': [], 'gpuType': 'T4'},
        'kernelspec': {'display_name': 'Python 3', 'name': 'python3'},
        'language_info': {'name': 'python'},
    },
    'nbformat': 4,
    'nbformat_minor': 0,
}

salida = AQUI / 'entrenar_hey_ally.ipynb'
salida.write_text(json.dumps(notebook, ensure_ascii=False, indent=1), encoding='utf-8')
print('Generado', salida)
