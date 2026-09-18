"""
Перенесення медіа сигналів із Google Drive у Firebase Storage.

Навіщо: Drive не призначений для віддачі файлів у браузер — запити йдуть із
кукі користувача, на 403 немає CORS-заголовків, потрібен проксі та його кеш.
Storage віддає файли з CDN, з Range і CORS, і ним же користується адмін-панель.

Два етапи, щоб між ними можна було переглянути результат:

    python migrate_media_to_storage.py fetch
        читає сигнали з Firestore, завантажує кожен Drive-файл у теку
        media_migration/, аудіо перекодовує в 96 kbps mono (ffmpeg),
        решту лишає як є; пише manifest.json. Нічого не змінює ззовні.

    python migrate_media_to_storage.py push
        за manifest.json заливає файли в Storage як
        signals/<поле>/<docId>.<ext> і підставляє download-URL у Firestore.
        Старі Drive-посилання зберігаються в полі driveBackup документа —
        щоб можна було відкотити.

    python migrate_media_to_storage.py rollback
        повертає посилання з driveBackup.

Параметри: --bitrate 96, --dir <тека>, --ffmpeg <шлях>, --dry-run (для push:
показати, що буде зроблено, без запитів на запис).
"""

import argparse
import json
import mimetypes
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

# Консоль Windows типово в cp1251 і падає на «→» та інших символах виводу.
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

API_KEY = 'AIzaSyAhVTO38rw3oN0zxgH5_kXGl8Ex6mWPoPE'  # публічний веб-ключ, той самий, що в main.dart.js
PROJECT_ID = 'huntingsignals'
BUCKET = 'huntingsignals.firebasestorage.app'
FIRESTORE = f'https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents'
STORAGE = f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o'

# Поля документа сигналу, в яких лежать посилання на файли.
AUDIO_FIELDS = ('audioUrl', 'notationAudioUrl')
OTHER_FIELDS = ('videoUrl', 'videoUrl2', 'notationUrl', 'partitureUrl', 'imageUrl')
LIST_FIELDS = ('galleryImages',)

# mimetypes на Windows не знає webp — тримаємо власну таблицю.
CONTENT_TYPES = {
    'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav', 'm4a': 'audio/mp4',
    'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp', 'gif': 'image/gif',
    'mp4': 'video/mp4', 'webm': 'video/webm',
}

DRIVE_ID_RE = [
    re.compile(r'drive\.google\.com/file/d/([^/?]+)'),
    re.compile(r'lh3\.googleusercontent\.com/d/([^/?]+)'),
    re.compile(r'[?&]id=([^&]+)'),
]


def drive_id(url):
    for rx in DRIVE_ID_RE:
        m = rx.search(url)
        if m:
            return m.group(1)
    return None


def http(method, url, data=None, headers=None, timeout=300):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, dict(r.headers), r.read()


# ── Firestore ────────────────────────────────────────────────────────────────

def fs_value(v):
    """Firestore JSON → Python."""
    if 'stringValue' in v: return v['stringValue']
    if 'integerValue' in v: return int(v['integerValue'])
    if 'doubleValue' in v: return v['doubleValue']
    if 'booleanValue' in v: return v['booleanValue']
    if 'nullValue' in v: return None
    if 'arrayValue' in v: return [fs_value(x) for x in v['arrayValue'].get('values', [])]
    if 'mapValue' in v: return {k: fs_value(x) for k, x in v['mapValue'].get('fields', {}).items()}
    return v


def to_fs(v):
    """Python → Firestore JSON (лише те, що потрібно тут)."""
    if v is None: return {'nullValue': None}
    if isinstance(v, bool): return {'booleanValue': v}
    if isinstance(v, int): return {'integerValue': str(v)}
    if isinstance(v, float): return {'doubleValue': v}
    if isinstance(v, str): return {'stringValue': v}
    if isinstance(v, list): return {'arrayValue': {'values': [to_fs(x) for x in v]}}
    if isinstance(v, dict): return {'mapValue': {'fields': {k: to_fs(x) for k, x in v.items()}}}
    raise TypeError(type(v))


def load_signals():
    docs, token = [], None
    while True:
        url = f'{FIRESTORE}/signals?pageSize=100&key={API_KEY}'
        if token:
            url += f'&pageToken={token}'
        _, _, body = http('GET', url)
        page = json.loads(body)
        docs += page.get('documents', [])
        token = page.get('nextPageToken')
        if not token:
            break
    out = []
    for d in docs:
        out.append({
            'docId': d['name'].rsplit('/', 1)[1],
            'fields': {k: fs_value(v) for k, v in d.get('fields', {}).items()},
        })
    return out


