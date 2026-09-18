import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'session_detail_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sessions = store.db.sessions;
        if (sessions.isEmpty) {
          return Scaffold(
            appBar: saqrAppBar(
                eyebrow: 'PROGRESS', title: 'التقارير', showBack: false),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyBox(
                  'لسه معملتش أي تمرين مسجل.\nابدأ تمرين من الرئيسية وهيبدأ التقرير يظهر هنا.'),
            ),
          );
        }

        final now = DateTime.now();
        final last7 = sessions
            .where((s) => now.difference(s.date).inDays <= 7)
            .toList();
        final last30 = sessions
            .where((s) => now.difference(s.date).inDays <= 30)
            .toList();

        final weeklyVol = Analytics.weeklyVolume(weeksBack: 8);
        final thisWeek = weeklyVol.last.value;
        final lastWeek = weeklyVol[weeklyVol.length - 2].value;
        String trendText = '';
        Color trendColor = C.muted;
        if (lastWeek > 0) {
          final pct = (((thisWeek - lastWeek) / lastWeek) * 100).round();
          trendText = pct >= 0
              ? '▲ $pct% عن الأسبوع اللي فات'
              : '▼ ${pct.abs()}% عن الأسبوع اللي فات';
          trendColor = pct >= 0 ? C.good : C.danger;
        }

        final durations = Analytics.sessionDurations(limit: 10);
        final avgDuration = durations.isEmpty
            ? 0
            : (durations.fold<double>(0, (a, d) => a + d.value) /
                    durations.length)
                .round();

        final weightTrend = Analytics.inbodyWeightTrend();

        final mainExercises = <ExerciseDef>[];
        for (final d in store.db.days) {
          for (final ex in d.exercises) {
            if (ex.isMain) mainExercises.add(ex);
          }
        }

        final byDay = <String, int>{};
        for (final s in last30) {
          byDay[s.dayName] = (byDay[s.dayName] ?? 0) + 1;
        }

        final skipEntries = Analytics.skippedExercises(last30).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: saqrAppBar(
              eyebrow: 'PROGRESS', title: 'التقارير', showBack: false),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              StatGrid([
                StatBox('${Analytics.computeStreak()}', '🔥 يوم متتالي'),
                StatBox('${last30.length}', 'أيام تمرين (شهر)'),
                StatBox(Analytics.avgRating(last7), 'متوسط التقييم (أسبوع)'),
                StatBox(Analytics.avgRating(last30), 'متوسط التقييم (شهر)'),
              ]),

              const SectionTitle('📈 حجم التمرين أسبوعيًا (وزن × عدات × مجموعات)'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('هالأسبوع: ${numStr(thisWeek)}كجم',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (trendText.isNotEmpty)
                          Text(trendText,
                              style:
                                  TextStyle(fontSize: 12, color: trendColor)),
                      ],
                    ),
                    LineChartView(weeklyVol,
                        suffix: 'كجم',
                        emptyMsg:
                            'كمّل تمرين أسبوعين متتاليين على الأقل عشان الرسم يبان.'),
                  ],
                ),
              ),

              const SectionTitle('🗓 انتظامك (آخر 8 أسابيع)'),
              const SCard(child: HeatmapView()),

              SectionTitle('⏱ مدة التمرين (آخر ${durations.length} جلسات)'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المتوسط: $avgDuration دقيقة',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    LineChartView(durations,
                        suffix: 'د',
                        height: 110,
                        emptyMsg: 'محتاج جلستين على الأقل عشان الرسم يبان.'),
                  ],
                ),
              ),

              const SectionTitle('🧬 وزن الجسم (InBody) بمرور الوقت'),
              SCard(
                child: weightTrend.length < 2
                    ? const Text(
                        'سجّل قياسين InBody على الأقل من صفحة "InBody" عشان الرسم يبان هنا جنب حجم التمرين.',
                        style: TextStyle(
                            fontSize: 12.5, color: C.muted, height: 1.7))
                    : LineChartView(weightTrend, suffix: 'كجم'),
              ),

              const SectionTitle('🏆 تقدير الـ 1RM للتمارين الأساسية'),
              SCard(
                child: mainExercises.isEmpty
                    ? const Text(
                        'مفيش تمارين متعلّمة "أساسي" لسه. تقدر تعلّم أي تمرين من صفحة التعديل عشان يظهر رقمه الأقصى هنا.',
                        style: TextStyle(
                            fontSize: 12.5, color: C.muted, height: 1.7))
                    : Column(
                        children: [
                          for (var i = 0; i < mainExercises.length; i++)
                            _oneRmRow(mainExercises[i],
                                divider: i != mainExercises.length - 1),
                        ],
                      ),
              ),

              const SectionTitle('عدد مرات كل يوم تدريب (آخر 30 يوم)'),
              SCard(
                child: Column(
                  children: [
                    for (var i = 0; i < store.db.days.length; i++)
                      ListRow(
                        divider: i != store.db.days.length - 1,
                        start: Text(store.db.days[i].name,
                            style: const TextStyle(fontSize: 13.5)),
                        end: Pill('${byDay[store.db.days[i].name] ?? 0} مرة'),
                      ),
                  ],
                ),
              ),

              const SectionTitle('تمارين ناقصة أو متجاهلة (آخر 30 يوم)'),
              SCard(
                child: skipEntries.isEmpty
                    ? const Text('مفيش تمارين ناقصة، تمام كده!',
                        style: TextStyle(fontSize: 12.5, color: C.muted))
                    : Column(
                        children: [
                          for (var i = 0;
                              i < skipEntries.length && i < 6;
                              i++)
                            ListRow(
                              divider: i != skipEntries.length - 1 && i != 5,
                              start: Text(skipEntries[i].key,
                                  style: const TextStyle(fontSize: 13)),
                              end: Pill('${skipEntries[i].value} مرة ناقص',
                                  color: C.danger),
                            ),
                        ],
                      ),
              ),

              const SectionTitle('آخر التمارين'),
              ...sessions.reversed.take(10).map((s) => SCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(sessionId: s.id)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${s.dayName} · ${fmtDateShort(s.date)}',
                                  style: const TextStyle(fontSize: 13.5)),
                              const SizedBox(height: 3),
                              Text(
                                '${s.durationMinutes} دقيقة · ${Analytics.sessionVolume(s)}كجم حجم',
                                style: const TextStyle(
                                    fontSize: 11.5, color: C.muted),
                              ),
                            ],
                          ),
                        ),
                        Pill(s.rating != null ? '${s.rating}/10' : '-',
                            accent: true),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _oneRmRow(ExerciseDef ex, {required bool divider}) {
    final hist = Analytics.exerciseHistory(ex.id, ex.name);
    final rms =
        hist.map((h) => Analytics.estimate1RM(h.value, h.reps)).toList();
    final current = rms.isEmpty ? null : rms.last;
    final prev = rms.length > 1 ? rms[rms.length - 2] : null;
    String arrow = '';
    Color arrowColor = C.muted;
    if (current != null && prev != null) {
      if (current > prev) {
        arrow = ' ▲';
        arrowColor = C.good;
      } else if (current < prev) {
        arrow = ' ▼';
        arrowColor = C.danger;
      }
    }
    return ListRow(
      divider: divider,
      start: Text(ex.name, style: const TextStyle(fontSize: 13)),
      end: Row(
        children: [
          Pill(current != null ? '${current}كجم' : 'لسه مفيش بيانات',
              accent: current != null),
          if (arrow.isNotEmpty)
            Text(arrow, style: TextStyle(color: arrowColor, fontSize: 13)),
        ],
      ),
    );
  }
}
