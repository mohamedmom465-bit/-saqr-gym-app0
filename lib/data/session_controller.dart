import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/feedback.dart';
import 'analytics.dart';
import 'models.dart';
import 'store.dart';

/// بيدير الجلسة الشغالة: التايمرات، فتح التمارين تدريجيًا، الدروب سيت... إلخ
class SessionController extends ChangeNotifier {
  WorkoutSession? session;

  Timer? _workTimer;
  Timer? _restTimer;
  Timer? _waterTimer;

  /// ثواني التمرين الكلي — منفصلة عشان الساعة بس هي اللي تتحدث كل ثانية
  final ValueNotifier<int> workSeconds = ValueNotifier(0);

  /// ثواني الراحة المتبقية (null = مفيش راحة شغالة)
  final ValueNotifier<int?> restLeft = ValueNotifier(null);
  int restTotal = 0;

  bool get isActive => session != null;

  // ---------- بدء الجلسة ----------
  void start(WorkoutDay day) {
    final settings = store.db.settings;
    final exercises = <SessionExercise>[];

    for (final ex in day.exercises) {
      final prevSets = Analytics.lastSessionLoggedSets(ex.id, ex.name);
      final fullyCompleted = prevSets != null && prevSets.length >= ex.sets;
      final autoBump = fullyCompleted && settings.autoProgress;

      final logged = List.generate(ex.sets, (i) {
        LoggedSet? prev;
        if (prevSets != null && prevSets.isNotEmpty) {
          prev = i < prevSets.length ? prevSets[i] : prevSets.last;
        }
        var w = prev?.weight ?? '';
        if (prev != null && autoBump) {
          final v = prev.weightNum + 2.5;
          w = v == v.roundToDouble() ? v.round().toString() : v.toString();
        }
        return LoggedSet(weight: w, reps: prev?.reps ?? '');
      });

      exercises.add(SessionExercise(
        exerciseId: ex.id,
        name: ex.name,
        targetSets: ex.sets,
        targetReps: ex.reps,
        rest: ex.rest,
        core: ex.core,
        cardio: ex.cardio,
        noRestAfter: ex.noRestAfter,
        prefilled: prevSets != null,
        autoBumped: autoBump,
        loggedSets: logged,
      ));
    }

    session = WorkoutSession(
      id: uid('s'),
      dayId: day.id,
      dayName: day.name,
      date: DateTime.now(),
      startedAt: DateTime.now().millisecondsSinceEpoch,
      exercises: exercises,
    );

    _startWorkTimer();
    _startWaterReminder();
    Fx.keepScreenOn(true);
    notifyListeners();
  }

