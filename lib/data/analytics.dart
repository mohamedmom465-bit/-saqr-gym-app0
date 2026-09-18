import 'dart:math';

import 'models.dart';
import 'store.dart';

/// نقطة على أي رسم بياني
class ChartPoint {
  final DateTime date;
  final double value;
  final String reps;
  final bool isPR;
  ChartPoint(this.date, this.value, {this.reps = '', this.isPR = false});
}

class LastPerformance {
  final DateTime date;
  final String weight;
  final String reps;
  final int setsLogged;
  LastPerformance(this.date, this.weight, this.reps, this.setsLogged);
}

class Analytics {
  static GymDB get db => store.db;

  /// استخراج رقم مفيد من نص العدات زي "8-12" أو "10 دقائق"
  static double parseRepsNum(String reps) {
    final nums = RegExp(r'\d+').allMatches(reps).map((m) => m.group(0)!).toList();
    if (nums.isEmpty) return 10;
    if (nums.length >= 2) {
      return (int.parse(nums[0]) + int.parse(nums[1])) / 2;
    }
    return double.parse(nums[0]);
  }

  /// الوقت المتوقع لليوم بالثواني (نفس معادلة نسخة الويب)
  static int estimateDuration(WorkoutDay day) {
    final s = db.settings;
    double total = 0;
    for (final ex in day.exercises) {
      if (ex.cardio && ex.reps.contains('دقيق')) {
        total += parseRepsNum(ex.reps) * 60 * ex.sets;
        continue;
      }
      total += parseRepsNum(ex.reps) * 3 * ex.sets;
      total += ex.rest * max(0, ex.sets - 1);
      if (ex.plates) total += s.transitionSeconds;
    }
    total += (day.exercises.length - 1) * 20;
    return total.round();
  }

  /// آخر أداء متسجل لتمرين معيّن
  static LastPerformance? lastPerformance(String exId, String name) {
    for (final s in db.sessions.reversed) {
      final match = _findLog(s, exId, name);
      if (match != null) {
        final done =
            match.loggedSets.where((x) => x.done && x.hasWeight).toList();
        if (done.isNotEmpty) {
          final top = done.reduce((a, b) => b.weightNum > a.weightNum ? b : a);
          return LastPerformance(s.date, top.weight, top.reps, done.length);
        }
      }
    }
    return null;
  }

  static SessionExercise? _findLog(
      WorkoutSession s, String exId, String name) {
    for (final e in s.exercises) {
      if (e.exerciseId == exId || e.name == name) return e;
    }
    return null;
  }

  /// كل المجموعات المتسجلة آخر مرة — بتستخدم في ملء الجلسة الجديدة تلقائي
  static List<LoggedSet>? lastSessionLoggedSets(String exId, String name) {
    for (final s in db.sessions.reversed) {
      final match = _findLog(s, exId, name);
      if (match != null) {
        final done =
            match.loggedSets.where((x) => x.done && x.hasWeight).toList();
        if (done.isNotEmpty) return done;
      }
    }
    return null;
  }

  /// تاريخ أعلى وزن لكل جلسة لتمرين معيّن
  static List<ChartPoint> exerciseHistory(String exId, String name) {
    final rows = <ChartPoint>[];
    for (final s in db.sessions) {
      final match = _findLog(s, exId, name);
      if (match == null) continue;
      final done = match.loggedSets
          .where((x) => x.done && x.hasWeight && x.weightNum > 0)
          .toList();
      if (done.isEmpty) continue;
      final top = done.reduce((a, b) => b.weightNum > a.weightNum ? b : a);
      rows.add(ChartPoint(s.date, top.weightNum,
          reps: top.reps, isPR: match.isPR));
    }
    return rows;
  }

  /// تقدير الرقم الأقصى بمعادلة Epley
  static int estimate1RM(double weight, String reps) {
    final r = double.tryParse(reps.trim()) ?? 1;
    if (weight <= 0) return 0;
    return (weight * (1 + r / 30)).round();
  }

  /// حجم التمرين = وزن × عدات لكل المجموعات المكتملة
  static int sessionVolume(WorkoutSession s) {
    double total = 0;
    for (final ex in s.exercises) {
      for (final set in ex.loggedSets) {
        if (set.done && set.hasWeight && set.reps.trim().isNotEmpty) {
          total += set.weightNum * set.repsNum;
        }
      }
    }
    return total.round();
  }

