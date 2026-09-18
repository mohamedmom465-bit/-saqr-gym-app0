import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/session_controller.dart';
import '../data/store.dart';
import '../services/backup.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'day_detail_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final streak = Analytics.computeStreak();
    if (streak >= 3) return '🔥 $streak أيام على التوالي، ماشي زي الوحش يا صقر';
    if (store.db.sessions.isEmpty) return 'يلا نبدأ أول تمرين — النظام جاهز';
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الجد، اختار يومك وابدأ';
    if (h < 18) return 'وقت التمرين — اختار يومك';
    return 'مسا الجد، جهز نفسك وابدأ';
  }

  IconData _dayIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('push')) return Icons.local_fire_department_rounded;
    if (n.contains('pull')) return Icons.radio_button_checked;
    if (n.contains('leg')) return Icons.bolt_rounded;
    return Icons.fitness_center_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, sessionCtrl]),
      builder: (context, _) {
        final streak = Analytics.computeStreak();
        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: '',
            title: 'SAQR TRAINING SYSTEM',
            showBack: false,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Image.asset('assets/brand/profile.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: C.accent,
                          alignment: Alignment.center,
                          child: const Text('ص',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Text(_greeting(),
                  style: const TextStyle(fontSize: 13, color: C.muted)),
              const SizedBox(height: 14),
              if (streak > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      C.accent.withOpacity(0.18),
                      C.panel,
                    ]),
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: C.accentDim),
                  ),
                  child: Column(
                    children: [
                      Text('🔥 $streak',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: C.accent)),
                      const SizedBox(height: 4),
                      const Text('يوم متتالي — كمل كده!',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
              if (sessionCtrl.isActive)
                SCard(
                  borderColor: C.accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SessionScreen(dayId: sessionCtrl.session!.dayId),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('▶ تمرين "${sessionCtrl.session!.dayName}" لسه شغال',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text('دوس هنا عشان تكمل من حيث ما وقفت',
                                style: TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded,
                          color: C.accent, size: 26),
                    ],
                  ),
                ),
              if (store.needsBackupReminder)
                SCard(
                  borderColor: C.accentDim,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                            '🛟 من زمان ما خدتش نسخة احتياطية من بياناتك',
                            style: TextStyle(fontSize: 13, height: 1.6)),
                      ),
                      const SizedBox(width: 10),
                      SButton('مشاركة الآن',
                          small: true,
                          expand: false,
                          onPressed: () => BackupService.share(context)),
                    ],
                  ),
                ),
              ...store.db.days.map((day) => _dayCard(context, day)),
              const SizedBox(height: 10),
              if (store.db.sessions.isNotEmpty)
                Text(
                  'إجمالي الجلسات المسجلة: ${store.db.sessions.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: C.muted),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _dayCard(BuildContext context, WorkoutDay day) {
    WorkoutSession? last;
    for (final s in store.db.sessions.reversed) {
      if (s.dayId == day.id) {
        last = s;
        break;
      }
    }
    final lastStr = last == null ? 'لسه ما اتعملش' : fmtDateShort(last.date);
    return SCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DayDetailScreen(dayId: day.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.accent, Color(0xFFB5330F)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_dayIcon(day.name), color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.name.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text('${day.exercises.length} تمارين · آخر مرة: $lastStr',
                    style: const TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: C.accent, size: 26),
        ],
      ),
    );
  }
}
