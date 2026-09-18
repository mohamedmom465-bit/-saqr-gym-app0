import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'default_program.dart';
import 'models.dart';

const _kDbKey = 'saqr_gym_db_v1';
const _kBackupsKey = 'saqr_gym_backups_v1';
const _kBackupMetaKey = 'saqr_gym_backup_meta_v1';
const _kLastManualBackupKey = 'saqr_gym_last_manual_backup';

String uid(String prefix) {
  final r = Random();
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(99999).toRadixString(36)}';
}

/// المخزن الرئيسي — كل الشاشات بتسمع منه وبيحفظ تلقائي على الجهاز
class GymStore extends ChangeNotifier {
  late GymDB db;
  late SharedPreferences _prefs;
  Directory? _docsDir;
  bool ready = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _docsDir = await getApplicationDocumentsDirectory();
    final raw = _prefs.getString(_kDbKey);
    if (raw == null) {
      db = defaultDB();
      await save();
    } else {
      try {
        db = _migrate(GymDB.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('DB load error: $e');
        db = defaultDB();
        await save();
      }
    }
    ready = true;
    notifyListeners();
  }

  String get photosDirPath => '${_docsDir?.path}/photos';
  String get exerciseImagesDirPath => '${_docsDir?.path}/exercise_images';

  Future<Directory> _ensureDir(String path) async {
    final d = Directory(path);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// لو النسخة القديمة (من ملف HTML مثلًا) ناقصة حاجات، نكملها هنا
  GymDB _migrate(GymDB d) {
    if (d.days.isEmpty) d.days = defaultDays();
    for (final day in d.days) {
      for (final ex in day.exercises) {
        // ربط الصور المرجعية الجاهزة بالتمارين اللي ليها id معروف،
        // من غير ما نلمس صورة رفعها المستخدم أو صورة شالها بنفسه
        if (ex.assetImage == null &&
            ex.filePath == null &&
            !ex.imageRemoved &&
            kExerciseImages.containsKey(ex.id)) {
          ex.assetImage = kExerciseImages[ex.id];
        }
      }
    }
    return d;
  }

  Future<void> save() async {
    try {
      await _prefs.setString(_kDbKey, jsonEncode(db.toJson()));
    } catch (e) {
      debugPrint('DB save error: $e');
    }
    notifyListeners();
    unawaited(_maybeAutoSnapshot());
  }

  /// نفس فكرة النسخ التلقائية في نسخة الويب: لقطة كل يومين، نحتفظ بآخر 3
  Future<void> _maybeAutoSnapshot() async {
    try {
      final metaRaw = _prefs.getString(_kBackupMetaKey);
      final meta = metaRaw == null
          ? <String, dynamic>{}
          : jsonDecode(metaRaw) as Map<String, dynamic>;
      final last = (meta['lastSnapshot'] as num?)?.toInt() ?? 0;
      const twoDays = 2 * 24 * 60 * 60 * 1000;
      if (DateTime.now().millisecondsSinceEpoch - last < twoDays) return;
      final list = _prefs.getStringList(_kBackupsKey) ?? [];
      list.add(jsonEncode({
        'at': DateTime.now().millisecondsSinceEpoch,
        'data': db.toJson(),
      }));
      while (list.length > 3) {
        list.removeAt(0);
      }
      await _prefs.setStringList(_kBackupsKey, list);
      await _prefs.setString(_kBackupMetaKey,
          jsonEncode({'lastSnapshot': DateTime.now().millisecondsSinceEpoch}));
    } catch (e) {
      debugPrint('snapshot error: $e');
    }
  }

  List<Map<String, dynamic>> listAutoBackups() {
    final list = _prefs.getStringList(_kBackupsKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i++) {
      try {
        final m = jsonDecode(list[i]) as Map<String, dynamic>;
        out.add({'index': i, 'at': (m['at'] as num).toInt(), 'data': m['data']});
      } catch (_) {}
    }
    return out;
  }

  Future<void> restoreAutoBackup(int index) async {
    final list = _prefs.getStringList(_kBackupsKey) ?? [];
    if (index < 0 || index >= list.length) return;
    final m = jsonDecode(list[index]) as Map<String, dynamic>;
    db = _migrate(GymDB.fromJson(Map<String, dynamic>.from(m['data'])));
    await save();
  }

  int get lastManualBackupAt => _prefs.getInt(_kLastManualBackupKey) ?? 0;

  Future<void> markManualBackup() async {
    await _prefs.setInt(
        _kLastManualBackupKey, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  bool get needsBackupReminder {
    if (db.sessions.length < 3) return false;
    return DateTime.now().millisecondsSinceEpoch - lastManualBackupAt >
        7 * 24 * 60 * 60 * 1000;
  }

  /// ملف نسخة احتياطية كامل (الصور جوه الملف base64 عشان ينفع يترجع على أي جهاز)
  Future<File> buildBackupFile() async {
    final map = db.toJson();
    final photosOut = <Map<String, dynamic>>[];
    for (final p in db.photos) {
      final f = File(p.path);
      String? data;
      if (await f.exists()) {
        data = base64Encode(await f.readAsBytes());
      }
      photosOut.add({'id': p.id, 'date': p.date.toIso8601String(), 'data': data});
    }
    map['photosEmbedded'] = photosOut;

    // صور التمارين اللي رفعها المستخدم بنفسه كمان بتتحط جوه الملف
    final exImages = <String, String>{};
    for (final day in db.days) {
      for (final ex in day.exercises) {
        if (ex.filePath != null) {
          final f = File(ex.filePath!);
          if (await f.exists()) {
            exImages[ex.id] = base64Encode(await f.readAsBytes());
          }
        }
      }
    }
    map['exerciseImagesEmbedded'] = exImages;

    final dir = await getTemporaryDirectory();
    final name =
        'saqr-gym-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    return file;
  }

  /// استيراد نسخة احتياطية (بتشتغل مع ملفات نسخة الويب القديمة كمان)
  Future<bool> importBackup(File file) async {
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (map['days'] is! List) return false;
      final imported = GymDB.fromJson(map);

      // صور التقدم
      final embedded = map['photosEmbedded'];
      if (embedded is List) {
        final dir = await _ensureDir(photosDirPath);
        imported.photos = [];
        for (final e in embedded) {
          final m = Map<String, dynamic>.from(e);
          if (m['data'] == null) continue;
          final f = File('${dir.path}/${m['id']}.jpg');
          await f.writeAsBytes(base64Decode(m['data'] as String));
          imported.photos.add(ProgressPhoto(
            id: m['id'].toString(),
            date: DateTime.tryParse(m['date']?.toString() ?? '') ??
                DateTime.now(),
            path: f.path,
          ));
        }
      } else if (map['photos'] is List) {
        // ملف قديم من نسخة الويب: الصور جوه حقل image كـ base64
        final dir = await _ensureDir(photosDirPath);
        imported.photos = [];
        for (final e in (map['photos'] as List)) {
          final m = Map<String, dynamic>.from(e);
          final img = m['image']?.toString();
          if (img == null || !img.contains('base64,')) continue;
          final f = File('${dir.path}/${m['id']}.jpg');
          await f.writeAsBytes(base64Decode(img.split('base64,').last));
          imported.photos.add(ProgressPhoto(
            id: m['id'].toString(),
            date: DateTime.tryParse(m['date']?.toString() ?? '') ??
                DateTime.now(),
            path: f.path,
          ));
        }
      }

      // صور التمارين
      final exDir = await _ensureDir(exerciseImagesDirPath);
      final exEmbedded = map['exerciseImagesEmbedded'];
      if (exEmbedded is Map) {
        for (final day in imported.days) {
          for (final ex in day.exercises) {
            final data = exEmbedded[ex.id];
            if (data is String) {
              final f = File('${exDir.path}/${ex.id}.jpg');
              await f.writeAsBytes(base64Decode(data));
              ex.filePath = f.path;
            } else {
              ex.filePath = null;
            }
          }
        }
      } else {
        // ملف نسخة الويب: الصور جوه حقل image لكل تمرين
        final rawDays = (map['days'] as List);
        for (var di = 0; di < imported.days.length && di < rawDays.length; di++) {
          final rawExs =
              (Map<String, dynamic>.from(rawDays[di])['exercises'] as List?) ??
                  [];
          for (var ei = 0;
              ei < imported.days[di].exercises.length && ei < rawExs.length;
              ei++) {
            final img =
                Map<String, dynamic>.from(rawExs[ei])['image']?.toString();
            final ex = imported.days[di].exercises[ei];
            if (img != null && img.contains('base64,')) {
              final f = File('${exDir.path}/${ex.id}.jpg');
              await f.writeAsBytes(base64Decode(img.split('base64,').last));
              ex.filePath = f.path;
            } else {
              ex.filePath = null;
              if (img == null) ex.imageRemoved = false;
            }
          }
        }
      }

      db = _migrate(imported);
      await save();
      return true;
    } catch (e) {
      debugPrint('import error: $e');
      return false;
    }
  }

  Future<void> resetAll() async {
    db = defaultDB();
    await save();
  }

  // ---------- تعديل البرنامج ----------
  Future<void> renameDay(String dayId, String name) async {
    db.days.firstWhere((d) => d.id == dayId).name = name;
    await save();
  }

  Future<WorkoutDay?> deleteDay(String dayId) async {
    final idx = db.days.indexWhere((d) => d.id == dayId);
    if (idx == -1) return null;
    final removed = db.days.removeAt(idx);
    await save();
    return removed;
  }

  Future<void> restoreDay(int index, WorkoutDay day) async {
    db.days.insert(index.clamp(0, db.days.length), day);
    await save();
  }

  int dayIndex(String dayId) => db.days.indexWhere((d) => d.id == dayId);

  Future<void> addDay(String name) async {
    db.days.add(WorkoutDay(id: uid('d'), name: name));
    await save();
  }

  Future<void> addExercise(String dayId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    day.exercises.add(ExerciseDef(
        id: uid('e'), name: 'تمرين جديد', sets: 3, reps: '10', rest: 60));
    await save();
  }

  Future<ExerciseDef?> deleteExercise(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final idx = day.exercises.indexWhere((e) => e.id == exId);
    if (idx == -1) return null;
    final removed = day.exercises.removeAt(idx);
    await save();
    return removed;
  }

  Future<void> restoreExercise(String dayId, int index, ExerciseDef ex) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    day.exercises.insert(index.clamp(0, day.exercises.length), ex);
    await save();
  }

  int exerciseIndex(String dayId, String exId) =>
      db.days.firstWhere((d) => d.id == dayId).exercises
          .indexWhere((e) => e.id == exId);

  Future<void> reorderExercise(String dayId, int oldIndex, int newIndex) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    if (newIndex > oldIndex) newIndex -= 1;
    final ex = day.exercises.removeAt(oldIndex);
    day.exercises.insert(newIndex.clamp(0, day.exercises.length), ex);
    await save();
  }