  static DateTime weekStart(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day);
    // نفس منطق الويب: الأسبوع بيبدأ يوم الأحد
    return dt.subtract(Duration(days: dt.weekday % 7));
  }

  static List<ChartPoint> weeklyVolume({int weeksBack = 8}) {
    final map = <int, int>{};
    for (final s in db.sessions) {
      final key = weekStart(s.date).millisecondsSinceEpoch;
      map[key] = (map[key] ?? 0) + sessionVolume(s);
    }
    final cursor = weekStart(DateTime.now());
    final rows = <ChartPoint>[];
    for (var i = weeksBack - 1; i >= 0; i--) {
      final wk = cursor.subtract(Duration(days: i * 7));
      rows.add(ChartPoint(
          wk, (map[wk.millisecondsSinceEpoch] ?? 0).toDouble()));
    }
    return rows;
  }

  static List<ChartPoint> sessionDurations({int limit = 10}) {
    final list = db.sessions.length > limit
        ? db.sessions.sublist(db.sessions.length - limit)
        : db.sessions;
    return list
        .map((s) => ChartPoint(s.date, s.durationMinutes.toDouble()))
        .toList();
  }

  static List<ChartPoint> inbodyWeightTrend() {
    final list = db.inbody
        .where((m) => m.weight != null && m.weight! > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list.map((m) => ChartPoint(m.date, m.weight!)).toList();
  }

  /// أيام متتالية فيها تمرين
  static int computeStreak() {
    if (db.sessions.isEmpty) return 0;
    final days = db.sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // لو النهارده لسه ما اتعملش فيه تمرين، نبدأ نعد من إمبارح بدل
    // ما نوقف على طول (عشان الستريك يفضل شغال لحد ما اليوم يخلص).
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// خريطة الانتظام: قائمة من (فيه تمرين؟، في المستقبل؟) بترتيب الأسابيع
  static List<List<bool>> consistencyGrid({int weeks = 8}) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    var start = weekStart(t).subtract(Duration(days: (weeks - 1) * 7));
    final dates = db.sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    final cells = <List<bool>>[];
    for (var i = 0; i < weeks * 7; i++) {
      final d = start.add(Duration(days: i));
      cells.add([dates.contains(d), d.isAfter(t)]);
    }
    return cells;
  }

  /// كشف الأرقام القياسية قبل حفظ الجلسة
  static List<String> detectAndMarkPRs(WorkoutSession session) {
    final newPRs = <String>[];
    for (final ex in session.exercises) {
      final done = ex.loggedSets
          .where((s) => s.done && s.hasWeight && s.weightNum > 0)
          .toList();
      if (done.isEmpty) continue;
      final topWeight =
          done.map((s) => s.weightNum).reduce((a, b) => a > b ? a : b);
      double priorBest = 0;
      for (final s in db.sessions) {
        final match = _findLog(s, ex.exerciseId, ex.name);
        if (match == null) continue;
        final mdone = match.loggedSets
            .where((x) => x.done && x.hasWeight && x.weightNum > 0)
            .toList();
        if (mdone.isEmpty) continue;
        final mtop =
            mdone.map((x) => x.weightNum).reduce((a, b) => a > b ? a : b);
        if (mtop > priorBest) priorBest = mtop;
      }
      if (topWeight > priorBest) {
        ex.isPR = true;
        newPRs.add(ex.name);
      }
    }
    return newPRs;
  }

  static double bestEverWeight(String exId, String name) {
    final hist = exerciseHistory(exId, name);
    if (hist.isEmpty) return 0;
    return hist.map((h) => h.value).reduce((a, b) => a > b ? a : b);
  }

  // ---------- حاسبة الأطباق ----------
  static Map<String, dynamic>? calcPlates(double total, {double? bar}) {
    final b = bar ?? db.settings.barWeight;
    final perSide = (total - b) / 2;
    if (perSide <= 0) return null;
    const denom = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    var remaining = (perSide * 4).round() / 4;
    final used = <double>[];
    for (final p in denom) {
      while (remaining >= p - 0.001) {
        used.add(p);
        remaining -= p;
      }
    }
    return {'used': used, 'leftover': max(0, remaining), 'bar': b};
  }

  static String platesText(double total) {
    final bar = db.settings.barWeight;
    final r = calcPlates(total);
    if (r == null) {
      return 'الوزن ده أقل من أو يساوي وزن البار (${_n(bar)}كجم).';
    }
    final used = (r['used'] as List<double>);
    if (used.isEmpty) return 'بار فاضي بس (${_n(bar)}كجم).';
    var txt =
        'كل جنب: ${used.map(_n).join(' + ')} كجم (بار ${_n(bar)}كجم)';
    final leftover = (r['leftover'] as num).toDouble();
    if (leftover > 0.01) {
      txt +=
          ' — فاضل ${leftover.toStringAsFixed(2)}كجم مش قابلة للتقسيم بالأطباق العادية';
    }
    return txt;
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  // ---------- أرقام التقارير ----------
  static String avgRating(List<WorkoutSession> list) {
    final rated = list.where((s) => s.rating != null).toList();
    if (rated.isEmpty) return '-';
    final sum = rated.fold<int>(0, (a, s) => a + s.rating!);
    return (sum / rated.length).toStringAsFixed(1);
  }

  static Map<String, int> skippedExercises(List<WorkoutSession> last30) {
    final skip = <String, int>{};
    for (final s in last30) {
      for (final ex in s.exercises) {
        final completed = ex.loggedSets
            .where((set) => set.done && set.reps.trim().isNotEmpty)
            .length;
        if (completed < ex.targetSets) {
          skip[ex.name] = (skip[ex.name] ?? 0) + 1;
        }
      }
    }
    return skip;
  }
}
