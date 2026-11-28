"""lib/analysis/chat/rules 일부를 파이썬으로 옮긴 것 (멘트 특징 · 멘트 시뮬레이션 · 테스트 기대값용)

옮긴 것: 정리(normalizer.dart) · 메시지 표시(tagger.dart, 단어는 lexicon.dart를 직접 읽음)
        · 멘트 사전(lines.dart를 직접 읽음: 방향별 · 존댓말 · 주제별) · 지금 앱 멘트 고르기(pickLines)
Dart 쪽 규칙을 고치면 여기도 같이 고칠 것
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass

import dart_rules as R

ROOT = R.DEFAULT_ROOT
RULES = os.path.join(ROOT, 'lib', 'analysis', 'chat', 'rules')


def _read(name: str) -> str:
    return open(os.path.join(RULES, name), encoding='utf-8').read().replace('\r', '')


_STR = re.compile(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"")


def _unescape(s: str) -> str:
    """Dart 문자열 이스케이프 풀기 (\\\\ → \\, \\$ → $, \\' → ')"""
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            n = s[i + 1]
            out.append({'n': '\n', 't': '\t'}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def _strings(body: str) -> list[str]:
    return [_unescape(a if a is not None and b == '' else (a or b)) for a, b in _STR.findall(body)]


def _list(text: str, name: str) -> list[str]:
    m = re.search(r'const (?:List<String> )?' + name + r' = \[(.*?)\n\];', text, re.S)
    return _strings(m.group(1))


# ---------- 단어 사전 · 표시 ----------

_LEX = _read('lexicon.dart')
WORD_TABLE: dict[str, list[str]] = {}
_wt = re.search(r'const Map<MessageTag, List<String>> wordTable = \{(.*?)\n\};', _LEX, re.S).group(1)
for m in re.finditer(r'MessageTag\.(\w+): \[(.*?)\n  \],', _wt, re.S):
    WORD_TABLE[m.group(1)] = _strings(m.group(2))

QUESTION_ENDINGS = _list(_LEX, 'questionEndings')
ASK_BACK = _list(_LEX, 'askBackWords')
PERSONAL = _list(_LEX, 'personalWords')
INVITE_ENDINGS = _list(_LEX, 'inviteEndings')
TOGETHER = _list(_LEX, 'togetherWords')
AGREE = _list(_LEX, 'agreeStarts')
AGREE_MAX = int(re.search(r'const agreeMaxLength = (\d+);', _LEX).group(1))
SHORT_REPLIES = _list(_LEX, 'shortReplies')
NEGATIONS = _list(_LEX, 'negations')
AEGYO = _list(_LEX, 'aegyoPatterns')
HONOR_END = _list(_LEX, 'honorificEndings')
HONOR_WORD = _list(_LEX, 'honorificWords')

_TAIL = r'[.!~ㅋㅎㅠㅜ^♡♥]*'
_POLITE_TAIL = r'[.!?~ㅋㅎㅠㅜ^♡♥]*'
_FLIPPED = {'positive', 'compliment', 'affection', 'interest', 'empathy'}
_WORD = {k: re.compile('|'.join(v)) for k, v in WORD_TABLE.items()}
_NEG = re.compile('|'.join(NEGATIONS))
_Q_END = re.compile('(' + '|'.join(QUESTION_ENDINGS) + ')' + _TAIL + '$')
_ASK_BACK = re.compile('|'.join(ASK_BACK))
_PERSONAL = re.compile('|'.join(PERSONAL))
_INVITE_END = re.compile('(' + '|'.join(INVITE_ENDINGS) + ')' + _TAIL + r'\??' + _TAIL + '$')
_TOGETHER = re.compile('|'.join(TOGETHER))
_AEGYO = re.compile('|'.join(AEGYO))
_HONOR_END = re.compile('(' + '|'.join(HONOR_END) + ')' + _POLITE_TAIL + '$')
_HONOR_WORD = re.compile('|'.join(HONOR_WORD))
_AGREE_WORDS = '|'.join(AGREE)
_AGREE_START = re.compile('^(' + _AGREE_WORDS + ')요?(' + _TAIL + '$|[!~,.ㅋㅎ]|' + _AGREE_WORDS + ')')
_SHORT = re.compile('^(' + '|'.join(SHORT_REPLIES) + ')' + _TAIL + '$')
_SPACES = re.compile(r'\s+')
_REPEATED = re.compile(r'(.)\1{2,}')


def normalize(raw: str) -> tuple[str, str]:
    t = _SPACES.sub(' ', raw.strip().lower())
    t = _REPEATED.sub(lambda m: m.group(1) * 2, t)
    return t, t.replace(' ', '')


def tag_message(raw: str) -> set[str]:
    """tagger.dart tagMessage (자리표시 글자는 멘트에 없어서 뺌)"""
    _, c = normalize(raw)
    if not c:
        return set()
    tags = {k for k, p in _WORD.items() if p.search(c)}
    if _NEG.search(c):
        tags -= _FLIPPED
        tags.add('negative')
    is_q = '?' in c or bool(_Q_END.search(c))
    if is_q:
        tags.add('question')
        tags.discard('share')
        if _ASK_BACK.search(c):
            tags.add('askBack')
        if _PERSONAL.search(c):
            tags.add('personal')
    if 'future' not in tags and (_INVITE_END.search(c) or (is_q and _TOGETHER.search(c))):
        tags.add('invite')
    if _AEGYO.search(c):
        tags.add('aegyo')
    if _HONOR_END.search(c) or _HONOR_WORD.search(c):
        tags.add('honorific')
    if len(c) <= AGREE_MAX and not is_q and _AGREE_START.search(c):
        tags.add('agree')
    if _SHORT.search(c):
        tags.add('shortReply')
    return tags


def text_length(text: str) -> int:
    return len(text.strip())


# ---------- 멘트 사전 ----------

@dataclass(frozen=True)
class Line:
    text: str
    slot: str | None = None  # morning · day · evening · night
    weekend: bool | None = None

    def fits(self, hour: int, weekday: int) -> bool:
        if self.slot is not None and slot_of(hour) != self.slot:
            return False
        if self.weekend is not None and (weekday >= 4) != self.weekend:
            return False
        return True


def slot_of(hour: int) -> str:
    return 'morning' if 5 <= hour < 11 else 'day' if 11 <= hour < 17 else 'evening' if 17 <= hour < 23 else 'night'


_LINES = _read('lines.dart')
_LINE = re.compile(r"Line\((" + _STR.pattern + r")(?:, slot: TimeSlot\.(\w+))?(?:, weekend: (true|false))?\)")


def _lines_of(body: str) -> list[Line]:
    out = []
    for m in _LINE.finditer(body):
        a, b = m.group(2), m.group(3)
        text = _unescape(a if a is not None else b)
        wk = m.group(5)
        out.append(Line(text, m.group(4), None if wk is None else wk == 'true'))
    return out


def _approach_map(name: str) -> dict[str, list[Line]]:
    body = re.search(r'const Map<Approach, List<Line>> ' + name + r' = \{(.*?)\n\};', _LINES, re.S).group(1)
    return {m.group(1): _lines_of(m.group(2)) for m in re.finditer(r'  Approach\.(\w+): \[(.*?)\n  \],', body, re.S)}


def _topic_map(name: str) -> dict[str, dict[str, list[Line]]]:
    body = re.search(r'const Map<Topic, TopicLines> ' + name + r' = \{(.*?)\n\};', _LINES, re.S).group(1)
    out = {}
    for m in re.finditer(r'  Topic\.(\w+): TopicLines\((.*?)\n  \),', body, re.S):
        kinds = {}
        for k in re.finditer(r'    (open|ask|invite): \[(.*?)\n    \],', m.group(2), re.S):
            kinds[k.group(1)] = _lines_of(k.group(2))
        out[m.group(1)] = kinds
    return out


APPROACH_LINES = _approach_map('approachLines')
FORMAL_LINES = _approach_map('formalLines')
TOPIC_LINES = _topic_map('topicLines')
FORMAL_TOPIC_LINES = _topic_map('formalTopicLines')

# Approach → 주제 멘트 종류 (lines.dart enum Approach)
TOPIC_KIND = {m.group(1): (None if m.group(2) == 'null' else m.group(2).split('.')[1])
              for m in re.finditer(r"^  (\w+)\('[^']*', (null|TopicKind\.\w+)\)", _LINES, re.M)}
APPROACHES = list(TOPIC_KIND)
TOPICS = list(TOPIC_LINES)


def line_pools(approach: str, hour: int, weekday: int, topic: str | None, formal: bool):
    """(주제 멘트, 방향 멘트) 지금 시각에 맞는 것만 (Dart linePools)"""
    kind = TOPIC_KIND[approach]
    topic_pool = []
    if topic is not None and kind is not None:
        src = (FORMAL_TOPIC_LINES if formal else TOPIC_LINES).get(topic, {}).get(kind, [])
        topic_pool = [l for l in src if l.fits(hour, weekday)]
    generic = [l for l in (FORMAL_LINES if formal else APPROACH_LINES).get(approach, []) if l.fits(hour, weekday)]
    return topic_pool, generic


def pick_lines(approach: str, hour: int, weekday: int, seed: int, topic: str | None = None,
               formal: bool = False, count: int = 3) -> list[str]:
    """지금 앱 pickLines (주제 멘트 하나 + 방향 멘트 돌려 고름)"""
    topic_pool, generic = line_pools(approach, hour, weekday, topic, formal)
    cands = []
    if topic_pool:
        cands.append(topic_pool[seed % len(topic_pool)].text)
    for i in range(len(generic)):
        t = generic[(seed + i) % len(generic)].text
        if t not in cands:
            cands.append(t)
    return cands[:count]


if __name__ == '__main__':
    n = sum(len(v) for v in APPROACH_LINES.values()) + sum(len(v) for v in FORMAL_LINES.values())
    n += sum(len(l) for t in TOPIC_LINES.values() for l in t.values())
    n += sum(len(l) for t in FORMAL_TOPIC_LINES.values() for l in t.values())
    print('멘트', n, '방향', len(APPROACHES), '주제', len(TOPICS))
    for t in ['요즘 많이 바쁘지? 무리하지 말고 밥 잘 챙겨 먹어!', '저번에 말한 맛집 같이 가볼래? ㅎㅎ',
              '오늘 진짜 고생 많았어', '너는 최애 음식 뭐야? 하나만 골라봐 ㅋㅋ', '그 와중에 다 해내는 거 진짜 대단하다']:
        print(t, sorted(tag_message(t)))