  ExerciseDef? findExercise(String exId) {
    for (final d in db.days) {
      for (final e in d.exercises) {
        if (e.id == exId) return e;
      }
    }
    return null;
  }

  WorkoutDay? dayOfExercise(String exId) {
    for (final d in db.days) {
      if (d.exercises.any((e) => e.id == exId)) return d;
    }
    return null;
  }

  /// صورة التمرين بتتقرأ من البرنامج الحالي عشان أي تعديل يبان فورًا
  ExerciseDef? defOf(String exId) => findExercise(exId);

  Future<void> setExerciseImageFile(
      String dayId, String exId, File picked) async {
    final dir = await _ensureDir(exerciseImagesDirPath);
    final dest = File('${dir.path}/${exId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await dest.writeAsBytes(await picked.readAsBytes());
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    // امسح الصورة القديمة اللي المستخدم كان رافعها
    if (ex.filePath != null) {
      final old = File(ex.filePath!);
      if (await old.exists()) await old.delete();
    }
    ex.filePath = dest.path;
    ex.imageRemoved = false;
    await save();
  }

  Future<void> removeExerciseImage(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    if (ex.filePath != null) {
      final old = File(ex.filePath!);
      if (await old.exists()) await old.delete();
      ex.filePath = null;
    }
    ex.imageRemoved = true;
    await save();
  }

  Future<void> restoreDefaultExerciseImage(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    ex.imageRemoved = false;
    ex.assetImage = kExerciseImages[ex.id];
    await save();
  }

  // ---------- InBody ----------
  Future<void> addInbody(InBodyEntry e) async {
    db.inbody.add(e);
    await save();
  }

  Future<InBodyEntry?> deleteInbody(String id) async {
    final idx = db.inbody.indexWhere((e) => e.id == id);
    if (idx == -1) return null;
    final removed = db.inbody.removeAt(idx);
    await save();
    return removed;
  }

  // ---------- صور التقدم ----------
  Future<void> addProgressPhoto(File picked) async {
    final dir = await _ensureDir(photosDirPath);
    final id = uid('ph');
    final dest = File('${dir.path}/$id.jpg');
    await dest.writeAsBytes(await picked.readAsBytes());
    db.photos.add(ProgressPhoto(id: id, date: DateTime.now(), path: dest.path));
    await save();
  }

  Future<void> deletePhoto(String id) async {
    final idx = db.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = db.photos.removeAt(idx);
    final f = File(p.path);
    if (await f.exists()) await f.delete();
    await save();
  }

  // ---------- الجلسات ----------
  Future<void> addSession(WorkoutSession s) async {
    db.sessions.add(s);
    await save();
  }

  Future<void> deleteSession(String id) async {
    db.sessions.removeWhere((s) => s.id == id);
    await save();
  }
}

final store = GymStore();
