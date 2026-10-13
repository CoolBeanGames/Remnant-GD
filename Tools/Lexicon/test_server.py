"""Exercise the actual local editor server and its save/revision boundary."""
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from lexicon import Editor, create_server


class LocalServerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.project = Path(self.temporary.name)
        (self.project / 'project.godot').write_text('config_version=5\n')
        self.editor = Editor(self.project)
        self.server = create_server(self.editor)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = 'http://127.0.0.1:' + str(self.server.server_port)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(2)
        self.editor.temporary.cleanup()
        self.temporary.cleanup()

    def request(self, path, payload=None, headers=None):
        values = {'X-Lexicon-Token': self.editor.token, 'Content-Type': 'application/json'}
        values.update(headers or {})
        request = Request(self.url + path, data=json.dumps(payload).encode() if payload is not None else None, headers=values)
        with urlopen(request, timeout=5) as response:
            return json.load(response)

    def test_browser_requests_need_this_session_and_origin(self):
        self.assertEqual(self.request('/api/state')['revision'], 0)
        for headers in [{'X-Lexicon-Token': 'wrong'}, {'Origin': 'https://unrelated.example'}, {'Host': 'unrelated.example'}]:
            with self.assertRaises(HTTPError) as failure:
                self.request('/api/state', headers=headers)
            self.assertEqual(failure.exception.code, 403)

    def test_save_is_persistent_and_stale_revision_cannot_overwrite(self):
        state = self.request('/api/state')
        state['database']['notes'].append({'id': 'letter', 'title': 'Letter', 'text': 'Original words', 'image': ''})
        saved = self.request('/api/save', state)
        self.assertEqual(saved['revision'], 1)
        with self.assertRaises(HTTPError) as failure:
            self.request('/api/save', state)
        self.assertEqual(failure.exception.code, 400)
        reopened = self.request('/api/open', {'path': str(self.project)})
        self.assertEqual(reopened['database']['notes'][0]['text'], 'Original words')

    def test_malformed_request_and_arbitrary_media_are_rejected(self):
        with self.assertRaises(HTTPError) as failure:
            self.request('/api/save', [])
        self.assertEqual(failure.exception.code, 400)
        with self.assertRaises(ValueError):
            self.editor.media(str(self.project / 'project.godot'))
        with self.assertRaises(ValueError):
            self.editor.media('../outside.png')


if __name__ == '__main__':
    unittest.main()
