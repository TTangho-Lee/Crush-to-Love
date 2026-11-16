import 'package:material_ui/material_ui.dart';

import '../config/level_texts.dart';
import '../data/app_store.dart';
import '../models/target_profile.dart';
import '../utils/format.dart';
import '../widgets/level_slider.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, this.initial});

  /// 수정 시 기존 프로필
  final TargetProfile? initial;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _myAge;
  late final TextEditingController _targetAge;
  late final TextEditingController _meetDetail;

  late MeetReason _meetReason;
  late PeriodType _periodType;
  DateTime? _periodEnd;
  late int _meetingsPerWeek;
  late int _intimacy;
  late int _courage;
  late RelationshipGoal _goal;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nickname = TextEditingController(text: p?.nickname ?? '');
    _myAge = TextEditingController(text: p?.myAge.toString() ?? '');
    _targetAge = TextEditingController(text: p?.targetAge.toString() ?? '');
    _meetDetail = TextEditingController(text: p?.meetReasonDetail ?? '');
    _meetReason = p?.meetReason ?? MeetReason.club;
    _periodType = p?.periodType ?? PeriodType.semester;
    _periodEnd = p?.periodEnd;
    _meetingsPerWeek = p?.meetingsPerWeek ?? 1;
    _intimacy = p?.intimacyLevel ?? 1;
    _courage = p?.courageLevel ?? 1;
    _goal = p?.goal ?? RelationshipGoal.friends;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _myAge.dispose();
    _targetAge.dispose();
    _meetDetail.dispose();
    super.dispose();
  }

  String? _validateAge(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n <= 0 || n > 120) return '나이를 숫자로 입력해 주세요';
    return null;
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _periodEnd = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periodType != PeriodType.unlimited && _periodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('만날 수 있는 마지막 날짜를 선택해 주세요')),
      );
      return;
    }

    final profile = TargetProfile(
      nickname: _nickname.text.trim(),
      myAge: int.parse(_myAge.text),
      targetAge: int.parse(_targetAge.text),
      meetReason: _meetReason,
      meetReasonDetail: _meetDetail.text.trim(),
      periodType: _periodType,
      periodEnd: _periodType == PeriodType.unlimited ? null : _periodEnd,
      meetingsPerWeek: _meetingsPerWeek,
      intimacyLevel: _intimacy,
      courageLevel: _courage,
      goal: _goal,
      progress: widget.initial?.progress ?? 0,
    );

    final store = AppScope.of(context);
    final navigator = Navigator.of(context);
    await store.saveProfile(profile);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sectionStyle = Theme.of(context).textTheme.titleSmall;
    final end = _periodEnd;

    return Scaffold(
      appBar: AppBar(title: const Text('상대 프로필')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nickname,
              decoration: const InputDecoration(labelText: '닉네임'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '닉네임을 입력해 주세요' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _myAge,
                    decoration: const InputDecoration(labelText: '내 나이'),
                    keyboardType: TextInputType.number,
                    validator: _validateAge,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _targetAge,
                    decoration: const InputDecoration(labelText: '상대 나이'),
                    keyboardType: TextInputType.number,
                    validator: _validateAge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MeetReason>(
              initialValue: _meetReason,
              decoration: const InputDecoration(labelText: '만나게 된 계기'),
              items: [
                for (final r in MeetReason.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _meetReason = v ?? _meetReason),
            ),
            TextFormField(
              controller: _meetDetail,
              decoration: const InputDecoration(
                labelText: '계기 상세 (선택)',
                helperText: '실명·학교명 등 고유명사는 적지 않는 것을 권장',
              ),
            ),
            const SizedBox(height: 24),
            Text('만날 수 있는 기간', style: sectionStyle),
            const SizedBox(height: 8),
            SegmentedButton<PeriodType>(
              segments: [
                for (final t in PeriodType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_periodType},
              onSelectionChanged: (s) => setState(() => _periodType = s.first),
            ),
            if (_periodType != PeriodType.unlimited)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('마지막 날'),
                trailing: Text(end == null ? '선택' : formatDate(end)),
                onTap: _pickEndDate,
              ),
            const SizedBox(height: 16),
            Text('일주일에 만나는 횟수', style: sectionStyle),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _meetingsPerWeek > 0
                      ? () => setState(() => _meetingsPerWeek--)
                      : null,
                ),
                Text('$_meetingsPerWeek회'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _meetingsPerWeek < 14
                      ? () => setState(() => _meetingsPerWeek++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LevelSlider(
              label: '친한 정도',
              descriptions: intimacyLevelTexts,
              value: _intimacy,
              onChanged: (v) => setState(() => _intimacy = v),
            ),
            const SizedBox(height: 16),
            LevelSlider(
              label: '낼 수 있는 용기',
              descriptions: courageLevelTexts,
              value: _courage,
              onChanged: (v) => setState(() => _courage = v),
            ),
            const SizedBox(height: 24),
            Text('목표', style: sectionStyle),
            const SizedBox(height: 8),
            SegmentedButton<RelationshipGoal>(
              segments: [
                for (final g in RelationshipGoal.values)
                  ButtonSegment(value: g, label: Text(g.label)),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