  void _startWorkTimer() {
    _workTimer?.cancel();
    workSeconds.value = 0;
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (session == null) return;
      workSeconds.value =
          ((DateTime.now().millisecondsSinceEpoch - session!.startedAt) / 1000)
              .round();
    });
  }

  void _startWaterReminder() {
    _waterTimer?.cancel();
    final mins = max(1, store.db.settings.waterIntervalMin);
    _waterTimer = Timer.periodic(Duration(minutes: mins), (_) {
      if (session != null) {
        Fx.notify('💧 وقت شرب المية!', 'خد شوية ميه وكمل تمرينك');
      }
    });
  }

  // ---------- المجموعات ----------
  void updateWeight(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].weight = value;
  }

  void updateReps(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].reps = value;
  }

  void updateNote(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].note = value;
  }

  /// زرار + / − بيزود أو ينقص 2.5 كجم
  String nudgeWeight(int exIdx, int setIdx, double delta) {
    final set = session!.exercises[exIdx].loggedSets[setIdx];
    var w = (set.weightNum + delta);
    if (w < 0) w = 0;
    w = (w * 100).round() / 100;
    set.weight = w == w.roundToDouble() ? w.round().toString() : w.toString();
    Fx.tapVibe();
    return set.weight;
  }

  void addSet(int exIdx) {
    final ex = session!.exercises[exIdx];
    ex.loggedSets.add(LoggedSet());
    ex.unlockedSetCount = max(ex.unlockedSetCount, ex.loggedSets.length);
    notifyListeners();
  }

  void removeSet(int exIdx, int setIdx) {
    final ex = session!.exercises[exIdx];
    if (ex.loggedSets.length <= 1) return;
    ex.loggedSets.removeAt(setIdx);
    ex.unlockedSetCount = min(ex.unlockedSetCount, ex.loggedSets.length);
    notifyListeners();
  }

  /// دروب سيت: وزن أخف ~20% وكمل على طول من غير راحة
  void addDropSet(int exIdx) {
    final ex = session!.exercises[exIdx];
    final lastSet = ex.loggedSets.last;
    final lastWeight = lastSet.weightNum;
    var dropWeight = '';
    if (lastWeight > 0) {
      var d = ((lastWeight * 0.8) / 1.25).round() * 1.25;
      if (d >= lastWeight) d = max(0, lastWeight - 2.5);
      dropWeight = d == d.roundToDouble() ? d.round().toString() : d.toString();
    }
    ex.loggedSets.add(LoggedSet(weight: dropWeight, isDrop: true));
    ex.unlockedSetCount = ex.loggedSets.length;
    _cancelRest();
    Fx.setDoneVibe();
    Fx.toast(
      '🔽 دروب سيت! نزّل الوزن لـ${dropWeight.isEmpty ? 'وزن أخف' : dropWeight}كجم وكمل على طول من غير راحة',
      duration: const Duration(milliseconds: 2800),
    );
    notifyListeners();
  }

  /// تبديل اسم التمرين للجلسة دي بس
  void swapExercise(int exIdx, String newName) {
    final ex = session!.exercises[exIdx];
    ex.name = newName;
    ex.swapped = true;
    notifyListeners();
  }

  void toggleSet(int exIdx, int setIdx) {
    final ex = session!.exercises[exIdx];
    final set = ex.loggedSets[setIdx];
    set.done = !set.done;

    if (!set.done) {
      notifyListeners();
      return;
    }

    Fx.setDoneVibe();

    // احتفال بالرقم القياسي وسط التمرين
    final bestBefore = Analytics.bestEverWeight(ex.exerciseId, ex.name);
    final w = set.weightNum;
    if (w > 0 && w > bestBefore) {
      Fx.celebrateVibe();
      Fx.toast('🏆 رقم قياسي جديد في "${ex.name}"! ${set.weight}كجم',
          duration: const Duration(milliseconds: 2600));
    }

    // فتح تدريجي ثابت: اللي اتفتح ما بيتقفلش تاني
    ex.unlockedSetCount = max(ex.unlockedSetCount, setIdx + 2);
    final allDone = ex.loggedSets.every((s) => s.done);
    if (allDone) {
      Fx.toast('💥 خلصت "${ex.name}"! كمل كده',
          duration: const Duration(milliseconds: 1800));
      session!.unlockedExerciseCount =
          max(session!.unlockedExerciseCount, exIdx + 2);
    }

    final isLastSetOfEx = setIdx == ex.loggedSets.length - 1;
    final isLastEx = exIdx == session!.exercises.length - 1;
    final skipForSuperset = isLastSetOfEx && ex.noRestAfter && !isLastEx;

    if (!(isLastSetOfEx && isLastEx) && !skipForSuperset && ex.rest > 0) {
      startRest(ex.rest);
    }
    notifyListeners();
  }

  // ---------- تايمر الراحة ----------
  void startRest(int seconds) {
    _restTimer?.cancel();
    restTotal = seconds;
    restLeft.value = seconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (restLeft.value ?? 0) - 1;
      restLeft.value = left;
      if (left <= 0) {
        t.cancel();
        restLeft.value = null;
        Fx.beep();
        Fx.restEndVibe();
        Fx.notify('⏱ خلصت الراحة', 'ابدأ المجموعة الجاية!');
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void addRest(int seconds) {
    if (restLeft.value == null) return;
    restLeft.value = max(1, (restLeft.value ?? 0) + seconds);
  }

  void skipRest() => _cancelRest();

  void _cancelRest() {
    _restTimer?.cancel();
    restLeft.value = null;
    notifyListeners();
  }

  // ---------- إنهاء ----------
  void finish() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    restLeft.value = null;
    session?.endedAt = DateTime.now().millisecondsSinceEpoch;
    Fx.keepScreenOn(false);
    notifyListeners();
  }

  /// حفظ الجلسة + كشف الأرقام القياسية
  Future<List<String>> save() async {
    final s = session!;
    final prs = Analytics.detectAndMarkPRs(s);
    await store.addSession(s);
    session = null;
    notifyListeners();
    return prs;
  }

  void abandon() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    restLeft.value = null;
    session = null;
    Fx.keepScreenOn(false);
    notifyListeners();
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}

final sessionCtrl = SessionController();
