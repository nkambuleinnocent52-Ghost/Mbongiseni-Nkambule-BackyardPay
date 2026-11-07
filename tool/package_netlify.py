"""Package the rebuilt 1.0.1 release after integrity checks; preserve the old flagged ZIP."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile
from validate_web_release import validate, from_directory

root=Path(__file__).resolve().parent.parent
out=root/'downloads'
files=from_directory(root/'build/web')
files.pop('release-integrity.json',None)
sums=validate(files)
files['release-integrity.json']=(json.dumps(sums,indent=2,sort_keys=True)+'\n').encode()

def write_zip(destination,contents):
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name,data in sorted(contents.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,11,7,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o100644<<16
            archive.writestr(info,data)
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None

write_zip(out/'BackyardPay-Netlify-web.zip',files)
source={}
for name in set(subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard'],cwd=root).decode().split('\0')):
    if not name or name.split('/')[0] in {'downloads','build','.dart_tool','.git'}:continue
    path=root/name
    if path.is_file():
        assert path.name not in {'.env','key.properties'} and path.suffix not in {'.pem','.key','.p12','.jks'}, f'Unexpected secret file: {name}'
        source[name]=path.read_bytes()
write_zip(out/'BackyardPay-Netlify-source.zip',source)
(out/'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in sorted(out.iterdir()) if p.is_file() and p.name!='SHA256SUMS'))
print(f'Packaged web ZIP ({len(files)} files), source ZIP and checksums. Old research archive unchanged.')
