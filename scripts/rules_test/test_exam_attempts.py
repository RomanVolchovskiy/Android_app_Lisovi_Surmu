"""Правила іспитових спроб сайту (ТЗ практики, 5.7): exam_sessions,
exam_attempts, exam_submissions — ті самі запити, що робить site/js/exam-data.js.

Запуск (з кореня репозиторію):
    firebase emulators:exec --only firestore --project demo-hs "python scripts/rules_test/test_exam_attempts.py"
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
B_ = lambda v: {'booleanValue': v}
NULL = {'nullValue': None}
TS = lambda iso: {'timestampValue': iso}
ARR = lambda *v: {'arrayValue': {'values': list(v)}}
MAP = lambda d: {'mapValue': {'fields': d}}


def call(method, url, body, t):
    h = {'Content-Type': 'application/json'}
    if t:
        h['Authorization'] = 'Bearer ' + t
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h))
        return 'ALLOW', json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return 'ALLOW', 'not found'  # правила пропустили, документа немає
        return ('DENY' if e.code in (401, 403) else f'ERR{e.code}'), e.read()[:400]


def query(col, filters, t, limit=None):
    f = [{'fieldFilter': {'field': {'fieldPath': k}, 'op': 'EQUAL', 'value': v}} for k, v in filters]
    q = {'from': [{'collectionId': col}]}
    if f:
        q['where'] = f[0] if len(f) == 1 else {'compositeFilter': {'op': 'AND', 'filters': f}}
    if limit:
        q['limit'] = limit
    return call('POST', DOCS + ':runQuery', {'structuredQuery': q}, t)


def commit(writes, t):
    return call('POST', DOCS + ':commit', {'writes': writes}, t)


def w_set(path, fields, server_ts=(), mask=None, exists=None):
    w = {'update': {'name': f'{DB}/{path}', 'fields': fields}}
    if mask is not None:
        w['updateMask'] = {'fieldPaths': mask}
    if server_ts:
        w['updateTransforms'] = [{'fieldPath': f, 'setToServerValue': 'REQUEST_TIME'} for f in server_ts]
    if exists is not None:
        w['currentDocument'] = {'exists': exists}
    return w


def w_delete(path):
    return {'delete': f'{DB}/{path}'}


fails = 0


def check(name, got, want):
    global fails
    res = got[0]
    fails += res != want
    print('ok  ' if res == want else 'FAIL', name, res, '(want', want + ')', '' if res == want else got[1])


# ── Сесії ────────────────────────────────────────────────────────────────────
CODE = 'K7MPX2'
session = {'id': S(CODE), 'code': S(CODE), 'title': S('Залік'), 'group': S('ЛГс-32'), 'status': S('active'),
           'timeLimitMin': I(30), 'startsAt': NULL, 'deadline': NULL,
           'theoryEnabled': B_(True), 'theoryTopicIds': ARR(S('t7')), 'theoryQuestionCount': I(20), 'theoryMaxPoints': I(20),
           'audioEnabled': B_(True), 'audioTag': S('практика'), 'audioQuestionCount': I(10), 'audioMaxPoints': I(6),
           'fileEnabled': B_(False), 'createdAt': TS('2026-10-05T08:00:00Z')}
check('admin creates session (id = code)', call('PATCH', f'{DOCS}/exam_sessions/{CODE}', {'fields': session}, ROOT), 'ALLOW')
check('student creates session', call('PATCH', f'{DOCS}/exam_sessions/HACK01', {'fields': session}, A), 'DENY')
check('student gets session by code', call('GET', f'{DOCS}/exam_sessions/{CODE}', None, A), 'ALLOW')
check('unverified gets session', call('GET', f'{DOCS}/exam_sessions/{CODE}', None, UNVERIFIED), 'DENY')
check('student lists all sessions', query('exam_sessions', [], A), 'DENY')
check('student finds legacy session by code (limit 1)', query('exam_sessions', [('code', S(CODE))], A, 1), 'ALLOW')
check('admin lists sessions', query('exam_sessions', [], ROOT), 'ALLOW')

# ── Спроба ───────────────────────────────────────────────────────────────────
AID = f'{CODE}_{A_UID}'
BID = f'{CODE}_{B_UID}'


def attempt(uid, extra=None):
    f = {'sessionId': S(CODE), 'sessionCode': S(CODE), 'uid': S(uid), 'email': S(uid), 'fullName': S('Анна Коваль'),
         'group': S('ЛГс-32'), 'status': S('in_progress'), 'submittedAt': NULL, 'deadlineAt': NULL,
         'theory': MAP({'items': ARR(MAP({'qid': S('q1'), 'order': ARR(I(2), I(0), I(1), I(3)), 'answer': NULL})),
                        'correct': NULL, 'total': I(1), 'points': NULL}),
         'audio': NULL, 'file': NULL, 'totalPoints': NULL, 'visibilityLeaves': I(0), 'autoSubmitted': B_(False)}
    f.update(extra or {})
    return f


check('student gets own missing attempt', call('GET', f'{DOCS}/exam_attempts/{AID}', None, A), 'ALLOW')
check('student creates attempt with client startedAt', commit([w_set(f'exam_attempts/{AID}', attempt(A_UID, {'startedAt': TS('2026-10-05T08:00:00Z')}))], A), 'DENY')
check('student creates attempt for someone else', commit([w_set(f'exam_attempts/{BID}', attempt(B_UID), server_ts=['startedAt'])], A), 'DENY')
check('student creates attempt with wrong id', commit([w_set(f'exam_attempts/OTHER_{A_UID}', attempt(A_UID), server_ts=['startedAt'])], A), 'DENY')
check('student creates attempt already submitted', commit([w_set(f'exam_attempts/{AID}', attempt(A_UID, {'status': S('submitted')}), server_ts=['startedAt'])], A), 'DENY')
check('student creates own attempt', commit([w_set(f'exam_attempts/{AID}', attempt(A_UID), server_ts=['startedAt'])], A), 'ALLOW')
check('student restarts (overwrites) attempt', commit([w_set(f'exam_attempts/{AID}', attempt(A_UID), server_ts=['startedAt'])], A), 'DENY')
check('student reads own attempt', call('GET', f'{DOCS}/exam_attempts/{AID}', None, A), 'ALLOW')
check('other student reads attempt', call('GET', f'{DOCS}/exam_attempts/{AID}', None, B), 'DENY')
check('other student lists attempts of session', query('exam_attempts', [('sessionId', S(CODE))], B), 'DENY')
check('student lists own attempts', query('exam_attempts', [('uid', S(A_UID))], A), 'ALLOW')

items_answered = MAP({'items': ARR(MAP({'qid': S('q1'), 'order': ARR(I(2), I(0), I(1), I(3)), 'answer': I(1)})),
                      'correct': NULL, 'total': I(1), 'points': NULL})
check('student saves answer', commit([w_set(f'exam_attempts/{AID}', {'theory': items_answered}, mask=['theory'])], A), 'ALLOW')
check('student syncs clock', commit([w_set(f'exam_attempts/{AID}', {}, mask=[], server_ts=['clientSyncAt'])], A), 'ALLOW')
check('student sets deadlineAt', commit([w_set(f'exam_attempts/{AID}', {'deadlineAt': TS('2026-10-05T08:30:00Z')}, mask=['deadlineAt'])], A), 'ALLOW')
check('student +1 visibilityLeaves', commit([{'transform': {'document': f'{DB}/exam_attempts/{AID}',
       'fieldTransforms': [{'fieldPath': 'visibilityLeaves', 'increment': I(1)}]}}], A), 'ALLOW')
check('student resets visibilityLeaves', commit([w_set(f'exam_attempts/{AID}', {'visibilityLeaves': I(0)}, mask=['visibilityLeaves'])], A), 'DENY')
check('student moves startedAt', commit([w_set(f'exam_attempts/{AID}', {'startedAt': TS('2030-01-01T00:00:00Z')}, mask=['startedAt'])], A), 'DENY')
check('student changes uid', commit([w_set(f'exam_attempts/{AID}', {'uid': S(B_UID)}, mask=['uid'])], A), 'DENY')
check('other student writes attempt', commit([w_set(f'exam_attempts/{AID}', {'theory': items_answered}, mask=['theory'])], B), 'DENY')
check('student deletes own attempt', commit([w_delete(f'exam_attempts/{AID}')], A), 'DENY')


def submission(uid, sid):
    return {'id': S(sid), 'sessionId': S(CODE), 'sessionCode': S(CODE), 'studentName': S('Анна Коваль'),
            'theoryCorrect': I(1), 'theoryTotal': I(1), 'theoryAutoPoints': I(20), 'adminTheoryPoints': NULL,
            'audioCorrect': I(0), 'audioTotal': I(0), 'audioAutoPoints': I(0), 'adminAudioPoints': NULL,
            'fileUrl': NULL, 'fileName': NULL, 'adminFilePoints': NULL, 'adminNote': NULL, 'status': S('pending'),
            'uid': S(uid), 'email': S(uid), 'group': S('ЛГс-32'), 'attemptId': S(sid)}


submit_fields = {'status': S('submitted'), 'totalPoints': I(20), 'autoSubmitted': B_(False)}
check('student creates submission without submitting attempt',
      commit([w_set(f'exam_submissions/{AID}', submission(A_UID, AID), server_ts=['submittedAt'])], A), 'DENY')
check('student submits someone else\'s summary',
      commit([w_set(f'exam_attempts/{AID}', submit_fields, mask=list(submit_fields), server_ts=['submittedAt']),
              w_set(f'exam_submissions/{BID}', submission(B_UID, BID), server_ts=['submittedAt'])], A), 'DENY')
bad = submission(A_UID, AID); bad['adminTheoryPoints'] = I(20)
check('student submits with admin points',
      commit([w_set(f'exam_attempts/{AID}', submit_fields, mask=list(submit_fields), server_ts=['submittedAt']),
              w_set(f'exam_submissions/{AID}', bad, server_ts=['submittedAt'])], A), 'DENY')
check('student submits (batch)',
      commit([w_set(f'exam_attempts/{AID}', submit_fields, mask=list(submit_fields), server_ts=['submittedAt']),
              w_set(f'exam_submissions/{AID}', submission(A_UID, AID), server_ts=['submittedAt'])], A), 'ALLOW')
check('student edits submitted attempt', commit([w_set(f'exam_attempts/{AID}', {'theory': items_answered}, mask=['theory'])], A), 'DENY')
check('student reopens submitted attempt', commit([w_set(f'exam_attempts/{AID}', {'status': S('in_progress')}, mask=['status'])], A), 'DENY')
check('student rewrites own submission', commit([w_set(f'exam_submissions/{AID}', submission(A_UID, AID), server_ts=['submittedAt'])], A), 'DENY')
check('owner reads own submission', call('GET', f'{DOCS}/exam_submissions/{AID}', None, A), 'ALLOW')
check('other student reads site submission', call('GET', f'{DOCS}/exam_submissions/{AID}', None, B), 'DENY')
check('admin lists attempts of session', query('exam_attempts', [('sessionId', S(CODE))], ROOT), 'ALLOW')
check('admin lists submissions of session', query('exam_submissions', [('sessionId', S(CODE))], ROOT), 'ALLOW')
check('admin grades', commit([w_set(f'exam_submissions/{AID}', {'status': S('graded'), 'adminTheoryPoints': I(18)}, mask=['status', 'adminTheoryPoints'])], ROOT), 'ALLOW')

# ── Анулювання й повторна спроба ─────────────────────────────────────────────
check('student annuls own attempt', commit([w_delete(f'exam_attempts/{AID}'), w_delete(f'exam_submissions/{AID}')], A), 'DENY')
check('admin annuls attempt', commit([w_delete(f'exam_attempts/{AID}'), w_delete(f'exam_submissions/{AID}')], ROOT), 'ALLOW')
check('student starts again after annul', commit([w_set(f'exam_attempts/{AID}', attempt(A_UID), server_ts=['startedAt'])], A), 'ALLOW')

# ── Примусова здача адміністратором ─────────────────────────────────────────
check('B starts attempt', commit([w_set(f'exam_attempts/{BID}', attempt(B_UID), server_ts=['startedAt'])], B), 'ALLOW')
check('admin force-submits B',
      commit([w_set(f'exam_attempts/{BID}', dict(submit_fields, forcedByAdmin=B_(True)), mask=list(submit_fields) + ['forcedByAdmin'], server_ts=['submittedAt']),
              w_set(f'exam_submissions/{BID}', submission(B_UID, BID), server_ts=['submittedAt'])], ROOT), 'ALLOW')

# ── Закрита сесія ───────────────────────────────────────────────────────────
check('admin closes session', commit([w_set(f'exam_sessions/{CODE}', {'status': S('closed')}, mask=['status'])], ROOT), 'ALLOW')
C_UID = 'chrystia@gmail.com'; C = tok(C_UID); CID = f'{CODE}_{C_UID}'
check('new attempt in closed session', commit([w_set(f'exam_attempts/{CID}', attempt(C_UID), server_ts=['startedAt'])], C), 'DENY')
auto_fields = dict(submit_fields, autoSubmitted=B_(True))
check('in-progress attempt auto-submits after close',
      commit([w_set(f'exam_attempts/{AID}', auto_fields, mask=list(auto_fields), server_ts=['submittedAt']),
              w_set(f'exam_submissions/{AID}', submission(A_UID, AID), server_ts=['submittedAt'])], A), 'ALLOW')

# ── Вікно доступності ───────────────────────────────────────────────────────
FUT = 'FUTUR2'
fs = dict(session, id=S(FUT), code=S(FUT), startsAt=TS('2099-01-01T00:00:00Z'))
check('admin creates future session', call('PATCH', f'{DOCS}/exam_sessions/{FUT}', {'fields': fs}, ROOT), 'ALLOW')
check('attempt before startsAt', commit([w_set(f'exam_attempts/{FUT}_{C_UID}', dict(attempt(C_UID), sessionId=S(FUT)), server_ts=['startedAt'])], C), 'DENY')
PAST = 'PASTX3'
ps = dict(session, id=S(PAST), code=S(PAST), deadline=TS('2020-01-01T00:00:00Z'))
check('admin creates expired session', call('PATCH', f'{DOCS}/exam_sessions/{PAST}', {'fields': ps}, ROOT), 'ALLOW')
check('attempt after deadline', commit([w_set(f'exam_attempts/{PAST}_{C_UID}', dict(attempt(C_UID), sessionId=S(PAST)), server_ts=['startedAt'])], C), 'DENY')

print('FAILS', fails)
