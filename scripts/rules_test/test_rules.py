"""Перевірка firestore.rules і storage.rules на локальних емуляторах.

Запуск (потрібні Firebase CLI і Java, напр. JBR з Android Studio):
    firebase emulators:exec --only firestore,storage --project demo-hs "python scripts/rules_test/test_rules.py"
(з кореня репозиторію; порти емуляторів — у firebase.json).
Проєкт demo-hs — демо: емулятори не звертаються до справжнього Firebase.
Має завершитися рядком «FAILS 0».
"""
import json, base64, time, urllib.request, urllib.error, urllib.parse

P = 'demo-hs'
FS = f'http://127.0.0.1:8181/v1/projects/{P}/databases/(default)/documents/'
ST = f'http://127.0.0.1:9199/v0/b/{P}.appspot.com/o'
NL = chr(13) + chr(10)


def tok(email, verified=True):
    b = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip('=')
    now = int(time.time())
    return b({'alg': 'none', 'typ': 'JWT'}) + '.' + b({
        'iss': f'https://securetoken.google.com/{P}', 'aud': P, 'auth_time': now, 'iat': now, 'exp': now + 3600,
        'sub': email, 'user_id': email, 'email': email, 'email_verified': verified,
        'firebase': {'sign_in_provider': 'password'}}) + '.'


ROOT = tok('volcovskij@forestcollege.ukr.education')
ROOTU = tok('volcovskij@forestcollege.ukr.education', False)
USER = tok('student@gmail.com')
OTHER = tok('other@x.ua')
ANON = None


def req(method, url, body=None, t=None, ct='application/json'):
    h = {'Content-Type': ct}
    if ct.startswith('multipart/'):
        h['X-Goog-Upload-Protocol'] = 'multipart'
    if t:
        h['Authorization'] = 'Bearer ' + t
    data = body if isinstance(body, bytes) or body is None else json.dumps(body).encode()
    try:
        urllib.request.urlopen(urllib.request.Request(url, data=data, method=method, headers=h))
        return 'ALLOW'
    except urllib.error.HTTPError as e:
        return 'DENY' if e.code in (401, 403) else f'ERR{e.code}:{e.read()[:150]}'


def fs_set(path, t, fields=None):
    return req('PATCH', FS + path, {'fields': fields or {'a': {'stringValue': 'x'}}}, t)


def fs_get(path, t):
    return req('GET', FS + path, None, t)


def st_up(path, t, ct='image/webp'):
    b = 'bnd123'
    meta = json.dumps({'name': path, 'contentType': ct}).encode()
    body = (('--' + b + NL + 'Content-Type: application/json; charset=utf-8' + NL + NL).encode() + meta
            + (NL + '--' + b + NL + 'Content-Type: ' + ct + NL + NL).encode() + b'RIFFxxxxWEBP'
            + (NL + '--' + b + '--').encode())
    url = ST + '?name=' + urllib.parse.quote(path, safe='') + '&uploadType=multipart'
    return req('POST', url, body, t, 'multipart/related; boundary=' + b)


fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print('ok  ' if ok else 'FAIL', name, got, '(want', want + ')')


arr = lambda *xs: {'arrayValue': {'values': [{'stringValue': x} for x in xs]}}

check('anon read signals', fs_get('signals/none', ANON).replace('ERR404', 'ALLOW')[:5], 'ALLOW')
check('anon write signals', fs_set('signals/s1', ANON), 'DENY')
check('user write signals', fs_set('signals/s1', USER), 'DENY')
check('root unverified write signals', fs_set('signals/s1', ROOTU), 'DENY')
check('root write signals', fs_set('signals/s1', ROOT), 'ALLOW')
check('user write edu_topics', fs_set('edu_topics/t1', USER), 'DENY')
check('user write global_events', fs_set('global_events/e1', USER), 'DENY')
check('user write shared_events', fs_set('shared_events/e1', USER), 'ALLOW')
check('anon write shared_events', fs_set('shared_events/e2', ANON), 'DENY')
check('anon read shared_events', fs_get('shared_events/e1', ANON), 'ALLOW')
check('user create config (self admin)', fs_set('app_access/config', USER, {'adminEmails': arr('student@gmail.com')}), 'DENY')
check('ST listed admin upload before listed', st_up('signals/imageUrl/0_a.webp', OTHER), 'DENY')
check('other write signals before listed', fs_set('signals/s2', OTHER), 'DENY')
check('root create config', fs_set('app_access/config', ROOT, {'adminEmails': arr('other@x.ua')}), 'ALLOW')
check('listed admin write signals', fs_set('signals/s2', OTHER), 'ALLOW')
check('root still admin (not in list)', fs_set('signals/s3', ROOT), 'ALLOW')
check('user create exam_submission', fs_set('exam_submissions/x1', USER), 'ALLOW')
check('anon read exam_submission', fs_get('exam_submissions/x1', ANON), 'DENY')
check('user update exam_submission', fs_set('exam_submissions/x1', USER, {'grade': {'integerValue': '5'}}), 'DENY')
check('admin update exam_submission', fs_set('exam_submissions/x1', OTHER, {'grade': {'integerValue': '5'}}), 'ALLOW')
check('user write exam_sessions', fs_set('exam_sessions/s1', USER), 'DENY')
check('user write unknown coll', fs_set('misc/m1', USER), 'ALLOW')
check('anon write unknown coll', fs_set('misc/m2', ANON), 'DENY')
check('anon read users', fs_get('users/u1', ANON), 'DENY')
check('ST anon upload signals', st_up('signals/imageUrl/1_a.webp', ANON), 'DENY')
check('ST user upload signals', st_up('signals/imageUrl/1_a.webp', USER), 'DENY')
check('ST root upload signals', st_up('signals/imageUrl/1_a.webp', ROOT), 'ALLOW')
check('ST listed admin upload (cross-service)', st_up('signals/imageUrl/2_a.webp', OTHER), 'ALLOW')
check('ST admin upload wrong type', st_up('signals/imageUrl/3_a.exe', ROOT, 'application/octet-stream'), 'DENY')
check('ST anon read signals', req('GET', ST + '/' + urllib.parse.quote('signals/imageUrl/1_a.webp', safe='') + '?alt=media'), 'ALLOW')
check('ST user delete signals', req('DELETE', ST + '/' + urllib.parse.quote('signals/imageUrl/1_a.webp', safe=''), None, USER), 'DENY')
check('ST user upload exam_files', st_up('exam_files/s/x.pdf', USER, 'application/pdf'), 'ALLOW')
check('ST anon upload exam_files', st_up('exam_files/s/y.pdf', ANON, 'application/pdf'), 'DENY')
print('FAILS', fails)
raise SystemExit(1 if fails else 0)
