"""Standalone local Lexicon editor. No service, account or game installation needed."""
from __future__ import annotations
import argparse
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import webbrowser
from urllib.parse import parse_qs, urlsplit
from model import AUDIO_EXTENSIONS, IMAGE_EXTENSIONS, atomic_write, digest, empty_database, export, open_library, safe_path

APP = Path(getattr(sys, '_MEIPASS', Path(__file__).parent))
PLUGIN = APP / 'plugin' if getattr(sys, 'frozen', False) else Path(__file__).resolve().parents[2] / 'addons/lexicon'


class Editor:
    def __init__(self, project=None):
        self.project = Path(project).resolve() if project else None
        self.database = open_library(self.project) if self.project else empty_database()
        self.revision = 0
        self.lock = threading.RLock()
        self.temporary = tempfile.TemporaryDirectory(prefix='lexicon-uploads-')
        self.uploads = Path(self.temporary.name)
        self.token = secrets.token_hex(32)

    def state(self):
        return {'project': str(self.project) if self.project else '', 'database': self.database, 'revision': self.revision}

    def open(self, path):
        project = Path(path).expanduser().resolve()
        if not (project / 'project.godot').is_file():
            raise ValueError('Choose the folder containing project.godot.')
        database = open_library(project)
        self.project, self.database = project, database
        self.revision += 1
        return self.state()

    def save(self, payload):
        if self.project is None:
            raise ValueError('Open a Godot project before saving.')
        if payload.get('revision') != self.revision:
            raise ValueError('This library changed in another tab. Reopen it before overwriting.')
        result = export(self.project, payload['database'], PLUGIN)
        self.database = result.pop('database')
        self.revision += 1
        return {**self.state(), 'export': result}

    def upload(self, payload):
        suffix = Path(payload['name']).suffix.lower()
        if suffix not in AUDIO_EXTENSIONS | IMAGE_EXTENSIONS:
            raise ValueError('Use PNG/JPEG/WebP images or WAV/OGG/MP3 audio.')
        data = base64.b64decode(payload['data'], validate=True)
        if not data or len(data) > 100 * 1024 * 1024:
            raise ValueError('Choose a nonempty file smaller than 100 MB.')
        path = self.uploads / (digest(data) + suffix)
        atomic_write(path, data)
        return {'path': str(path)}

    def media(self, reference):
        path = Path(reference)
        if not path.is_absolute():
            if self.project is None:
                raise ValueError('No project selected.')
            path = safe_path(self.project, reference)
            if not path.is_relative_to(self.project / 'lexicon'):
                raise ValueError('Media must belong to this library.')
        else:
            path = path.resolve()
            if not path.is_relative_to(self.uploads):
                raise ValueError('Media must be an uploaded asset.')
        if not path.is_file() or path.suffix.lower() not in AUDIO_EXTENSIONS | IMAGE_EXTENSIONS:
            raise ValueError('Media file is unavailable.')
        return path


def create_server(editor, port=0):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def send(self, body, status=200, mime='application/json'):
            if isinstance(body, dict):
                body = json.dumps(body, ensure_ascii=False).encode('utf8')
            self.send_response(status)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(body)

        def authorized(self):
            query = parse_qs(urlsplit(self.path).query)
            token = self.headers.get('X-Lexicon-Token', query.get('session', [''])[0])
            expected_host = '127.0.0.1:' + str(self.server.server_port)
            origin = self.headers.get('Origin')
            return secrets.compare_digest(token, editor.token) and self.headers.get('Host') == expected_host and origin in (None, 'http://' + expected_host)

        def do_GET(self):
            if not self.authorized():
                self.send({'error': 'This Lexicon session is unavailable.'}, 403)
                return
            route = urlsplit(self.path).path
            try:
                with editor.lock:
                    if route == '/':
                        self.send((APP / 'index.html').read_bytes(), mime='text/html; charset=utf-8')
                    elif route == '/api/state':
                        self.send(editor.state())
                    elif route == '/api/media':
                        reference = parse_qs(urlsplit(self.path).query).get('path', [''])[0]
                        path = editor.media(reference)
                        self.send(path.read_bytes(), mime=mimetypes.guess_type(path.name)[0] or 'application/octet-stream')
                    else:
                        self.send({'error': 'Unknown request.'}, 404)
            except (ValueError, OSError, json.JSONDecodeError) as error:
                self.send({'error': str(error)}, 400)

        def do_POST(self):
            if not self.authorized():
                self.send({'error': 'This Lexicon session is unavailable.'}, 403)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if length <= 0 or length > 140 * 1024 * 1024:
                    raise ValueError('Request is empty or too large.')
                payload = json.loads(self.rfile.read(length))
                if not isinstance(payload, dict):
                    raise ValueError('Expected an object request.')
                with editor.lock:
                    route = urlsplit(self.path).path
                    if route == '/api/open':
                        self.send(editor.open(payload['path']))
                    elif route == '/api/save':
                        self.send(editor.save(payload))
                    elif route == '/api/upload':
                        self.send(editor.upload(payload))
                    elif route == '/api/browse':
                        import tkinter as tk
                        from tkinter import filedialog
                        window = tk.Tk()
                        window.withdraw()
                        window.attributes('-topmost', True)
                        path = filedialog.askdirectory(parent=window, title='Select a Godot project folder')
                        window.destroy()
                        self.send({'path': path})
                    elif route == '/api/close':
                        self.send({'closed': True})
                        threading.Thread(target=self.server.shutdown, daemon=True).start()
                    else:
                        self.send({'error': 'Unknown request.'}, 404)
            except (ValueError, OSError, KeyError, TypeError) as error:
                self.send({'error': str(error)}, 400)
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.daemon_threads = True
    return server


def main():
    parser = argparse.ArgumentParser(description='Lexicon: reusable notes, branching dialog and flavor authoring.')
    parser.add_argument('--project', type=Path)
    parser.add_argument('--library', type=Path, help='JSON library for deterministic agent/CLI authoring.')
    parser.add_argument('--export-only', action='store_true')
    parser.add_argument('--no-browser', action='store_true')
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--session-file', type=Path, help='Write local test/launcher connection information.')
    args = parser.parse_args()
    if args.export_only:
        if args.project is None or args.library is None:
            parser.error('--export-only needs --project and --library.')
        result = export(args.project, json.loads(args.library.read_text(encoding='utf8')), PLUGIN)
        result.pop('database')
        if sys.stdout is not None:
            print(json.dumps(result))
        return
    editor = Editor(args.project)
    server = create_server(editor, args.port)
    url = f'http://127.0.0.1:{server.server_port}/?session={editor.token}'
    if args.session_file:
        atomic_write(args.session_file, json.dumps({'url': url, 'port': server.server_port, 'token': editor.token}).encode())
    if not args.no_browser:
        webbrowser.open(url)
    if sys.stdout is not None:
        print('Lexicon / ' + url, flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        editor.temporary.cleanup()


if __name__ == '__main__':
    main()
