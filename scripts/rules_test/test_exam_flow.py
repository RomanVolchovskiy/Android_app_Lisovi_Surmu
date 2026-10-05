"""Перевірка правил для іспитів: ті самі запити, що роблять сайт і додаток.

Запуск (з кореня репозиторію):
    firebase emulators:exec --only firestore --project demo-hs "python scripts/rules_test/test_exam_flow.py"
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


SID = '1790000000000'
session = {'id': S(SID), 'code': S('ABC234'), 'title': S('Тест'), 'status': S('draft'), 'passingScore': I(60),
           'theoryEnabled': B(False), 'audioEnabled': B(False), 'fileEnabled': B(True), 'fileMaxPoints': I(30),
           'theoryTopicId': NULL, 'deadline': NULL}
check('admin creates session', call('PATCH', f'{DOCS}/exam_sessions/{SID}', {'fields': session}, ROOT), 'ALLOW')
check('admin activates session', call('PATCH', f'{DOCS}/exam_sessions/{SID}?updateMask.fieldPaths=status', {'fields': {'status': S('active')}}, ROOT), 'ALLOW')
check('student finds session by code', query('exam_sessions', [('code', S('ABC234'))], STUDENT, 1), 'ALLOW')
check('student hasSubmitted (limit 1)', query('exam_submissions', [('sessionId', S(SID)), ('studentName', S('Іван Петренко'))], STUDENT, 1), 'ALLOW')

sub = {'id': S('1790000000001'), 'sessionId': S(SID), 'sessionCode': S('ABC234'), 'studentName': S('Іван Петренко'),
       'theoryCorrect': I(0), 'theoryTotal': I(0), 'theoryAutoPoints': I(0), 'adminTheoryPoints': NULL,
       'audioCorrect': I(0), 'audioTotal': I(0), 'audioAutoPoints': I(0), 'adminAudioPoints': NULL,
       'fileUrl': NULL, 'fileName': NULL, 'adminFilePoints': NULL, 'adminNote': NULL, 'status': S('pending')}
check('student submits', call('PATCH', f'{DOCS}/exam_submissions/1790000000001', {'fields': sub}, STUDENT), 'ALLOW')
check('student lists all results', query('exam_submissions', [('sessionId', S(SID))], STUDENT), 'DENY')
check('admin lists results', query('exam_submissions', [('sessionId', S(SID))], ROOT), 'ALLOW')
check('admin grades', call('PATCH', f'{DOCS}/exam_submissions/1790000000001?updateMask.fieldPaths=status&updateMask.fieldPaths=adminFilePoints',
                           {'fields': {'status': S('graded'), 'adminFilePoints': I(25)}}, ROOT), 'ALLOW')
print('FAILS', fails)
