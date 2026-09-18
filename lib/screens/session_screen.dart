import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/session_controller.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'session_end_screen.dart';

class SessionScreen extends StatefulWidget {
  final String dayId;
  const SessionScreen({super.key, required this.dayId});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sessionCtrl.session == null) {
        final day = store.db.days.firstWhere((d) => d.id == widget.dayId);
        sessionCtrl.start(day);
      }
    });
  }

  Future<void> _onBack() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عندك تمرين شغال دلوقتي',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('تحب تعمل إيه؟',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 16),
              SButton('⏹ إنهاء التمرين وحفظه',
                  onPressed: () => Navigator.pop(ctx, 'finish')),
              const SizedBox(height: 8),
              SButton('↩ رجوع للرئيسية والتمرين يفضل شغال',
                  kind: BtnKind.secondary,
                  onPressed: () => Navigator.pop(ctx, 'keep')),
              const SizedBox(height: 8),
              SButton('🗑 إلغاء التمرين من غير حفظ',
                  kind: BtnKind.ghost,
                  onPressed: () => Navigator.pop(ctx, 'abandon')),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'finish') {
      _finish(confirm: false);
    } else if (choice == 'keep') {
      Navigator.pop(context);
    } else if (choice == 'abandon') {
      final ok = await confirmDialog(
          context, 'هيتلغي التمرين ده من غير ما يتحفظ. متأكد؟',
          danger: true);
      if (!mounted) return;
      if (ok) {
        sessionCtrl.abandon();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _finish({bool confirm = true}) async {
    if (confirm) {
      final ok = await confirmDialog(context, 'تأكيد إنهاء التمرين؟');
      if (!ok) return;
    }
    if (!mounted) return;
    sessionCtrl.finish();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SessionEndScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionCtrl,
      builder: (context, _) {
        final s = sessionCtrl.session;
        if (s == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: C.accent)));
        }

        var inCore = false, inCardio = false;
        final items = <Widget>[];
        for (var i = 0; i < s.exercises.length; i++) {
          final ex = s.exercises[i];
          if (ex.core && !inCore) {
            items.add(const SectionTitle('🔥 سيشن البطن (Core)'));
            inCore = true;
          }
          if (ex.cardio && !inCardio) {
            items.add(const SectionTitle('🚴 سيشن الكارديو (Cardio)'));
            inCardio = true;
          }
          final unlocked = i < s.unlockedExerciseCount;
          items.add(unlocked
              ? _ExerciseCard(key: ValueKey('ex_${ex.exerciseId}_$i'), exIdx: i)
              : _lockedExercise(ex));
        }

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: s.dayName.toUpperCase(),
            title: 'التمرين شغال',
            showBack: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: C.text),
              onPressed: _onBack,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _WorkClock(),
              const _RestPanel(),
              ...items,
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SButton('⏹  إنهاء التمرين',
                  kind: BtnKind.danger, onPressed: () => _finish()),
            ),
          ),
        );
      },
    );
  }

  Widget _lockedExercise(SessionExercise ex) {
    return Opacity(
      opacity: 0.55,
      child: SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('🔒 ${ex.name}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Pill('${ex.targetReps} عدة هدف'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('خلّص التمرين اللي قبله الأول عشان التمرين ده يتفتح',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ],
        ),
      ),
    );
  }
}

/// ساعة التمرين الكلي — بتتحدث لوحدها كل ثانية من غير ما تعيد رسم الشاشة كلها
class _WorkClock extends StatelessWidget {
  const _WorkClock();

