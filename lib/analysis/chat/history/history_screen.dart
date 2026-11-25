// 분석 기록 모아보기 (설정 · 대화 분석 결과에서, 하단 탭 없이 전체 화면, 오른쪽 위 되돌아가기)
// 상대별로 호감 신호 점수 변화를 막대로 (최근 historyBars번), 숫자만 저장된 기록이라 대화 내용은 없음
//   앱의 상대: 연결한 카톡 이름들의 기록을 합침 (지금 상대 → 다른 상대 → 보관한 상대 순)
//   연결 안 된 카톡 이름: 그 이름으로 따로
import 'package:material_ui/material_ui.dart';

import '../../../onboarding/data/crush_store.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/widgets/app_header.dart';
import 'chat_history_db.dart';
import 'chat_record.dart';

/// 막대로 보여줄 최근 기록 수
const historyBars = 8;

/// 한 상대(또는 연결 안 된 카톡 이름)의 기록 묶음
class HistoryGroup {
  const HistoryGroup({
    required this.title,
    required this.records,
    this.note,
  });

  /// 별명 또는 카톡 이름
  final String title;

  /// '보관', '연결 안 된 카톡 이름' 같은 작은 글자
  final String? note;

  /// 마지막 메시지 시각 순
  final List<ChatRecord> records;
}

/// 기록을 상대별로 묶기 (기록 없는 상대는 지금 상대만 빈 묶음으로)
List<HistoryGroup> groupHistory(List<ChatRecord> records, CrushStore? crushes) {
  final byName = <String, List<ChatRecord>>{};
  for (final r in records) {
    (byName[r.partner] ??= []).add(r);
  }
  final used = <String>{};
  final groups = <HistoryGroup>[];

  if (crushes != null) {
    final current = crushes.current;
    final ordered = [
      ?current,
      for (final c in crushes.active)
        if (c.id != current?.id) c,
      ...crushes.archived,
    ];
    for (final c in ordered) {
      final mine = [
        for (final name in c.chatNames) ...?byName[name],
      ]..sort((a, b) => a.lastMessageAt.compareTo(b.lastMessageAt));
      used.addAll(c.chatNames);
      if (mine.isEmpty && c.id != current?.id) continue;
      groups.add(HistoryGroup(
        title: c.nickname,
        note: c.archived ? '보관' : null,
        records: mine,
      ));
    }
  }
  for (final entry in byName.entries) {
    if (used.contains(entry.key)) continue;
    groups.add(HistoryGroup(
      title: entry.key,
      note: '연결 안 된 카톡 이름',
      records: entry.value,
    ));
  }
  return groups;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<ChatRecord>> _records = ChatHistoryDb.loadAll();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = CrushScope.maybeOf(context);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<ChatRecord>>(
          future: _records,
          builder: (context, snapshot) {
            final groups = snapshot.hasData
                ? groupHistory(snapshot.data!, crushes)
                : const <HistoryGroup>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                AppHeader(
                  showCrush: false,
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
                Text('분석 기록 모아보기', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text('상대별 호감 신호 점수 변화예요. 대화 내용은 저장하지 않아요.',
                    style: text.bodySmall),
                const SizedBox(height: 20),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text('기록을 불러오지 못했어요.', style: text.bodySmall)
                else if (groups.every((g) => g.records.isEmpty))
                  Text('아직 분석한 대화가 없어요. 대화 탭에서 분석하면 여기에 쌓여요.',
                      style: text.bodySmall)
                else
                  Column(
                    spacing: 12,
                    children: [
                      for (final g in groups) _HistoryCard(group: g),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 상대 하나: 이름 · 최근 점수 · 지난번과 차이 + 점수 막대
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.group});

  final HistoryGroup group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final records = group.records;
    final recent = records.length > historyBars
        ? records.sublist(records.length - historyBars)
        : records;
    final last = records.isEmpty ? null : records.last;
    final diff = records.length >= 2
        ? records.last.score - records[records.length - 2].score
        : null;
    final note = group.note;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: text.titleMedium),
                    Text(
                      [
                        ?note,
                        '${records.length}번 분석',
                        if (diff != null) '지난번 ${diff >= 0 ? '+' : ''}$diff점',
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (last != null)
                Text(
                  '${last.score}',
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Text('아직 분석 기록이 없어요.', style: text.bodySmall)
          else
            _ScoreBars(records: recent),
        ],
      ),
    );
  }
}

/// 점수 막대 (위에 점수, 아래에 대화 날짜), 마지막 막대만 진하게
class _ScoreBars extends StatelessWidget {
  const _ScoreBars({required this.records});

  final List<ChatRecord> records;

  static const _maxHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 6,
      children: [
        for (var i = 0; i < records.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${records[i].score}', style: small),
                const SizedBox(height: 2),
                Container(
                  height: (_maxHeight * records[i].score / 100)
                      .clamp(4, _maxHeight)
                      .toDouble(),
                  decoration: BoxDecoration(
                    color: i == records.length - 1
                        ? AppColors.peach
                        : AppColors.rose,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${records[i].lastMessageAt.month}/${records[i].lastMessageAt.day}',
                  style: small,
                ),
              ],
            ),
          ),
        // 기록이 적으면 막대가 너무 넓지 않게 빈 칸으로 채움
        for (var i = records.length; i < historyBars; i++)
          const Expanded(child: SizedBox()),
      ],
    );
  }
}
