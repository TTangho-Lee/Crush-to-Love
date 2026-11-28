// 피그마 10번 화면 (데이트 준비하기)
// 장소 · 날씨 · 시간 · 인원을 칩으로 고르고 '준비 가이드 보기' → 13번
// 지금 사이 · 용기 · 목표는 지금 상대의 입력값, 마지막 대화 분석이 지금 상대와의 대화면 사이 · 주제는 분석 결과 (guideBasisOf)
// 지금 상대가 없으면 (예시 화면) 미션 흐름의 예시 입력값
// 웃음 표현 · 말 높이는 설정에서 고른 값 (대화에 맞춤이면 대화 기준)
// 고른 조건은 DateStore에 (탭을 옮겨도 그대로)
import 'package:material_ui/material_ui.dart';

import '../../mission/data/mission_store.dart';
import '../../onboarding/data/crush_store.dart';
import '../../shared/app_colors.dart';
import '../../shared/models.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/primary_button.dart';
import '../chat/chat_store.dart';
import 'date_guide.dart';
import 'date_guide_rules.dart';
import 'date_guide_screen.dart';
import 'date_store.dart';

class DatePrepScreen extends StatelessWidget {
  const DatePrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = DateScope.of(context);
    final choice = store.choice;
    final crushes = CrushScope.maybeOf(context);
    final chat = ChatScope.of(context).stats;
    final partner = chat.record?.partner;
    final basis = guideBasisOf(
      crushes?.profile ?? MissionScope.of(context).profile,
      chat,
      // 지금 상대가 있으면 그 상대 대화일 때만
      useChat: crushes == null ||
          crushes.current == null ||
          (partner != null && crushes.chatBelongsToCurrent(partner)),
      // 설정에서 고른 웃음 표현(나) · 말 높이(지금 상대)
      laugh: crushes?.laughStyle ?? LaughStyle.auto,
      speech: crushes?.current?.speech ?? SpeechLevel.auto,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('데이트 준비하기', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('약속이 정해졌다면 장소와 상황에 맞는 준비를 시작해요.', style: text.bodySmall),
            const SizedBox(height: 24),
            _Section(
              title: '장소',
              // 4개씩 두 줄
              child: Column(
                spacing: 8,
                children: [
                  for (var row = 0; row < DatePlace.values.length; row += 4)
                    _ChipRow([
                      for (final place in DatePlace.values.skip(row).take(4))
                        _Chip(
                          icon: place.icon,
                          label: place.label,
                          vertical: true,
                          selected: choice.place == place,
                          onTap: () => store.choose(choice.copyWith(place: place)),
                        ),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              title: '날씨',
              child: _ChipRow([
                for (final weather in DateWeather.values)
                  _Chip(
                    icon: weather.icon,
                    label: weather.label,
                    vertical: true,
                    selected: choice.weather == weather,
                    onTap: () =>
                        store.choose(choice.copyWith(weather: weather)),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Section(
                    title: '시간',
                    child: _ChipRow([
                      for (final time in MeetTime.values)
                        _Chip(
                          icon: time.icon,
                          label: time.label,
                          selected: choice.time == time,
                          onTap: () =>
                              store.choose(choice.copyWith(time: time)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Section(
                    title: '누구랑',
                    child: _ChipRow([
                      for (final company in Company.values)
                        _Chip(
                          icon: company.icon,
                          label: company.label,
                          selected: choice.company == company,
                          onTap: () =>
                              store.choose(choice.copyWith(company: company)),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 가이드에 반영되는 상황 (대화 분석이 있으면 말풍선 아이콘)
            Row(
              children: [
                Icon(
                  basis.fromChat ? Icons.forum_outlined : Icons.person_outline,
                  size: 15,
                  color: AppColors.warmGray,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${basis.intimacy.label} · ${basis.goal.label}'
                    '${basis.fromChat ? ' · 대화 분석 반영' : ''}',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '준비 가이드 보기 →',
              onPressed: () {
                store.build(basis);
                // 피그마 13번으로 (데이트 탭 안에서 이동, 하단 탭 유지)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DateGuideScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 제목 + 고르는 칸
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// 칩을 같은 너비로 한 줄에
class _ChipRow extends StatelessWidget {
  const _ChipRow(this.chips);

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }
}

/// 아이콘 + 이름 칩, 고르면 분홍 바탕 (vertical: 아이콘 위 · 이름 아래)
/// 칸이 좁으면 이름을 줄이거나 자르지 않고 글자를 조금 작게
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.vertical = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
    final iconWidget = Icon(icon, size: vertical ? 22 : 16, color: AppColors.charcoal);
    final labelWidget = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, style: style, maxLines: 1, softWrap: false),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: vertical ? 64 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.ivory,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.peach : AppColors.ivory,
          ),
        ),
        child: vertical
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [iconWidget, labelWidget],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [iconWidget, Flexible(child: labelWidget)],
              ),
      ),
    );
  }
}
