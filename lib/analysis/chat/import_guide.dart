// 카톡 대화 가져오는 법 (피그마 9번 '대화 넣기' 안내)
// 기기별(안드로이드 · 아이폰 · PC) 단계를 그림 카드로, 쓰는 기기 탭이 먼저 열림
//   대화 화면 ① 제목 오른쪽 '? 가져오는 법'을 누르면 아래에서 올라오는 창으로 (showImportGuide)
//   안드로이드는 같은 앞 단계 뒤에 두 갈래: 바로 보내기(공유) · 파일로 저장해서 불러오기
//   아이폰은 파일로 저장해서 불러오기만 (공유 목록에 뜨려면 Share Extension이 필요한데 아직 없음)
//   TODO: 아이폰 실제 메뉴 이름 확인
// 그림은 직접 그린 단순한 휴대폰 모양 + 누를 곳 강조 (카톡 화면 캡처 · 모방 안 함)
// 카톡 메뉴 이름이 바뀌면 아래 _sections 글자만 고치면 됨
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';

/// 가져오는 기기
enum _Device {
  android('안드로이드'),
  ios('아이폰'),
  pc('PC');

  const _Device(this.label);

  final String label;

  /// 지금 쓰는 기기 (웹은 PC로 봄)
  static _Device get current {
    if (kIsWeb) return pc;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => pc,
    };
  }
}

/// 그림에서 강조할 곳
enum _Spot {
  /// 오른쪽 위 버튼
  topRight,

  /// 오른쪽 아래 버튼
  bottomRight,

  /// 목록 중 한 줄
  row,

  /// 아래에서 올라온 창
  sheet,

  /// 가운데
  center,
}

/// 단계 하나
typedef _GuideStep = ({String text, IconData icon, _Spot spot});

/// 단계 묶음 (label: 갈래 이름, 없으면 공통 단계)
typedef _Section = ({String? label, List<_GuideStep> steps});

// 자주 쓰는 단계
const _GuideStep _openMenu =
    (text: '대화방 오른쪽 위 ≡', icon: Icons.menu, spot: _Spot.topRight);
const _GuideStep _openSettings =
    (text: '오른쪽 위 ⚙ 설정', icon: Icons.settings_outlined, spot: _Spot.topRight);
const _GuideStep _export =
    (text: '대화 내용 내보내기', icon: Icons.file_upload_outlined, spot: _Spot.row);
const _GuideStep _loadFile =
    (text: "여기서 'txt 파일 불러오기'", icon: Icons.upload_file, spot: _Spot.center);
const _GuideStep _textOnly =
    (text: "'텍스트 메시지만 보내기'", icon: Icons.notes, spot: _Spot.row);

/// 기기별 단계 묶음 (번호는 묶음을 이어서 셈, 갈래끼리는 같은 번호부터)
const Map<_Device, List<_Section>> _sections = {
  _Device.android: [
    (label: null, steps: [_openMenu, _openSettings, _export]),
    (
      label: '바로 보내기',
      steps: [
        _textOnly,
        (text: '공유 목록에서 DueDate', icon: Icons.favorite, spot: _Spot.sheet),
      ],
    ),
    (
      label: '파일로 저장해서 불러오기',
      steps: [
        (text: "'모든 메시지 내부저장소에 저장'", icon: Icons.save_alt, spot: _Spot.row),
        _loadFile,
      ],
    ),
  ],
  _Device.ios: [
    (
      label: null,
      steps: [
        _openMenu,
        _openSettings,
        _export,
        _textOnly,
        (text: "'파일에 저장'", icon: Icons.folder_outlined, spot: _Spot.sheet),
        _loadFile,
      ],
    ),
  ],
  _Device.pc: [
    (
      label: null,
      steps: [
        _openMenu,
        (text: '대화 내용 → 대화 내보내기', icon: Icons.file_upload_outlined, spot: _Spot.row),
        (text: 'txt 파일로 저장', icon: Icons.save_alt, spot: _Spot.center),
        _loadFile,
      ],
    ),
  ],
};

/// 기기별 끝에 붙는 한 줄, 없으면 null
const Map<_Device, String> _notes = {
  _Device.pc: '메모장으로 열어 전체 복사 후 붙여넣어도 돼요.',
};

