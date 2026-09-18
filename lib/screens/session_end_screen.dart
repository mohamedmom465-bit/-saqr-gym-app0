import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/session_controller.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SessionEndScreen extends StatefulWidget {
  const SessionEndScreen({super.key});

  @override
  State<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends State<SessionEndScreen> {
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    notesCtrl.text = sessionCtrl.session?.notes ?? '';
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = sessionCtrl.session;
    if (s == null) return;
    if (s.rating == null) {
      final ok = await confirmDialog(
          context, 'ما اخترتش تقييم، تحفظ من غير تقييم؟');
      if (!ok) return;
    }
    s.notes = notesCtrl.text;
    final prs = await sessionCtrl.save();
    if (!mounted) return;
    if (prs.isNotEmpty) {
      Fx.celebrateVibe();
      Fx.toast('🏆 رقم قياسي جديد في: ${prs.join('، ')}!',
          duration: const Duration(milliseconds: 4200));
    } else {
      Fx.setDoneVibe();
      Fx.toast('✅ اتحفظ التمرين');
    }
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionCtrl,
      builder: (context, _) {
        final s = sessionCtrl.session;
        if (s == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final volume = Analytics.sessionVolume(s);
        final doneSets = s.exercises
            .expand((e) => e.loggedSets)
            .where((x) => x.done)
            .length;

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: s.dayName.toUpperCase(),
            title: 'تقييم التمرين',
            showBack: false,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              StatGrid([
                StatBox('${s.durationMinutes}', 'دقيقة مدة التمرين'),
                StatBox('$doneSets', 'مجموعة اتكملت'),
                StatBox('$volume', 'حجم التمرين', unit: 'كجم'),
                StatBox('${s.exercises.length}', 'تمارين اليوم'),
              ]),
              const SectionTitle('تقييمك العام للتمرين ده (من 1 لـ 10)'),
              SCard(
                child: RatingScale(
                  value: s.rating,
                  onChanged: (n) {
                    s.rating = n;
                    setState(() {});
                  },
                ),
              ),
              const SectionTitle('تقييم كل تمرين لوحده (اختياري)'),
              ...s.exercises.map((ex) => SCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        RatingScale(
                          value: s.exerciseRatings[ex.exerciseId],
                          onChanged: (n) {
                            s.exerciseRatings[ex.exerciseId] = n;
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  )),
              const SectionTitle('ملاحظات (اختياري)'),
              SCard(
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: C.text),
                  decoration: const InputDecoration(
                      hintText: 'أي حاجة حصلت النهاردة تحب تفتكرها...'),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SButton('💾  حفظ التمرين',
                  kind: BtnKind.good, onPressed: _save),
            ),
          ),
        );
      },
    );
  }
}
