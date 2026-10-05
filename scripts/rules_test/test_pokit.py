"""Перевірка правил тренажера «Покіт» (pokit_species / pokit_trainer / pokit_sessions).

Запуск (з кореня репозиторію):
    firebase emulators:exec --only firestore --project demo-hs "python scripts/rules_test/test_pokit.py"
Має завершитися рядком «FAILS 0».
"""
import json, base64, time, urllib.request, urllib.error

P = 'demo-hs'


def tok(email, verified=True):
    b = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip('=')
    now = int(time.time())
    return b({'alg': 'none', 'typ': 'JWT'}) + '.' + b({
        'iss': f'https://securetoken.google.com/{P}', 'aud': P, 'auth_time': now, 'iat': now, 'exp': now + 3600,
        'sub': email, 'user_id': email, 'email': email, 'email_verified': verified,
        'firebase': {'sign_in_provider': 'password'}}) + '.'


DOCS = f'http://127.0.0.1:8181/v1/projects/{P}/databases/(default)/documents'
ROOT = tok('volcovskij@forestcollege.ukr.education')
STUDENT = tok('student@gmail.com')

S = lambda v: {'stringValue': v}
I = lambda v: {'integerValue': str(v)}
B = lambda v: {'booleanValue': v}
NULL = {'nullValue': None}


def call(method, url, body, t):
    h = {'Content-Type': 'application/json'}
    if t:
        h['Authorization'] = 'Bearer ' + t
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h))
        return 'ALLOW', json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e:
        return ('DENY' if e.code in (401, 403) else f'ERR{e.code}'), e.read()[:300]


def query(col, filters, t, limit=None):
    f = [{'fieldFilter': {'field': {'fieldPath': k}, 'op': 'EQUAL', 'value': v}} for k, v in filters]
    where = f[0] if len(f) == 1 else {'compositeFilter': {'op': 'AND', 'filters': f}}
    q = {'from': [{'collectionId': col}], 'where': where}
    if limit:
        q['limit'] = limit
    return call('POST', DOCS + ':runQuery', {'structuredQuery': q}, t)


fails = 0


def check(name, got, want):
    global fails
    res = got[0]
    fails += res != want
    print('ok  ' if res == want else 'FAIL', name, res, '(want', want + ')', '' if res == want else got[1])


OTHER = tok('other@gmail.com')
SP = {'id': S('ps_1'), 'name': S('Кабан'), 'pokitRank': I(10)}
check('admin creates species', call('PATCH', f'{DOCS}/pokit_species/ps_1', {'fields': SP}, ROOT), 'ALLOW')
check('student creates species', call('PATCH', f'{DOCS}/pokit_species/ps_2', {'fields': SP}, STUDENT), 'DENY')
check('student edits rank', call('PATCH', f'{DOCS}/pokit_species/ps_1?updateMask.fieldPaths=pokitRank', {'fields': {'pokitRank': I(1)}}, STUDENT), 'DENY')
check('anon reads species', call('GET', f'{DOCS}/pokit_species/ps_1', None, None), 'ALLOW')
check('admin writes config', call('PATCH', f'{DOCS}/pokit_trainer/config', {'fields': {'minSpecies': I(2)}}, ROOT), 'ALLOW')
check('student writes config', call('PATCH', f'{DOCS}/pokit_trainer/config', {'fields': {'minSpecies': I(1)}}, STUDENT), 'DENY')
check('anon reads config', call('GET', f'{DOCS}/pokit_trainer/config', None, None), 'ALLOW')


def create_session(doc_id, uid, t, server_time=True, percent=True):
    fields = {'uid': S(uid), 'correct': I(5), 'total': I(6)}
    if percent:
        fields['percent'] = I(83)
    if not server_time:
        fields['createdAt'] = {'timestampValue': '2026-01-01T00:00:00Z'}
    w = {'update': {'name': f'projects/{P}/databases/(default)/documents/pokit_sessions/{doc_id}', 'fields': fields},
         'currentDocument': {'exists': False}}
    if server_time:
        w['updateTransforms'] = [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}]
    return call('POST', f'{DOCS}:commit', {'writes': [w]}, t)


check('student creates own session', create_session('s1', 'student@gmail.com', STUDENT), 'ALLOW')
check('other creates own session', create_session('s2', 'other@gmail.com', OTHER), 'ALLOW')
check('student creates for other uid', create_session('s3', 'other@gmail.com', STUDENT), 'DENY')
check('student fakes createdAt', create_session('s4', 'student@gmail.com', STUDENT, server_time=False), 'DENY')
check('session without percent', create_session('s5', 'student@gmail.com', STUDENT, percent=False), 'DENY')
check('student lists own', query('pokit_sessions', [('uid', S('student@gmail.com'))], STUDENT), 'ALLOW')
check('student lists other', query('pokit_sessions', [('uid', S('other@gmail.com'))], STUDENT), 'DENY')
check('student reads other doc', call('GET', f'{DOCS}/pokit_sessions/s2', None, STUDENT), 'DENY')
check('admin lists all', call('POST', DOCS + ':runQuery', {'structuredQuery': {'from': [{'collectionId': 'pokit_sessions'}]}}, ROOT), 'ALLOW')
check('student edits own result', call('PATCH', f'{DOCS}/pokit_sessions/s1?updateMask.fieldPaths=percent', {'fields': {'percent': I(100)}}, STUDENT), 'DENY')
check('admin deletes session', call('DELETE', f'{DOCS}/pokit_sessions/s1', None, ROOT), 'ALLOW')
print('FAILS', fails)
