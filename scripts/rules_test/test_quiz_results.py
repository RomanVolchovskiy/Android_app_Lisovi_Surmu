"""Правила історії пробних тестів (ТЗ практики, розділ 4): quiz_results —
ті самі запити, що робить site/js/quiz-results.js.

Запуск (з кореня репозиторію):
    firebase emulators:exec --only firestore --project demo-hs "python scripts/rules_test/test_quiz_results.py"
Має завершитися рядком «FAILS 0».
"""
import json, base64, time, urllib.request, urllib.error

P = 'demo-hs'
DB = f'projects/{P}/databases/(default)/documents'
DOCS = f'http://127.0.0.1:8181/v1/{DB}'


def tok(email, verified=True):
    b = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).decode().rstrip('=')
    now = int(time.time())
    return b({'alg': 'none', 'typ': 'JWT'}) + '.' + b({
        'iss': f'https://securetoken.google.com/{P}', 'aud': P, 'auth_time': now, 'iat': now, 'exp': now + 3600,
        'sub': email, 'user_id': email, 'email': email, 'email_verified': verified,
        'firebase': {'sign_in_provider': 'password'}}) + '.'


ROOT = tok('volcovskij@forestcollege.ukr.education')
A_UID, B_UID = 'anna@gmail.com', 'bohdan@gmail.com'
A, B = tok(A_UID), tok(B_UID)
UNVERIFIED = tok('c@gmail.com', verified=False)

S = lambda v: {'stringValue': v}
I = lambda v: {'integerValue': str(v)}
TS = lambda iso: {'timestampValue': iso}


def call(method, url, body, t):
    h = {'Content-Type': 'application/json'}
    if t:
        h['Authorization'] = 'Bearer ' + t
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h))
        return 'ALLOW', json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return 'ALLOW', 'not found'
        return ('DENY' if e.code in (401, 403) else f'ERR{e.code}'), e.read()[:400]


def query(filters, t, ranges=()):
    f = [{'fieldFilter': {'field': {'fieldPath': k}, 'op': 'EQUAL', 'value': v}} for k, v in filters]
    f += [{'fieldFilter': {'field': {'fieldPath': k}, 'op': op, 'value': v}} for k, op, v in ranges]
    q = {'from': [{'collectionId': 'quiz_results'}]}
    if f:
        q['where'] = f[0] if len(f) == 1 else {'compositeFilter': {'op': 'AND', 'filters': f}}
    return call('POST', DOCS + ':runQuery', {'structuredQuery': q}, t)


def create(doc_id, fields, t, server_ts=True):
    w = {'update': {'name': f'{DB}/quiz_results/{doc_id}', 'fields': fields}, 'currentDocument': {'exists': False}}
    if server_ts:
        w['updateTransforms'] = [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}]
    return call('POST', DOCS + ':commit', {'writes': [w]}, t)


def result(uid, **kw):
    f = {'uid': S(uid), 'email': S(uid), 'fullName': S('Анна Коваль'), 'group': S('ЛГс-32'), 'kind': S('theory'),
         'topicId': S('t1'), 'topicName': S('Тема 1'), 'audioFilter': {'nullValue': None},
         'correct': I(7), 'total': I(9), 'percent': I(78)}
    f.update(kw)
    return f


fails = 0


def check(name, got, want):
    global fails
    res = got[0]
    fails += res != want
    print('ok  ' if res == want else 'FAIL', name, res, '(want', want + ')', '' if res == want else got[1])


check('student saves own result', create('r1', result(A_UID), A), 'ALLOW')
check('student saves audio result', create('r2', result(A_UID, kind=S('audio'), audioFilter=S('tag:практика'), topicId={'nullValue': None}), A), 'ALLOW')
check('student saves result for other uid', create('r3', result(B_UID), A), 'DENY')
check('student backdates result', create('r4', dict(result(A_UID), createdAt=TS('2026-09-29T08:00:00Z')), A, server_ts=False), 'DENY')
check('unknown kind', create('r5', result(A_UID, kind=S('exam')), A), 'DENY')
check('correct > total', create('r6', result(A_UID, correct=I(10), total=I(9)), A), 'DENY')
check('correct as string', create('r7', result(A_UID, correct=S('7')), A), 'DENY')
check('unverified saves result', create('r8', result('c@gmail.com'), UNVERIFIED), 'DENY')
check('student lists own results', query([('uid', S(A_UID))], A), 'ALLOW')
check('student reads own result', call('GET', f'{DOCS}/quiz_results/r1', None, A), 'ALLOW')
check('other student reads result', call('GET', f'{DOCS}/quiz_results/r1', None, B), 'DENY')
check('other student lists by uid', query([('uid', S(A_UID))], B), 'DENY')
check('student lists all results', query([], A), 'DENY')
check('anon lists results', query([], None), 'DENY')
check('student edits own result', call('PATCH', f'{DOCS}/quiz_results/r1?updateMask.fieldPaths=correct', {'fields': {'correct': I(9)}}, A), 'DENY')
check('student deletes own result', call('DELETE', f'{DOCS}/quiz_results/r1', None, A), 'DENY')
check('admin lists results by date', query([], ROOT, ranges=[('createdAt', 'GREATER_THAN_OR_EQUAL', TS('2020-01-01T00:00:00Z'))]), 'ALLOW')
check('admin deletes result', call('DELETE', f'{DOCS}/quiz_results/r2', None, ROOT), 'ALLOW')
print('FAILS', fails)
