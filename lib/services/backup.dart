import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'feedback.dart';

class BackupService {
  /// مشاركة نسخة احتياطية (درايف / واتساب / ملفات)
  static Future<void> share(BuildContext context) async {
    try {
      final file = await store.buildBackupFile();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية - نظام صقر',
        text: 'نسخة احتياطية من تطبيق SAQR GYM',
      );
      await store.markManualBackup();
      Fx.toast('✅ اتشاركت النسخة الاحتياطية');
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نشارك الملف: $e', duration: const Duration(seconds: 4));
    }
  }

  /// حفظ نسخة في فولدر التنزيلات/المستندات على الجهاز
  static Future<void> saveToDevice(BuildContext context) async {
    try {
      final file = await store.buildBackupFile();
      Directory? target;
      if (Platform.isAndroid) {
        const downloads = '/storage/emulated/0/Download';
        if (await Directory(downloads).exists()) {
          target = Directory(downloads);
        }
      }
      target ??= await getApplicationDocumentsDirectory();
      final dest = File('${target.path}/${file.uri.pathSegments.last}');
      await dest.writeAsBytes(await file.readAsBytes());
      await store.markManualBackup();
      Fx.toast('✅ اتحفظت النسخة هنا:\n${dest.path}',
          duration: const Duration(seconds: 5));
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نحفظ الملف، جرب "مشاركة" بدلها');
    }
  }

  /// استيراد نسخة احتياطية: افتح ملف الـ JSON بأي مدير ملفات أو تطبيق نصوص،
  /// انسخ كل المحتوى، والصقه هنا. بيشتغل مع ملفات نسخة الويب القديمة كمان.
  static Future<void> import(BuildContext context) async {
    final controller = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        surfaceTintColor: Colors.transparent,
        title: const Text('استيراد نسخة احتياطية',
            style: TextStyle(fontSize: 15, color: C.text)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'افتح ملف النسخة الاحتياطية (JSON) بأي مدير ملفات أو محرر نصوص، '
                'انسخ كل المحتوى، والصقه هنا:',
                style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.7),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 8,
                style: const TextStyle(fontSize: 12, color: C.text),
                decoration: const InputDecoration(
                    hintText: '{ "days": [...], "sessions": [...] }'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('استيراد',
                style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (pasted == null || pasted.trim().isEmpty) return;
    if (!context.mounted) return;

    final ok = await confirmDialog(
      context,
      'هيتم استبدال كل البيانات الحالية بالنسخة اللي هتستوردها. متأكد؟',
      danger: true,
    );
    if (!ok) return;

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/imported_backup.json');
      await file.writeAsString(pasted);
      final done = await store.importBackup(file);
      Fx.toast(done
          ? '✅ اتستوردت النسخة الاحتياطية بنجاح'
          : '⚠️ الملف مش نسخة احتياطية صحيحة');
    } catch (e) {
      Fx.toast('⚠️ حصلت مشكلة وإحنا بنقرأ النص');
    }
  }
}