/// 아래에서 올라오는 창으로 안내 (하단 탭 위로 덮음)
Future<void> showImportGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // 안드로이드는 줄이 3개라 길어서 화면 높이의 90%까지 쓰고, 넘치면 위아래로 넘겨 봄
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: ImportGuide(),
      ),
    ),
  );
}

/// 카톡 대화 가져오는 법 (제목 + 기기 탭 + 단계 카드)
class ImportGuide extends StatefulWidget {
  const ImportGuide({super.key});

  @override
  State<ImportGuide> createState() => _ImportGuideState();
}

class _ImportGuideState extends State<ImportGuide> {
  _Device _device = _Device.current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sections = _sections[_device] ?? const <_Section>[];
    final note = _notes[_device];
    final wide = _device == _Device.pc;

    // 갈래(label 있는 묶음)는 공통 단계 다음 번호부터 같은 번호로 시작
    final common = [
      for (final section in sections)
        if (section.label == null) ...section.steps,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('카톡에서 가져오는 법', style: text.titleSmall),
        const SizedBox(height: 10),
        Row(
          spacing: 6,
          children: [
            for (final device in _Device.values)
              _Tab(
                label: device.label,
                selected: device == _device,
                onTap: () => setState(() => _device = device),
              ),
          ],
        ),
        for (final section in sections) ...[
          const SizedBox(height: 10),
          if (section.label case final label?) ...[
            Text(label, style: text.labelSmall),
            const SizedBox(height: 6),
          ],
          _StepRow(
            steps: section.steps,
            firstNumber: section.label == null ? 1 : common.length + 1,
            wide: wide,
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: text.bodySmall),
        ],
      ],
    );
  }
}

/// 단계 카드 한 줄 (옆으로 넘겨 보기)
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.steps,
    required this.firstNumber,
    required this.wide,
  });

  final List<_GuideStep> steps;

  /// 첫 카드 번호
  final int firstNumber;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _StepCard(
          number: firstNumber + i,
          step: steps[i],
          wide: wide,
        ),
      ),
    );
  }
}

/// 기기 고르기 작은 탭
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.peach : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.charcoal,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

/// 단계 카드 (그림 + 번호 + 한 줄)
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.step,
    required this.wide,
  });

  final int number;
  final _GuideStep step;

  /// PC면 가로로 긴 화면 그림
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 76,
            child: Center(
              child: _ScreenSketch(icon: step.icon, spot: step.spot, wide: wide),
            ),
          ),
          const SizedBox(height: 8),
          // 번호 (대화 화면 단계 번호와 같은 모양)
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.peach,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: text.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColors.charcoal,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 11.5,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 단순한 휴대폰(PC면 모니터) 화면 그림, 누를 곳만 분홍으로 강조
class _ScreenSketch extends StatelessWidget {
  const _ScreenSketch({
    required this.icon,
    required this.spot,
    required this.wide,
  });

  final IconData icon;
  final _Spot spot;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // 화면 내용 대신 흐린 줄
    Widget line(double width) => Container(
          width: width,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.track,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    final highlight = switch (spot) {
      _Spot.row || _Spot.sheet => Container(
          width: double.infinity,
          height: spot == _Spot.sheet ? 20 : 14,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: spot == _Spot.sheet
                ? const BorderRadius.vertical(top: Radius.circular(4))
                : BorderRadius.circular(3),
          ),
          child: Icon(icon, size: 10, color: AppColors.charcoal),
        ),
      _ => Container(
          width: spot == _Spot.center ? 24 : 16,
          height: spot == _Spot.center ? 24 : 16,
          decoration: const BoxDecoration(
            color: AppColors.peach,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: spot == _Spot.center ? 14 : 10,
            color: AppColors.charcoal,
          ),
        ),
    };

    final alignment = switch (spot) {
      _Spot.topRight => Alignment.topRight,
      _Spot.bottomRight => Alignment.bottomRight,
      _Spot.row => const Alignment(0, 0.15),
      _Spot.sheet => Alignment.bottomCenter,
      _Spot.center => Alignment.center,
    };

    return Container(
      width: wide ? 80 : 44,
      height: wide ? 52 : 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(wide ? 4 : 8),
        border: Border.all(color: AppColors.charcoal, width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [line(20), line(28), line(16), line(24)],
            ),
          ),
          Align(alignment: alignment, child: highlight),
        ],
      ),
    );
  }
}
