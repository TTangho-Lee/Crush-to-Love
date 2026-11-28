"""lib/dummy 규칙을 파이썬으로 옮긴 것 (시뮬레이션 · 테스트 기대값용)

옮긴 것: 미션 사전(dummy_mission_lines.dart를 직접 읽음) · 로드맵 만들기(dummy_roadmap_generator.dart)
        · 상황 읽기 · 오늘의 미션 규칙 점수 · 다음 주차 조정(dummy_mission_rules.dart)
Dart 쪽을 고치면 여기도 같이 고칠 것 (check_port.py로 기존 테스트 성질 확인)
"""
from __future__ import annotations

import math
import os
import re
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta

# ---------- 사전 ----------

STAGES = ['greet', 'topic', 'follow', 'often', 'plan', 'alone', 'show', 'confess']
TAGS = ['prep', 'greet', 'react', 'ask', 'share', 'care', 'push', 'invite', 'express']
INTIMACY = ['faceOnly', 'smallTalk', 'close']
GOALS = ['friends', 'some', 'dating']

BOLD = {'push', 'invite', 'express'}
GENTLE = {'prep', 'react', 'care'}

def _default_root() -> str:
    """프로젝트 폴더: DUEDATE_ROOT, 없으면 이 파일 두 단계 위 (tool/learning → 프로젝트)"""
    env = os.environ.get('DUEDATE_ROOT')
    if env:
        return env
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, '..', '..'))


DEFAULT_ROOT = _default_root()


@dataclass(frozen=True)
class Line:
    title: str
    tip: str
    offline: bool
    level: int
    tags: frozenset


def load_lines(root: str = DEFAULT_ROOT) -> dict[str, list[Line]]:
    """dummy_mission_lines.dart에서 단계별 미션 읽기"""
    path = os.path.join(root, 'lib', 'dummy', 'dummy_mission_lines.dart')
    text = open(path, encoding='utf-8').read().replace('\r', '')
    out: dict[str, list[Line]] = {}
    for m in re.finditer(r'DummyStage\.(\w+): \[\n(.*?)\n  \],', text, re.S):
        stage, body = m.group(1), m.group(2)
        lines = []
        for row in body.split('\n'):
            row = row.strip()
            if not row.startswith('DummyMissionLine('):
                continue
            strs = re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", row)
            texts = [a or b for a, b in strs]
            level = re.search(r'level: (\d)', row)
            tags = re.search(r'tags: \{([^}]*)\}', row)
            lines.append(Line(
                title=texts[0],
                tip=texts[1],
                offline='offline: true' in row,
                level=int(level.group(1)) if level else 1,
                tags=frozenset(re.findall(r'MissionTag\.(\w+)', tags.group(1)) if tags else []),
            ))
        out[stage] = lines
    assert list(out) == STAGES, list(out)
    return out


LINES = load_lines()


def line_of(mission_id: str) -> Line | None:
    stage, _, i = mission_id.partition('-')
    lines = LINES.get(stage)
    if lines is None or not i.isdigit() or int(i) >= len(lines):
        return None
    return lines[int(i)]


# ---------- 모델 ----------

@dataclass(frozen=True)
class Profile:
    dday: date
    intimacy: str  # INTIMACY
    meetings: int
    courage: int
    goal: str  # GOALS
    reason: str = '종강'


@dataclass(frozen=True)
class Mission:
    id: str
    done: bool = False
    done_at: datetime | None = None
    brave: bool = False

    @property
    def line(self) -> Line | None:
        return line_of(self.id)

    @property
    def level(self) -> int:
        line = self.line
        return line.level if line else 1

    @property
    def offline(self) -> bool:
        line = self.line
        return line.offline if line else False

    @property
    def tags(self) -> frozenset:
        line = self.line
        return line.tags if line else frozenset()

    def mark(self, done: bool, at: datetime | None = None, brave: bool = False) -> 'Mission':
        return Mission(self.id, done, at if done else None, done and brave)


@dataclass(frozen=True)
class Week:
    week_no: int
    stage: str
    from_dday: int
    to_dday: int
    missions: tuple

    @property
    def all_done(self) -> bool:
        return all(m.done for m in self.missions)


@dataclass(frozen=True)
class Roadmap:
    crush_id: int
    started_at: date
    weeks: tuple
    shift: int = 0


def courage_level(percent: int) -> int:
    """0 저전력 · 1 표준 · 2 고속충전 · 3 풀충전"""
    return 0 if percent < 35 else 1 if percent < 65 else 2 if percent < 90 else 3


