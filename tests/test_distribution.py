import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
ROOT=Path(__file__).parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
D=module('distribution',ROOT/'scripts/distribution.py')
E=module('encoding_gate',ROOT/'scripts/check-encoding.py')
class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.source=self.root/'source.txt';self.source.write_bytes(b'\xef\xbb\xbf'+E.PHRASES[0].encode('utf-8'));self.zip=self.root/'test.zip'
    def test_complete_extract_hash_and_two_independent_checks(self):
        files={'Foison-v1/LEIA-ME.txt':self.source};D.make_zip(self.zip,files);r=D.validate_zip(self.zip,files)
        self.assertEqual(r['files'],1);self.assertEqual(r['entries'][0]['method'],8)
        self.assertEqual(r['entries'][0]['sha256'],D.sha256(self.source))
    def test_hash_divergence_rejected(self):
        files={'readme.txt':self.source};D.make_zip(self.zip,files);self.source.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'differs'):D.validate_zip(self.zip,files)
    def test_truncation_rejected(self):
        D.make_zip(self.zip,{'a':self.source});self.zip.write_bytes(self.zip.read_bytes()[:-10])
        with self.assertRaises((ValueError,zipfile.BadZipFile)):D.validate_zip(self.zip)
    def test_unsafe_and_exotic_rejected(self):
        for name,method in [('../escape',8),('C:/absolute',8),('nome-\u00e9',8),('file',zipfile.ZIP_BZIP2)]:
            with self.subTest(name=name,method=method):
                with zipfile.ZipFile(self.zip,'w',compression=method) as z:z.writestr(name,'data')
                with self.assertRaises(ValueError):D.validate_zip(self.zip)
    def test_duplicate_rejected(self):
        with zipfile.ZipFile(self.zip,'w') as z:z.writestr('a','1');z.writestr('A','2')
        with self.assertRaises(ValueError):D.validate_zip(self.zip)
    def test_format_rename_rejected(self):
        self.zip.write_bytes(b'7z\xbc\xaf\x27\x1c')
        with self.assertRaises(ValueError):D.validate_zip(self.zip)
    def test_encoding_and_portuguese_roundtrip(self):
        self.assertGreater(len(E.audit()),10)
        for phrase in E.PHRASES:self.assertEqual(phrase,phrase.encode('utf-8-sig').decode('utf-8-sig'))
