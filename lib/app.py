from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import yt_dlp
import os
import re
import logging

app = Flask(__name__)
CORS(app)  # Permite solicitudes CORS desde cualquier origen

# Ruta de FFmpeg (asegúrate de que esta ruta sea correcta en tu sistema)
FFMPEG_PATH = r'C:\ffmpeg-2025-02-26-git-99e2af4e78-essentials_build\bin'
ffmpeg_exe = os.path.join(FFMPEG_PATH, 'ffmpeg.exe')
if not os.path.isfile(ffmpeg_exe):
    raise FileNotFoundError(f"FFmpeg no se encontró en {ffmpeg_exe}")

# Directorio donde se guardan los archivos generados
DOWNLOADS_DIR = 'Descargas'
os.makedirs(DOWNLOADS_DIR, exist_ok=True)

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("youtube_downloader.log"),
        logging.StreamHandler()
    ]
)

def limpiar_nombre(nombre: str) -> str:
    """Limpia el nombre del archivo removiendo caracteres no válidos."""
    return re.sub(r'[\\/:*?"<>|]', '_', nombre)

def obtener_nombre_limpio(url: str) -> str:
    """Extrae información del video y retorna un título limpio para el archivo."""
    with yt_dlp.YoutubeDL({'ffmpeg_location': FFMPEG_PATH}) as ydl:
        info = ydl.extract_info(url, download=False)
        title = info.get('title', 'video')
        return limpiar_nombre(title)

@app.route('/info', methods=['GET'])
def info():
    url = request.args.get('url')
    if not url:
        return jsonify({'error': 'Falta el parámetro URL'}), 400

    ydl_opts = {'ffmpeg_location': FFMPEG_PATH}
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_data = ydl.extract_info(url, download=False)
            result = {
                'title': limpiar_nombre(info_data.get('title', '')),
                'thumbnail': info_data.get('thumbnail', ''),
                'description': info_data.get('description', ''),
                'upload_date': info_data.get('upload_date', '')
            }
            return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/download', methods=['POST'])
def download():
    # Se aceptan tanto form-data como JSON
    data = request.form if request.form else request.get_json()
    url = data.get('url')
    fmt = data.get('format')
    if not url or not fmt:
        return jsonify({'error': 'Falta la URL o el formato'}), 400

    app.logger.info(f"Iniciando descarga: URL={url}, formato={fmt}")
    try:
        # Obtener nombre limpio y definir extensión
        title = obtener_nombre_limpio(url)
        file_ext = "mp3" if fmt.upper() == "MP3" else "mp4"
        output_template = os.path.join(DOWNLOADS_DIR, f"{title}.%(ext)s")

        # Configuración de yt_dlp según formato
        ydl_opts = {
            'ffmpeg_location': FFMPEG_PATH,
            'outtmpl': output_template,
            'noplaylist': True,
        }
        if fmt.upper() == "MP3":
            ydl_opts.update({
                'format': 'bestaudio/best',
                'postprocessors': [{
                    'key': 'FFmpegExtractAudio',
                    'preferredcodec': 'mp3',
                    'preferredquality': '192',
                }],
            })
        else:
            # MP4: Se copia el stream de video y se reencodifica el audio a AAC
            ydl_opts.update({
                'format': 'bestvideo+bestaudio/best',
                'merge_output_format': 'mp4',
                'postprocessor_args': ['-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k'],
            })

        # Descargar y procesar el video/audio
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])

        # Nombre final y ruta del archivo generado
        filename = f"{title}.{file_ext}"
        output_file = os.path.join(DOWNLOADS_DIR, filename)
        if not os.path.exists(output_file):
            raise FileNotFoundError(f"El archivo descargado no se encontró: {output_file}")
        if os.path.getsize(output_file) <= 0:
            raise Exception("El archivo generado está vacío.")

        # Definir MIME type según formato
        mimetype = "audio/mpeg" if file_ext == "mp3" else "video/mp4"

        # Enviar el archivo al navegador
        return send_file(
            output_file,
            as_attachment=True,
            download_name=filename,
            mimetype=mimetype,
            conditional=False  # Asegura una transferencia completa
        )
    except Exception as e:
        app.logger.error(f"Error en /download: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)