  @override
  Widget build(BuildContext context) {
    return SCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Text('وقت التمرين الكلي',
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: sessionCtrl.workSeconds,
            builder: (_, v, __) => Text(
              fmtTime(v),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: C.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// لوحة الراحة — بتظهر بس وقت الراحة
class _RestPanel extends StatelessWidget {
  const _RestPanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: sessionCtrl.restLeft,
      builder: (_, left, __) {
        if (left == null) return const SizedBox.shrink();
        final total = sessionCtrl.restTotal <= 0 ? 1 : sessionCtrl.restTotal;
        return SCard(
          borderColor: C.accentDim,
          child: Column(
            children: [
              const Text('فترة الراحة',
                  style: TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 6),
              Text(
                fmtTime(left),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: C.accent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (left / total).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: C.panel2,
                  valueColor: const AlwaysStoppedAnimation(C.accent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SButton('+30 ثانية',
                        kind: BtnKind.secondary,
                        small: true,
                        onPressed: () => sessionCtrl.addRest(30)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SButton('تخطي الراحة →',
                        kind: BtnKind.secondary,
                        small: true,
                        onPressed: sessionCtrl.skipRest),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// كارت تمرين واحد جوه الجلسة
class _ExerciseCard extends StatefulWidget {
  final int exIdx;
  const _ExerciseCard({super.key, required this.exIdx});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final ex = sessionCtrl.session!.exercises[widget.exIdx];
    final last = Analytics.lastPerformance(ex.exerciseId, ex.name);
    final def = store.defOf(ex.exerciseId);

    final subParts = <String>['راحة مقترحة: ${ex.rest} ثانية'];
    if (last != null) {
      subParts.add('📈 آخر مرة: ${last.weight}كجم × ${last.reps}');
    }
    if (ex.autoBumped) {
      subParts.add('🔼 اتزود 2.5كجم تلقائي (كملت كل المجموعات آخر مرة)');
    } else if (ex.prefilled) {
      subParts.add('🔁 القيم اتملت من آخر مرة، عدّلها لو حابب تزود');
    }

    final lastSet = ex.loggedSets.isEmpty ? null : ex.loggedSets.last;

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(ex.name,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (ex.noRestAfter) const Pill('⚡ سوبرست', accent: true),
                    if (ex.swapped) const Pill('🔄 اتبدل'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Pill('${ex.targetReps} عدة هدف'),
              IconButton(
                tooltip: 'بدّل التمرين ده للجلسة دي بس',
                icon: const Icon(Icons.swap_horiz_rounded,
                    size: 20, color: C.muted),
                onPressed: () async {
                  final name = await promptDialog(
                    context,
                    title: 'اسم التمرين البديل (للجلسة دي بس)',
                    initial: ex.name,
                  );
                  if (name != null && name.isNotEmpty) {
                    sessionCtrl.swapExercise(widget.exIdx, name);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subParts.join('  ·  '),
              style:
                  const TextStyle(fontSize: 11.5, color: C.muted, height: 1.7)),
          ExerciseShapeToggle(image: def?.image),
          const SizedBox(height: 10),
          for (var i = 0; i < ex.loggedSets.length; i++)
            i < ex.unlockedSetCount
                ? _SetRow(
                    // مهم: المفتاح لازم يتبع "المجموعة نفسها" مش رقم مكانها
                    // في الليستة، عشان لو المستخدم مسح مجموعة من النص
                    // (removeSet) الحقول متتلخبطش وتوري بيانات مجموعة غلط.
                    key: ObjectKey(ex.loggedSets[i]),
                    exIdx: widget.exIdx,
                    setIdx: i,
                  )
                : _lockedSet(),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SButton('+ إضافة مجموعة',
                    kind: BtnKind.ghost,
                    small: true,
                    onPressed: () => sessionCtrl.addSet(widget.exIdx)),
              ),
              if (lastSet != null && lastSet.done) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SButton('🔽 دروب سيت',
                      kind: BtnKind.secondary,
                      small: true,
                      onPressed: () => sessionCtrl.addDropSet(widget.exIdx)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockedSet() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: C.panel2.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: const Row(
        children: [
          Text('🔒', style: TextStyle(fontSize: 14)),
          SizedBox(width: 10),
          Text('خلّص المجموعة اللي قبلها الأول',
              style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

/// صف مجموعة واحدة: وزن (+/-)، عدات، ملاحظة، حاسبة أطباق، زرار تم
class _SetRow extends StatefulWidget {
  final int exIdx;
  final int setIdx;
  const _SetRow({super.key, required this.exIdx, required this.setIdx});

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController wCtrl;
  late TextEditingController rCtrl;
  late TextEditingController nCtrl;
  bool noteOpen = false;

  LoggedSet get _set =>
      sessionCtrl.session!.exercises[widget.exIdx].loggedSets[widget.setIdx];

  @override
  void initState() {
    super.initState();
    wCtrl = TextEditingController(text: _set.weight);
    rCtrl = TextEditingController(text: _set.reps);
    nCtrl = TextEditingController(text: _set.note);
    noteOpen = _set.note.isNotEmpty;
  }

  @override
  void dispose() {
    wCtrl.dispose();
    rCtrl.dispose();
    nCtrl.dispose();
    super.dispose();
  }

  void _nudge(double delta) {
    final v = sessionCtrl.nudgeWeight(widget.exIdx, widget.setIdx, delta);
    wCtrl.text = v;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _set;
    final done = s.done;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: done ? C.good.withOpacity(0.07) : C.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done
              ? C.good.withOpacity(0.5)
              : (s.isDrop ? C.accentDim : C.border),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.isDrop ? C.accentDim : C.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.border),
                ),
                child: Text(s.isDrop ? '🔽' : '${widget.setIdx + 1}',
                    style: const TextStyle(fontSize: 11, color: C.text)),
              ),
              const SizedBox(width: 8),
              _stepBtn('−', () => _nudge(-2.5)),
              SizedBox(
                width: 62,
                child: TextField(
                  controller: wCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: C.text),
                  decoration: const InputDecoration(
                    hintText: 'كجم',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  ),
                  onChanged: (v) => sessionCtrl.updateWeight(
                      widget.exIdx, widget.setIdx, v),
                ),
              ),
              _stepBtn('+', () => _nudge(2.5)),
              const SizedBox(width: 6),
              SizedBox(
                width: 54,
                child: TextField(
                  controller: rCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: C.text),
                  decoration: const InputDecoration(
                    hintText: 'عدات',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  ),
                  onChanged: (v) =>
                      sessionCtrl.updateReps(widget.exIdx, widget.setIdx, v),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Fx.toast('🏋 ${Analytics.platesText(s.weightNum)}',
                      duration: const Duration(seconds: 4));
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('🏋', style: TextStyle(fontSize: 16)),
                ),
              ),
              InkWell(
                onTap: () => setState(() => noteOpen = !noteOpen),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('📝',
                      style: TextStyle(
                          fontSize: 15,
                          color: s.note.isEmpty ? C.muted : C.accent)),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  sessionCtrl.toggleSet(widget.exIdx, widget.setIdx);
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 40,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? C.good : C.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.circle_outlined,
                    color: done ? C.bg : Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          if (noteOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: nCtrl,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(fontSize: 13, color: C.text),
                decoration: const InputDecoration(
                  hintText: 'ملاحظة على المجموعة دي (حسيت بإيه، وجعتك حاجة...)',
                ),
                onChanged: (v) =>
                    sessionCtrl.updateNote(widget.exIdx, widget.setIdx, v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.border),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 17, color: C.text, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