def patch_signal(doc_id, fields, dry_run):
    """Оновлює лише перелічені поля (updateMask), решту документа не чіпає."""
    mask = '&'.join('updateMask.fieldPaths=' + urllib.parse.quote(k) for k in fields)
    url = f'{FIRESTORE}/signals/{doc_id}?{mask}&key={API_KEY}'
    body = json.dumps({'fields': {k: to_fs(v) for k, v in fields.items()}}).encode()
    if dry_run:
        print(f'      [dry-run] PATCH signals/{doc_id}: {", ".join(fields)}')
        return
    http('PATCH', url, body, {'Content-Type': 'application/json'})


# ── Storage ──────────────────────────────────────────────────────────────────

def storage_upload(path, data, content_type, dry_run):
    """Upload у Firebase Storage так, як це робить SDK (multipart: метадані +
    вміст, POST …/o?name=<шлях>); повертає download-URL з токеном."""
    encoded = urllib.parse.quote(path, safe='')
    if dry_run:
        print(f'      [dry-run] POST {path} ({len(data) // 1024} KB, {content_type})')
        return f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{encoded}?alt=media&token=DRY-RUN'

    boundary = 'migrate-' + str(abs(hash(path)))
    metadata = json.dumps({'name': path, 'contentType': content_type}).encode()
    crlf = '\r\n'
    body = (
        f'--{boundary}{crlf}Content-Type: application/json; charset=utf-8{crlf}{crlf}'.encode()
        + metadata
        + f'{crlf}--{boundary}{crlf}Content-Type: {content_type}{crlf}{crlf}'.encode()
        + data
        + f'{crlf}--{boundary}--'.encode()
    )
    _, _, resp = http('POST', f'{STORAGE}?name={encoded}&uploadType=multipart', body, {
        'Content-Type': f'multipart/related; boundary={boundary}',
        'X-Goog-Upload-Protocol': 'multipart',
    })
    meta = json.loads(resp)
    token = meta['downloadTokens'].split(',')[0]
    return f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/{encoded}?alt=media&token={token}'


# ── fetch ────────────────────────────────────────────────────────────────────

def sniff_ext(data, declared):
    if data[:3] == b'ID3' or (len(data) > 1 and data[0] == 0xFF and data[1] & 0xE0 == 0xE0):
        return 'mp3'
    if data[:8] == b'\x89PNG\r\n\x1a\n': return 'png'
    if data[:3] == b'\xff\xd8\xff': return 'jpg'
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP': return 'webp'
    if data[4:8] == b'ftyp': return 'mp4'
    if data[:4] == b'OggS': return 'ogg'
    ext = mimetypes.guess_extension(declared.split(';')[0].strip()) if declared else None
    return (ext or '.bin').lstrip('.')


def download_drive(file_id):
    url = (f'https://drive.usercontent.google.com/download?id={file_id}'
           '&export=download&authuser=0&confirm=t')
    status, headers, data = http('GET', url)
    ctype = headers.get('Content-Type', '')
    if 'text/html' in ctype:
        raise RuntimeError('Drive повернув HTML — файл не публічний або видалений')
    return data, ctype


def probe_audio(ffprobe, src):
    """(codec, channels, bit_rate) першого аудіопотоку."""
    r = subprocess.run(
        [ffprobe, '-v', 'error', '-select_streams', 'a:0',
         '-show_entries', 'stream=codec_name,channels,bit_rate', '-of', 'json', str(src)],
        capture_output=True, text=True, check=True,
    )
    st = json.loads(r.stdout)['streams'][0]
    return st.get('codec_name'), int(st.get('channels') or 0), int(st.get('bit_rate') or 0)


def reencode(ffmpeg, src, dst, bitrate):
    # -vn: обкладинка, вшита в mp3, інакше переїде в результат як відеопотік.
    subprocess.run(
        [ffmpeg, '-y', '-loglevel', 'error', '-i', str(src), '-vn',
         '-ac', '1', '-ar', '44100', '-b:a', f'{bitrate}k', '-map_metadata', '-1', str(dst)],
        check=True,
    )


