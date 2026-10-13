"""Meaningful exporter checks including shared assets, rollback and clean portability."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import model

PLUGIN = Path(__file__).resolve().parents[2] / 'addons/lexicon'


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Lexicon Test"\n')
        self.image = self.root / 'original.png'
        self.image.write_bytes(b'fixture image')
        self.voice = self.root / 'voice.wav'
        self.voice.write_bytes(b'fixture voice')
        self.db = model.empty_database()
        self.db['notes'] = [{'id': 'note_1', 'title': 'Letter', 'text': 'A quote: "Hello"\nNew line <script>', 'image': str(self.image)}, {'id': 'note_2', 'title': 'Second', 'text': 'Shared picture', 'image': str(self.image)}]
        self.db['dialog'] = [{'id': 'conversation_1', 'title': 'A choice', 'start_line': 'start', 'lines': [
            {'id': 'start', 'speaker': 'Someone', 'text': 'Stay?', 'audio': str(self.voice), 'next': '', 'choices': [{'label': 'Yes', 'target': 'end'}, {'label': 'No', 'target': ''}]},
            {'id': 'end', 'speaker': '', 'text': 'Okay.', 'audio': str(self.voice), 'next': '', 'choices': []}]}]
        self.db['flavor'] = [{'id': 'flavor_1', 'title': 'Cold coffee', 'lines': [{'id': 'line_1', 'speaker': '', 'text': 'Cold.', 'audio': str(self.voice)}]}]

    def tearDown(self):
        self.directory.cleanup()

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}

    def test_master_lists_and_portable_reopen(self):
        result = model.export(self.root, self.db, PLUGIN)
        self.assertEqual(result['assets'], 3)
        for path in ['lexicon/lexicon_db.tres', 'lexicon/notes/note_db.tres', 'lexicon/dialog/conversation_db.tres', 'lexicon/flavor/flavor_db.tres', 'lexicon/notes/note_1.tres']:
            self.assertTrue((self.root / path).is_file())
        reopened = model.open_library(self.root)
        self.assertEqual(reopened['notes'][0]['text'], self.db['notes'][0]['text'])
        self.assertTrue(reopened['notes'][0]['image'].startswith('lexicon/notes/images/'))
        self.assertEqual(reopened['dialog'][0]['lines'][0]['choices'][0]['target'], 'end')
        self.assertEqual(model.export(self.root, reopened, PLUGIN)['removed'], 0)

    def test_shared_asset_retained_until_last_reference(self):
        saved = model.export(self.root, self.db, PLUGIN)['database']
        picture = self.root / saved['notes'][0]['image']
        saved['notes'].pop(0)
        saved = model.export(self.root, saved, PLUGIN)['database']
        self.assertTrue(picture.is_file())
        self.assertFalse((self.root / 'lexicon/notes/note_1.tres').exists())
        saved['notes'].clear()
        model.export(self.root, saved, PLUGIN)
        self.assertFalse(picture.exists())
        self.assertTrue(self.image.exists())
        self.assertTrue(self.voice.exists())

    def test_invalid_branch_and_reserved_or_case_duplicate_ids_rejected(self):
        for change in ['branch', 'reserved', 'duplicate', 'escape']:
            db = copy.deepcopy(self.db)
            if change == 'branch': db['dialog'][0]['lines'][0]['choices'][0]['target'] = 'gone'
            elif change == 'reserved': db['notes'][0]['id'] = 'note_db'
            elif change == 'duplicate': db['notes'][1]['id'] = 'NOTE_1'
            else: db['notes'][0]['id'] = '../escape'
            with self.assertRaises(ValueError): model.export(self.root, db, PLUGIN)
            self.assertFalse((self.root / 'lexicon').exists())

    def test_unowned_and_modified_obsolete_files_protected(self):
        (self.root / 'lexicon/notes').mkdir(parents=True)
        unowned = self.root / 'lexicon/notes/note_1.tres'
        unowned.write_text('personal resource')
        with self.assertRaises(ValueError): model.export(self.root, self.db, PLUGIN)
        self.assertEqual(unowned.read_text(), 'personal resource')
        unowned.unlink()
        saved = model.export(self.root, self.db, PLUGIN)['database']
        unowned.write_text('external edit')
        saved['notes'].pop(0)
        with self.assertRaises(ValueError): model.export(self.root, saved, PLUGIN)
        self.assertEqual(unowned.read_text(), 'external edit')

    def test_write_failure_rolls_back_existing_export(self):
        saved = model.export(self.root, self.db, PLUGIN)['database']
        before = self.snapshot()
        saved['notes'][0]['text'] = 'changed'
        real_write = model.atomic_write
        calls = [0]
        def fail_once(path, data):
            calls[0] += 1
            if calls[0] == 3: raise OSError('simulated disk failure')
            real_write(path, data)
        with patch.object(model, 'atomic_write', side_effect=fail_once):
            with self.assertRaises(OSError): model.export(self.root, saved, PLUGIN)
        self.assertEqual(self.snapshot(), before)

    def test_malicious_manifest_and_symlink_cannot_escape(self):
        (self.root / 'lexicon').mkdir()
        (self.root / 'lexicon/.lexicon-manifest.json').write_text(json.dumps({'version': 1, 'files': {'../outside.txt': 'fake'}}))
        with self.assertRaises(ValueError): model.export(self.root, self.db, PLUGIN)
        with self.assertRaises(ValueError): model.safe_path(self.root, '../outside')

    def test_malformed_libraries_fail_before_writing(self):
        malformed = [None, [], {'version': 1, 'notes': [None], 'dialog': [], 'flavor': []}]
        for field, value in [('choices', 'wrong'), ('choices', [None]), ('audio', None)]:
            db = copy.deepcopy(self.db)
            db['dialog'][0]['lines'][0][field] = value
            malformed.append(db)
        db = copy.deepcopy(self.db)
        db['dialog'][0]['start_line'] = []
        malformed.append(db)
        for db in malformed:
            with self.assertRaises(ValueError): model.export(self.root, db, PLUGIN)
            self.assertFalse((self.root / 'lexicon').exists())

    def test_prune_failure_restores_shared_assets_and_import_descriptors(self):
        saved = model.export(self.root, self.db, PLUGIN)['database']
        picture = self.root / saved['notes'][0]['image']
        picture.with_suffix(picture.suffix + '.import').write_text('generated import metadata')
        before = self.snapshot()
        saved['notes'].clear()
        real_write = model.atomic_write
        failed = [False]
        def fail_manifest_once(path, data):
            if path.name == '.lexicon-manifest.json' and not failed[0]:
                failed[0] = True
                raise OSError('simulated manifest failure after pruning')
            real_write(path, data)
        with patch.object(model, 'atomic_write', side_effect=fail_manifest_once):
            with self.assertRaises(OSError): model.export(self.root, saved, PLUGIN)
        self.assertEqual(self.snapshot(), before)


if __name__ == '__main__':
    unittest.main()
