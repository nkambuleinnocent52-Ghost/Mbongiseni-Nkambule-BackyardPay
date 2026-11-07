"""Fail packaging for malformed HTML, paths, missing assets or unexpected scripts.
This is a release integrity check, not an antivirus verdict.
"""
from pathlib import Path, PurePosixPath
from html.parser import HTMLParser
import hashlib
import json
import zipfile

REQUIRED = {'index.html','main.dart.js','flutter_bootstrap.js','startup.js','startup.css','_headers','_redirects','manifest.json','version.json'}
EXTENSIONS = {'.html','.js','.css','.json','.bin','.ttf','.otf','.frag','.wasm','.symbols','.png','.svg'}
SPECIAL = {'_headers','_redirects','NOTICES','AssetManifest.bin'}
class Entry(HTMLParser):
    def __init__(self):
        super().__init__(); self.scripts=[]; self.references=[]; self.csp=None; self.inline_script=False; self.in_script=False
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag=='script':
            self.in_script=True
            assert attrs.get('src'), 'Inline scripts are not part of this entry page'
            self.scripts.append(attrs['src']);self.references.append(attrs['src'])
        if tag=='link' and attrs.get('href'):self.references.append(attrs['href'])
        if tag=='meta' and attrs.get('http-equiv','').lower()=='content-security-policy':self.csp=attrs['content']
        assert not any(k.lower().startswith('on') for k in attrs), 'Unexpected inline event handler'
    def handle_endtag(self,tag):
        if tag=='script':self.in_script=False
    def handle_data(self,data):
        if self.in_script and data.strip():self.inline_script=True

def validate(files):
    assert REQUIRED <= files.keys(), f'Missing release files: {REQUIRED-files.keys()}'
    assert files['index.html'].startswith(b'<!doctype html>')
    assert b'$FLUTTER_BASE_HREF' not in files['index.html']
    entry=Entry();entry.feed(files['index.html'].decode('utf-8'))
    assert entry.scripts==['startup.js','flutter_bootstrap.js'] and not entry.inline_script
    assert entry.csp and "object-src 'none'" in entry.csp and "script-src 'self' 'wasm-unsafe-eval'" in entry.csp
    for reference in entry.references:
        assert reference in files, f'Entry asset missing: {reference}'
    for name in files:
        path=PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts and '\\' not in name, f'Unsafe path: {name}'
        assert path.suffix in EXTENSIONS or path.name in SPECIAL, f'Unexpected deployed file: {name}'
    assert b'serviceWorkerSettings: {' not in files['flutter_bootstrap.js'], 'Do not configure the old Flutter offline cache'
    assert b'retirePreviousFlutterCache' in files['flutter_bootstrap.js']
    assert b'onEntrypointLoaded: async' in files['flutter_bootstrap.js']
    assert b'Cache-Control: no-cache' in files['_headers']
    assert files['_redirects'].strip()==b'/* /index.html 200'
    version=json.loads(files['version.json']);assert version['version']=='1.0.2' and version['build_number']=='3'
    return {name:hashlib.sha256(data).hexdigest() for name,data in sorted(files.items())}

def from_directory(root):
    return {str(p.relative_to(root)):p.read_bytes() for p in root.rglob('*') if p.is_file() and p.name!='.last_build_id'}

if __name__=='__main__':
    import sys
    path=Path(sys.argv[1] if len(sys.argv)>1 else 'build/web')
    if path.is_dir(): files=from_directory(path)
    else:
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None
            assert len(archive.namelist())==len(set(archive.namelist()))
            files={name:archive.read(name) for name in archive.namelist()}
    sums=validate(files)
    if 'release-integrity.json' in files:
        declared=json.loads(files['release-integrity.json'])
        assert declared=={k:v for k,v in sums.items() if k!='release-integrity.json'}, 'Release manifest does not match contents'
    print(f'Release integrity passed: {len(files)} files; all entry assets present; script policy and archive paths valid.')
