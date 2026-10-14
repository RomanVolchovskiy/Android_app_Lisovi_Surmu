"""Перевірка правил практики (practice_work / practice_grades).

Запуск (з кореня репозиторію):
    firebase emulators:exec --only firestore --project demo-hs "python scripts/rules_test/test_practice.py"
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
ME = 'student@gmail.com'


def save_work(uid, t, fields=None, server_time=True):
    f = {'uid': S(uid), 'fullName': S('Іван Демо'), 'steps': {'mapValue': {'fields': {'d1_pr': {'mapValue': {'fields': {'done': B(True)}}}}}}}
    if fields:
        f.update(fields)
    if not server_time:
        f['updatedAt'] = {'timestampValue': '2026-01-01T00:00:00Z'}
    w = {'update': {'name': f'projects/{P}/databases/(default)/documents/practice_work/{uid}', 'fields': f}}
    if server_time:
        w['updateTransforms'] = [{'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}]
    return call('POST', f'{DOCS}:commit', {'writes': [w]}, t)


check('student saves own work', save_work(ME, STUDENT), 'ALLOW')
check('student updates own work', save_work(ME, STUDENT, {'diary': {'mapValue': {'fields': {'d1': {'mapValue': {'fields': {'aud': S('x')}}}}}}}), 'ALLOW')
check('student saves other work', save_work('other@gmail.com', STUDENT), 'DENY')
check('student writes points into work', save_work(ME, STUDENT, {'points': I(60)}), 'DENY')
check('student fakes updatedAt', save_work(ME, STUDENT, server_time=False), 'DENY')
check('unverified saves work', save_work('nv@gmail.com', tok('nv@gmail.com', verified=False)), 'DENY')
check('student reads own work', call('GET', f'{DOCS}/practice_work/{ME}', None, STUDENT), 'ALLOW')
check('other reads student work', call('GET', f'{DOCS}/practice_work/{ME}', None, OTHER), 'DENY')
check('admin lists works', call('POST', DOCS + ':runQuery', {'structuredQuery': {'from': [{'collectionId': 'practice_work'}]}}, ROOT), 'ALLOW')
check('student lists works', call('POST', DOCS + ':runQuery', {'structuredQuery': {'from': [{'collectionId': 'practice_work'}]}}, STUDENT), 'DENY')
check('admin edits work', save_work(ME, ROOT), 'DENY')

G = {'grades': {'mapValue': {'fields': {'d1_pr': {'mapValue': {'fields': {'points': I(5), 'status': S('graded')}}}}}}}
check('admin grades', call('PATCH', f'{DOCS}/practice_grades/{ME}', {'fields': G}, ROOT), 'ALLOW')
check('student grades self', call('PATCH', f'{DOCS}/practice_grades/{ME}', {'fields': G}, STUDENT), 'DENY')
check('student reads own grades', call('GET', f'{DOCS}/practice_grades/{ME}', None, STUDENT), 'ALLOW')
check('other reads grades', call('GET', f'{DOCS}/practice_grades/{ME}', None, OTHER), 'DENY')
check('anon reads grades', call('GET', f'{DOCS}/practice_grades/{ME}', None, None), 'DENY')
check('admin deletes work', call('DELETE', f'{DOCS}/practice_work/{ME}', None, ROOT), 'ALLOW')
print('FAILS', fails)
