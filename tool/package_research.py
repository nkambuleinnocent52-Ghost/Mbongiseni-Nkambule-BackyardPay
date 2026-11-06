"""Build review/download artifacts from the verified release; never includes .git or private settings."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
out = root / 'downloads'
out.mkdir(exist_ok=True)
upgrade = '\n\n'.join((root / 'supabase/migrations' / name).read_text() for name in [
    '202611060001_research_accounts.sql', '202611060002_private_documents.sql'])
(out / 'BackyardPay-Research-Update.sql').write_text(upgrade)
with zipfile.ZipFile(out / 'BackyardPay-Research-web.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted((root / 'build/web').rglob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(root / 'build/web'))
with zipfile.ZipFile(out / 'BackyardPay-Research-web.zip') as archive:
    assert 'index.html' in archive.namelist()
    assert archive.testzip() is None
files = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).decode().split('\0')
with zipfile.ZipFile(out / 'BackyardPay-Research-source.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in sorted(set(files)):
        if not name or name.split('/')[0] in ('downloads', 'build', '.dart_tool', '.git'):
            continue
        file = root / name
        if file.is_file():
            archive.write(file, name)
with zipfile.ZipFile(out / 'BackyardPay-Research-source.zip') as archive:
    assert archive.testzip() is None
# Render the audit as an easy-to-open companion; it is not the final page-limited report.
from docx import Document
from docx.shared import Inches, Pt
doc = Document()
doc.sections[0].top_margin = Inches(.65)
doc.sections[0].bottom_margin = Inches(.65)
doc.styles['Normal'].font.name = 'Calibri'
doc.styles['Normal'].font.size = Pt(10)
lines = (root / 'docs/research/Implementation-Audit-2026-11-06.md').read_text().splitlines()
i = 0
while i < len(lines):
    line = lines[i]
    if line.startswith('|'):
        rows = []
        while i < len(lines) and lines[i].startswith('|'):
            row = [v.strip().replace('**', '') for v in lines[i].strip('|').split('|')]
            if not all(set(v) <= set('-: ') for v in row):
                rows.append(row)
            i += 1
        table = doc.add_table(rows=1, cols=len(rows[0]))
        table.style = 'Light Shading Accent 1'
        for cell, value in zip(table.rows[0].cells, rows[0]):
            cell.text = value
        for row in rows[1:]:
            for cell, value in zip(table.add_row().cells, row):
                cell.text = value
        continue
    if line.startswith('#'):
        doc.add_heading(line.lstrip('# '), min(3, len(line) - len(line.lstrip('#'))))
    elif line:
        doc.add_paragraph(line.replace('**', ''))
    i += 1
doc.save(out / 'BackyardPay-Implementation-Audit.docx')
checksums = []
for file in sorted(out.iterdir()):
    if file.is_file() and file.name != 'SHA256SUMS':
        checksums.append(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}')
(out / 'SHA256SUMS').write_text('\n'.join(checksums) + '\n')
print('Packaged research web/source ZIPs, additive SQL and checksums.')