def courage_max(percent: int) -> int:
    return [1, 2, 3, 3][courage_level(percent)]


def as_date(t) -> date:
    return t.date() if isinstance(t, datetime) else t


def days_until(day, now) -> int:
    return (as_date(day) - as_date(now)).days


# ---------- 로드맵 ----------

MAX_WEEKS = 8
PER_WEEK = 3


def week_ranges(total_days_left: int) -> list[tuple[int, int]]:
    total = max(total_days_left, 0)
    days = total + 1
    count = min(max((days + 6) // 7, 1), MAX_WEEKS)
    length = (days + count - 1) // count
    return [(total - i * length, max(total - (i + 1) * length + 1, 0)) for i in range(count)]


def current_week_index(ranges, days_left: int) -> int:
    if days_left > ranges[0][0]:
        return 0
    for i, (a, b) in enumerate(ranges):
        if b <= days_left <= a:
            return i
    return len(ranges) - 1


def goal_stage(goal: str) -> int:
    return {'friends': 3, 'some': 6, 'dating': 7}[goal]


def start_stage(intimacy: str) -> int:
    return {'faceOnly': 0, 'smallTalk': 1, 'close': 4}[intimacy]


def dart_round(x: float) -> int:
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


def stages_for(p: Profile, week_count: int) -> list[int]:
    end = goal_stage(p.goal)
    start = min(start_stage(p.intimacy), end)
    span = end - start + 1
    out = []
    for i in range(week_count):
        if week_count >= span:
            out.append(start + i * span // week_count)
        elif week_count == 1:
            out.append(start)
        else:
            out.append(min(start + 2 * i, start + dart_round(i * (span - 1) / (week_count - 1))))
    return out


def rotation_order(n: int, seed: int) -> list[int]:
    """지금 앱의 돌려 고르는 순서"""
    return [(i * 5 + seed) % n for i in range(n)]


def pick(stage: int, seed: int, can_meet: bool, max_level: int, used: set,
         keep=(), order=None) -> list[Mission]:
    """한 주차 미션 고르기, order를 주면 그 순서로 (학습), 없으면 지금 앱 순서"""
    name = STAGES[stage]
    lines = LINES[name]
    idof = lambda i: f'{name}-{i}'
    allowed = lambda i: can_meet or not lines[i].offline
    learned = order is not None
    order = order if learned else rotation_order(len(lines), seed)
    tiers = [
        lambda i: allowed(i) and lines[i].level <= max_level and idof(i) not in used,
        lambda i: allowed(i) and idof(i) not in used,
        allowed,
    ]
    picked: list[int] = []
    kept = {m.id for m in keep}
    for tier in tiers:
        for i in order:
            if len(keep) + len(picked) >= PER_WEEK:
                break
            if tier(i) and i not in picked and idof(i) not in kept:
                picked.append(i)
    # 학습 순서면 쉬운 미션(용기 최대보다 한 단계 아래, 저전력이면 용기 1)을 최소 1개 (학습 점수가 가장 낮은 것과 바꿈)
    if learned and picked:
        easy_max = max(1, max_level - 1)
        easy = lambda i: lines[i].level <= easy_max
        if not any(m.level <= easy_max for m in keep) and not any(easy(i) for i in picked):
            for i in order:
                if easy(i) and allowed(i) and idof(i) not in used and i not in picked and idof(i) not in kept:
                    picked[-1] = i
                    break
    picked.sort()
    return list(keep) + [Mission(idof(i)) for i in picked]


def build_weeks(crush_id: int, p: Profile, started_at: date, today, old: Roadmap | None = None,
                shift: int = 0, future_only: bool = False, order_for=None) -> list[Week]:
    """_weeks 옮김, order_for(stage, week_index, used) → 학습 순서 (없으면 None)"""
    ranges = week_ranges(days_until(p.dday, started_at))
    base = stages_for(p, len(ranges))
    end = goal_stage(p.goal)
    left = days_until(p.dday, today)
    now_index = current_week_index(ranges, left)
    old_weeks = {w.week_no: w for w in (old.weeks if old else ())}
    used: set = set()
    weeks: list[Week] = []
    floor = 0
    for i, (frm, to) in enumerate(ranges):
        prev = old_weeks.get(i + 1)
        ended = to > left
        if prev is not None and (ended or (future_only and i <= now_index)):
            weeks.append(replace(prev, from_dday=frm, to_dday=to))
            used.update(m.id for m in prev.missions)
            if not ended:
                floor = max(floor, STAGES.index(prev.stage))
            continue
        target = base[i] + shift if i > now_index else base[i]
        stage = min(max(target, floor), max(floor, end))
        floor = stage
        if prev is not None and future_only and STAGES.index(prev.stage) == stage:
            weeks.append(replace(prev, from_dday=frm, to_dday=to))
            used.update(m.id for m in prev.missions)
            continue
        order = order_for(stage, i, used) if order_for else None
        missions = pick(stage, seed=crush_id * 31 + (i + 1) * 7, can_meet=p.meetings > 0,
                        max_level=courage_max(p.courage), used=used,
                        keep=[m for m in (prev.missions if prev else ()) if m.done], order=order)
        used.update(m.id for m in missions)
        weeks.append(Week(i + 1, STAGES[stage], frm, to, tuple(missions)))
    extra = [m for w in old_weeks.values() if w.week_no > len(ranges)
             for m in w.missions if m.done and m.id not in used]
    if extra:
        last = weeks.pop()
        weeks.append(replace(last, missions=last.missions + tuple(extra)))
    return weeks


def build_roadmap(crush_id: int, p: Profile, today, order_for=None) -> Roadmap:
    started = as_date(today)
    return Roadmap(crush_id, started, tuple(build_weeks(crush_id, p, started, started, order_for=order_for)))


def adapt_roadmap(old: Roadmap, p: Profile, today, shift: int, order_for=None) -> Roadmap:
    weeks = build_weeks(old.crush_id, p, old.started_at, today, old=old, shift=shift,
                        future_only=True, order_for=order_for)
    return replace(old, weeks=tuple(weeks), shift=shift)


# ---------- 상황 ----------

@dataclass(frozen=True)
class Chat:
    interest: str  # 'low' | 'mid' | 'high'
    approach: str | None = None
    intimacy: str | None = None
    last_talk_at: datetime | None = None


def stage_weight(stage: int) -> float:
    return 1 + stage * 0.5


def mission_points(m: Mission, stage: int, earned: bool = False) -> float:
    return (0.75 + 0.25 * m.level) * stage_weight(stage) * (1.5 if earned and m.brave else 1)


@dataclass(frozen=True)
class Situation:
    profile: Profile
    roadmap: Roadmap
    days_left: int
    week_index: int
    progress: float
    expected: float
    pace: str  # 'ahead' | 'onTrack' | 'behind'
    done_count: int
    total_count: int
    elapsed: float
    rest_days: int | None
    chat: Chat | None

    @property
    def week(self) -> Week:
        return self.roadmap.weeks[self.week_index]

    @property
    def passed(self) -> bool:
        return self.days_left < 0

    def talk_gap(self, today) -> int | None:
        at = self.chat.last_talk_at if self.chat else None
        return None if at is None else days_until(today, at)


def read_situation(p: Profile, r: Roadmap, today, chat: Chat | None = None) -> Situation:
    weeks = r.weeks
    left = days_until(p.dday, today)
    wi = current_week_index([(w.from_dday, w.to_dday) for w in weeks], left)
    total = earned = expected = 0.0
    done = count = 0
    last_done = None
    for i, w in enumerate(weeks):
        st = STAGES.index(w.stage)
        points = sum(mission_points(m, st) for m in w.missions)
        total += points
        for m in w.missions:
            count += 1
            if not m.done:
                continue
            done += 1
            earned += mission_points(m, st, earned=True)
            if m.done_at is not None and (last_done is None or m.done_at > last_done):
                last_done = m.done_at
        if w.to_dday > left:
            expected += points
        elif i == wi:
            length = w.from_dday - w.to_dday + 1
            expected += points * min(max(w.from_dday - left, 0), length) / length
    progress = 0.0 if total == 0 else min(1.0, earned / total)
    rate = 0.0 if total == 0 else expected / total
    diff = progress - rate
    pace = 'onTrack' if rate < 0.05 else 'ahead' if diff >= 0.08 else 'behind' if diff <= -0.15 else 'onTrack'
    span = days_until(p.dday, r.started_at)
    passed = days_until(today, r.started_at)
    return Situation(
        profile=p, roadmap=r, days_left=left, week_index=wi, progress=progress, expected=rate,
        pace=pace, done_count=done, total_count=count,
        elapsed=1.0 if span <= 0 else min(max(passed / span, 0), 1),
        rest_days=None if last_done is None else days_until(today, last_done),
        chat=chat)


# ---------- 오늘의 미션 규칙 점수 ----------

APPROACH_TAGS = {
    'rest': {'prep', 'react'}, 'patience': {'prep', 'react'},
    'comfort': {'care'},
    'fixPlan': {'invite'}, 'invite': {'invite'},
    'breakIce': {'greet', 'ask'}, 'firstTalk': {'greet', 'ask'},
    'openUp': {'share', 'express'},
    'askBack': {'ask'}, 'common': {'ask'},
    'react': {'react'}, 'tempo': {'react'},
    'light': {'greet', 'react', 'share'},
    'lighten': {'share'}, 'laughTopic': {'share'},
    'routine': {'care', 'push'},
    'reconnect': {'push', 'care'},
    'afterMeet': {'care', 'express'},
}


def rule_terms(m: Mission, s: Situation, stage: int, today) -> list[tuple[float, str]]:
    """미션 하나의 규칙 (점수, 이유 key) 목록 (rankToday 안쪽 옮김)"""
    max_level = courage_max(s.profile.courage)
    chat = s.chat
    approach = chat.approach if chat else None
    gap = s.talk_gap(today)
    rest = s.rest_days
    meetings = s.profile.meetings
    tags = m.tags
    rules: list[tuple[float, str]] = []
    if m.level == max_level and max_level >= 2:
        rules.append((1.5, 'courageFit'))
    elif m.level < max_level or m.level == 1:
        rules.append((1.0, 'courageEasy'))
    elif s.pace == 'behind' and m.level == max_level + 1:
        rules.append((1.2, 'braveBoost'))
    else:
        rules.append((-3.0, ''))
    if approach is not None and tags & APPROACH_TAGS[approach]:
        rules.append((2.0, 'approach'))
    if chat is not None and chat.interest == 'low':
        if tags & BOLD:
            rules.append((-2.0, ''))
        if tags & GENTLE:
            rules.append((1.0, 'gentle'))
    if chat is not None and chat.interest == 'high' and stage >= STAGES.index('often') and tags & BOLD:
        rules.append((1.5, 'boldHigh'))
    if gap is not None and gap >= 3 and tags & {'push', 'care', 'greet'}:
        rules.append((1.5, 'talkGap'))
    if rest is not None and rest >= 3 and m.level == 1:
        rules.append((1.0, 'rested'))
    if s.pace == 'behind' and m.level >= 2:
        rules.append((0.3 * m.level, 'behind'))
    if courage_level(s.profile.courage) == 0 and 'prep' in tags:
        rules.append((0.5, 'prepLow'))
    if m.offline and meetings >= 3:
        rules.append((1.0, 'meetOften'))
    if m.offline and meetings == 1:
        rules.append((-0.5, ''))
    return rules


def rule_score(m: Mission, s: Situation, stage: int, today) -> float:
    return sum(v for v, _ in rule_terms(m, s, stage, today))


def today_candidates(s: Situation) -> tuple[Week, bool, list[tuple[int, Mission]]]:
    """오늘의 미션 후보: 이번 주 안 한 미션 (다 했으면 다음 주), (주차, 미리인지, [(사전 순서, 미션)])"""
    weeks = s.roadmap.weeks
    week = s.week
    early = False
    if week.all_done and s.week_index + 1 < len(weeks):
        week = weeks[s.week_index + 1]
        early = True
    return week, early, [(i, m) for i, m in enumerate(week.missions) if not m.done]


def rank_today(s: Situation, today) -> list[Mission]:
    """규칙 점수 순 (같으면 사전 순서)"""
    week, _, cands = today_candidates(s)
    stage = STAGES.index(week.stage)
    scored = [(rule_score(m, s, stage, today), i, m) for i, m in cands]
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [m for _, _, m in scored]


# ---------- 다음 주차 조정 ----------

def adapt_shift(s: Situation) -> int | None:
    cur = s.roadmap.shift
    chat = s.chat
    if s.passed:
        return None
    if chat is not None and chat.interest == 'low':
        return None if cur == -1 else -1
    if cur < 0 and chat is not None:
        return 0
    if cur >= 1:
        return None
    seen = chat.intimacy if chat else None
    if seen is not None and INTIMACY.index(seen) > INTIMACY.index(s.profile.intimacy):
        return 1
    if s.pace == 'ahead' and courage_level(s.profile.courage) >= 1:
        return 1
    return None
