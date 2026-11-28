// 디자인 토큰
// 글자 크기, 슬라이더 모양, 화면 넘김 (버튼 모양은 shared/widgets/primary_button.dart, secondary_button.dart)
// 화면 넘김: 모든 기기에서 새 화면이 오른쪽에서 밀려 들어오고 앞 화면은 왼쪽으로 조금 밀림 (_SlideTransitions)
import 'package:material_ui/material_ui.dart';

import '../shared/app_colors.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.peach,
      surface: AppColors.warmWhite,
      onSurface: AppColors.charcoal,
    ),
    scaffoldBackgroundColor: AppColors.warmWhite,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SlideTransitions(),
        TargetPlatform.iOS: _SlideTransitions(),
        TargetPlatform.windows: _SlideTransitions(),
        TargetPlatform.macOS: _SlideTransitions(),
        TargetPlatform.linux: _SlideTransitions(),
        TargetPlatform.fuchsia: _SlideTransitions(),
      },
    ),
    textTheme: const TextTheme(
      // 화면 제목
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.charcoal,
      ),
      // 'DueDate', 섹션 제목
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
      // 카드 제목, 버튼 글자
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
      // 본문
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.charcoal,
      ),
      // 설명, 보조 글자
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.warmGray,
      ),
      // 머리글 오른쪽 글자, 슬라이더 끝 글자
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.warmGray,
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      activeTrackColor: AppColors.peach,
      inactiveTrackColor: AppColors.track,
      thumbColor: AppColors.peach,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
      trackShape: RoundedRectSliderTrackShape(),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    ),
  );
}

/// 화면 넘김 슬라이드 (material_ui에 Cupertino 넘김이 없어서 직접)
class _SlideTransitions extends PageTransitionsBuilder {
  const _SlideTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final cover = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(enter),
      child: SlideTransition(
        position:
            Tween(begin: Offset.zero, end: const Offset(-0.3, 0)).animate(cover),
        child: child,
      ),
    );
  }
}
