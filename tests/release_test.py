"""Real Git ancestry/tag tests and offline CurseForge payload contracts."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import release
import publish_curseforge as cf


class ReleaseTests(unittest.TestCase):
    def toc(self, version='0.4.0'):
        return f'## Interface: 16001\n## Version: {version}\n## X-Curse-Project-ID: 1727059\n'

    def test_classification(self):
        for version, kind in [('0.4.0','release'),('0.4.0-alpha.1','alpha'),('0.4.0-beta.2','beta'),('0.4.0-rc.1','beta')]:
            with self.subTest(version=version):
                data=release.metadata('v'+version,self.toc(version))
                self.assertEqual(data['release_type'],kind)
                self.assertEqual(data['prerelease'],kind!='release')
                self.assertEqual(data['archive'],f'XPIsland-{version}.zip')
        for invalid in ['0.4.0','v01.2.3','v0.4.0-dev','v0.4.0;echo x','v0.4.0-alpha.0']:
            with self.assertRaises(ValueError): release.metadata(invalid,self.toc())

    def test_metadata_must_match(self):
        for toc in [self.toc('0.3.0'),self.toc().replace('16001','120001'),self.toc()+'## Interface-Classic: 11507\n',self.toc().replace('1727059','99')]:
            with self.assertRaises(ValueError): release.metadata('v0.4.0',toc)

    def test_exact_forever_only(self):
        data=release.metadata('v0.4.0',self.toc())
        versions=[{'id':1,'name':'1.60.1','gameVersionTypeID':517},{'id':2,'name':'1.60.0','gameVersionTypeID':88568}]
        with self.assertRaises(ValueError): cf.exact_version(versions,data)
        versions.append({'id':3,'name':'1.60.1','gameVersionTypeID':88568})
        self.assertEqual(cf.exact_version(versions,data),3)
        with self.assertRaises(ValueError): cf.exact_version(versions+[versions[-1]],data)

    def test_tag_ancestry_and_annotation(self):
        with tempfile.TemporaryDirectory(prefix='xpisland-release-test-') as folder:
            path=Path(folder)
            def git(*args):
                return subprocess.check_output(['git',*args],cwd=path,text=True,stderr=subprocess.DEVNULL).strip()
            git('init','-b','main');git('config','commit.gpgsign','false');git('config','tag.gpgsign','false');git('config','user.name','Release test');git('config','user.email','test@example.invalid')
            (path/'file').write_text('one');git('add','file');git('commit','-m','base')
            git('update-ref','refs/remotes/origin/main','HEAD')
            git('tag','-a','v0.4.0','-m','Release 0.4.0')
            self.assertEqual(release.check_tag('v0.4.0',path),git('rev-parse','HEAD'))
            git('tag','v0.4.1')
            with self.assertRaises(ValueError): release.check_tag('v0.4.1',path)
            git('checkout','-b','unmerged');(path/'file').write_text('two');git('commit','-am','off-main');git('tag','-a','v0.4.2','-m','Off-main')
            with self.assertRaises(ValueError): release.check_tag('v0.4.2',path)
            with self.assertRaises(ValueError): release.check_tag('v0.4.0',path)
            git('checkout','main');git('merge','--ff-only','unmerged');git('update-ref','refs/remotes/origin/main','HEAD')
            self.assertEqual(release.check_tag('v0.4.2',path),git('rev-parse','HEAD'))

    def test_multipart_preserves_exact_zip(self):
        with tempfile.TemporaryDirectory() as folder:
            archive=Path(folder)/'XPIsland-0.4.0.zip';archive.write_bytes(b'PK\x00\xff\x01')
            data={'gameVersions':[123], 'releaseType':'release'}
            body,content_type=cf.multipart(data,archive)
            self.assertIn(json.dumps(data).encode(),body);self.assertIn(archive.read_bytes(),body)
            self.assertIn(b'name="file"; filename="XPIsland-0.4.0.zip"',body)
            self.assertTrue(content_type.startswith('multipart/form-data; boundary=XPIsland-'))


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'dist').mkdir();(self.root/'docs/releases').mkdir(parents=True)
        self.data = release.metadata('v0.4.0',ReleaseTests().toc())
        (self.root/'dist/release.json').write_text(json.dumps(self.data))
        (self.root/'dist/XPIsland-0.4.0.zip').write_bytes(b'package bytes')
        (self.root/'dist/SHA256SUMS').write_text(cf.hashlib.sha256(b'package bytes').hexdigest()+'  XPIsland-0.4.0.zip')
        (self.root/'docs/releases/0.4.0.md').write_text('Release notes')
        self.assets=[];self.calls=[]
        def gh(*args):
            self.calls.append(('gh',args))
            if args[:2]==('release','view'): return json.dumps(self.assets)
            return ''
        def request(path,token,body=None,content_type=None):
            self.calls.append(('request',path))
            if body is None: return [{'id':33,'name':'1.60.1','gameVersionTypeID':88568}]
            return {'id':12345}
        for context in [patch.object(cf,'ROOT',self.root), patch.object(cf,'gh',side_effect=gh),
                        patch.object(cf,'request',side_effect=request), patch.dict(cf.os.environ,{'CF_API_TOKEN':'unit-test-only'})]:
            context.start();self.addCleanup(context.stop)

    def test_success_records_receipt_after_pending_marker(self):
        cf.main()
        receipt=json.loads((self.root/'dist/curseforge-receipt.json').read_text())
        self.assertEqual(receipt['file_id'],12345);self.assertEqual(receipt['release_type'],'release')
        self.assertEqual(receipt['game_version_id'],33)
        post=next(i for i,c in enumerate(self.calls) if c[0]=='request' and c[1].endswith('upload-file'))
        pending=next(i for i,c in enumerate(self.calls) if c[0]=='gh' and 'curseforge-upload-pending.json' in c[1][-1])
        self.assertLess(pending,post)
        self.assertEqual(self.calls[-1][1][:2],('release','delete-asset'))

    def test_receipt_prevents_duplicate_upload(self):
        self.assets=['curseforge-receipt.json'];cf.main()
        self.assertFalse(any(c[0]=='request' for c in self.calls))

    def test_pending_marker_blocks_uncertain_retry(self):
        self.assets=['curseforge-upload-pending.json']
        with self.assertRaises(ValueError): cf.main()
        self.assertFalse(any(c[0]=='request' for c in self.calls))

    def test_post_timeout_is_not_retried(self):
        original=cf.request.side_effect
        def timeout(path,*args):
            if path.endswith('upload-file'): raise TimeoutError('simulated network delay')
            return original(path,*args)
        cf.request.side_effect=timeout
        with self.assertRaises(TimeoutError): cf.main()
        self.assertEqual(cf.request.call_count,2) # one GET, one POST
        self.assertTrue((self.root/'dist/curseforge-upload-pending.json').exists())
        self.assertFalse((self.root/'dist/curseforge-receipt.json').exists())

    def test_missing_token_and_bad_hash_prevent_requests(self):
        with patch.dict(cf.os.environ,{'CF_API_TOKEN':''}):
            with self.assertRaises(ValueError): cf.main()
        (self.root/'dist/SHA256SUMS').write_text('bad')
        with self.assertRaises(ValueError): cf.main()
        self.assertEqual(cf.request.call_count,0)


if __name__ == '__main__':
    unittest.main()