def cmd_fetch(args):
    ffmpeg = args.ffmpeg or shutil.which('ffmpeg')
    if not ffmpeg:
        sys.exit('ffmpeg не знайдено: передайте --ffmpeg <шлях> або додайте в PATH')
    ffprobe = str(Path(ffmpeg).with_name('ffprobe' + Path(ffmpeg).suffix))
    out = Path(args.dir)
    (out / 'originals').mkdir(parents=True, exist_ok=True)
    (out / 'upload').mkdir(exist_ok=True)

    signals = load_signals()
    print(f'Сигналів у Firestore: {len(signals)}')
    manifest = []

    for s in signals:
        doc_id, f = s['docId'], s['fields']
        print(f'\n{doc_id}  {f.get("name", "")}')
        items = [(k, f[k]) for k in AUDIO_FIELDS + OTHER_FIELDS if f.get(k)]
        for k in LIST_FIELDS:
            for i, u in enumerate(f.get(k) or []):
                items.append((f'{k}[{i}]', u))

        for field, url in items:
            fid = drive_id(url)
            if not fid:
                print(f'   {field:<18} не Drive — лишаю як є')
                continue
            base = f'{doc_id}_{field}'.replace('[', '_').replace(']', '')
            existing = list((out / 'originals').glob(f'{base}.*'))
            if existing:
                # Повторний запуск — оригінал уже є, Drive не турбуємо.
                original = existing[0]
                data, ext = original.read_bytes(), original.suffix.lstrip('.')
                ctype = mimetypes.guess_type(str(original))[0] or ''
            else:
                try:
                    data, ctype = download_drive(fid)
                except Exception as e:
                    print(f'   {field:<18} ПОМИЛКА: {e}')
                    manifest.append({'docId': doc_id, 'field': field, 'from': url, 'error': str(e)})
                    continue
                ext = sniff_ext(data, ctype)
                original = out / 'originals' / f'{base}.{ext}'
                original.write_bytes(data)

            is_audio = ext in ('mp3', 'ogg', 'wav', 'm4a') and field.split('[')[0] in AUDIO_FIELDS
            if is_audio:
                final = out / 'upload' / f'{base}.mp3'
                codec, channels, bit_rate = probe_audio(ffprobe, original)
                if codec == 'mp3' and channels == 1 and 0 < bit_rate <= args.bitrate * 1000:
                    # Уже в потрібному вигляді — не перекодовуємо вдруге.
                    shutil.copyfile(original, final)
                else:
                    reencode(ffmpeg, original, final, args.bitrate)
                ctype_final = 'audio/mpeg'
            else:
                final = out / 'upload' / f'{base}.{ext}'
                shutil.copyfile(original, final)
                ctype_final = CONTENT_TYPES.get(ext) or ctype.split(';')[0] or 'application/octet-stream'

            before, after = len(data) // 1024, final.stat().st_size // 1024
            print(f'   {field:<18} {before:>7} KB → {after:>7} KB   {final.name}')
            manifest.append({
                'docId': doc_id, 'field': field, 'from': url, 'driveId': fid,
                'file': str(final), 'contentType': ctype_final,
                'storagePath': f'signals/{field.split("[")[0]}/{doc_id}{"_" + field.split("[")[1].rstrip("]") if "[" in field else ""}.{final.suffix.lstrip(".")}',
            })

    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    errors = [m for m in manifest if 'error' in m]
    print(f'\nГотово: {len(manifest) - len(errors)} файлів у {out / "upload"}, помилок: {len(errors)}')
    print(f'Маніфест: {out / "manifest.json"}')


# ── push ─────────────────────────────────────────────────────────────────────

def cmd_push(args):
    out = Path(args.dir)
    manifest = json.loads((out / 'manifest.json').read_text(encoding='utf-8'))
    signals = {s['docId']: s['fields'] for s in load_signals()}

    by_doc = {}
    for m in manifest:
        if 'error' in m:
            continue
        by_doc.setdefault(m['docId'], []).append(m)

    for doc_id, items in by_doc.items():
        fields = signals.get(doc_id)
        if fields is None:
            print(f'{doc_id}: документа більше немає — пропускаю')
            continue
        print(f'\n{doc_id}  {fields.get("name", "")}')
        update = {}
        backup = dict(fields.get('driveBackup') or {})
        lists = {}
        for m in items:
            data = Path(m['file']).read_bytes()
            url = storage_upload(m['storagePath'], data, m['contentType'], args.dry_run)
            print(f'   {m["field"]:<18} → {m["storagePath"]}')
            field = m['field']
            if '[' in field:
                name, idx = field.split('[')
                idx = int(idx.rstrip(']'))
                lst = lists.setdefault(name, list(fields.get(name) or []))
                backup.setdefault(f'{name}_{idx}', lst[idx])
                lst[idx] = url
            else:
                backup.setdefault(field, fields.get(field))
                update[field] = url
        update.update(lists)
        update['driveBackup'] = backup
        patch_signal(doc_id, update, args.dry_run)

    print('\nГотово.' if not args.dry_run else '\n(dry-run: нічого не змінено)')


def cmd_rollback(args):
    for s in load_signals():
        backup = s['fields'].get('driveBackup')
        if not backup:
            continue
        update, lists = {}, {}
        for k, v in backup.items():
            m = re.fullmatch(r'(\w+)_(\d+)', k)
            if m and m.group(1) in LIST_FIELDS:
                lst = lists.setdefault(m.group(1), list(s['fields'].get(m.group(1)) or []))
                lst[int(m.group(2))] = v
            else:
                update[k] = v
        update.update(lists)
        print(f'{s["docId"]}: повертаю {", ".join(update)}')
        patch_signal(s['docId'], update, args.dry_run)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('command', choices=['fetch', 'push', 'rollback'])
    p.add_argument('--dir', default=str(Path(__file__).parent / 'media_migration'))
    p.add_argument('--bitrate', type=int, default=96)
    p.add_argument('--ffmpeg')
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()
    {'fetch': cmd_fetch, 'push': cmd_push, 'rollback': cmd_rollback}[args.command](args)


if __name__ == '__main__':
    main()
