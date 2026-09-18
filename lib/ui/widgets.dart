import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../services/feedback.dart';
import 'theme.dart';

class SCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  const SCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: borderColor ?? C.border),
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap == null
          ? box
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(kRadius),
              child: box,
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final double topGap;
  const SectionTitle(this.text, {super.key, this.topGap = 20});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: C.text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final bool accent;
  final Color? color;
  const Pill(this.text, {super.key, this.accent = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (accent ? C.accent : C.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? C.accent.withOpacity(0.12) : C.panel2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent ? C.accentDim : C.border),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

enum BtnKind { primary, secondary, ghost, danger, good }

class SButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool small;
  final bool expand;
  const SButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.small = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    Border? border;
    switch (kind) {
      case BtnKind.primary:
        bg = C.accent;
        fg = Colors.white;
        break;
      case BtnKind.secondary:
        bg = C.panel2;
        fg = C.text;
        border = Border.all(color: C.border);
        break;
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = C.muted;
        border = Border.all(color: C.border);
        break;
      case BtnKind.danger:
        bg = C.danger;
        fg = Colors.white;
        break;
      case BtnKind.good:
        bg = C.good;
        fg = C.bg;
        break;
    }
    final child = Container(
      width: expand ? double.infinity : null,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: onPressed == null ? bg.withOpacity(0.4) : bg,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: small ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}

class StatBox extends StatelessWidget {
  final String value;
  final String label;
  final String? unit;
  const StatBox(this.value, this.label, {super.key, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: C.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: C.accent,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: const TextStyle(fontSize: 13, color: C.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: C.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: children,
    );
  }
}

class EmptyBox extends StatelessWidget {
  final String text;
  const EmptyBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: C.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: C.muted, fontSize: 13, height: 1.7),
      ),
    );
  }
}

class ListRow extends StatelessWidget {
  final Widget start;
  final Widget end;
  final bool divider;
  const ListRow({super.key, required this.start, required this.end, this.divider = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.border)))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Flexible(child: start), const SizedBox(width: 8), end],
      ),
    );
  }
}

/// زرار "شكل التمرين" اللي بيفتح الصورة المرجعية
class ExerciseShapeToggle extends StatefulWidget {
  final ImageProvider? image;
  const ExerciseShapeToggle({super.key, this.image});

  @override
  State<ExerciseShapeToggle> createState() => _ExerciseShapeToggleState();
}

class _ExerciseShapeToggleState extends State<ExerciseShapeToggle> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.image == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SButton(
          open ? '🖼 إخفاء شكل التمرين' : '🖼 شكل التمرين',
          kind: BtnKind.secondary,
          small: true,
          expand: false,
          onPressed: () => setState(() => open = !open),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => _openFull(context, widget.image!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: widget.image!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    alignment: Alignment.center,
                    color: C.panel2,
                    child: const Icon(Icons.broken_image_outlined,
                        color: C.muted, size: 28),
                  ),
                ),
              ),
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  void _openFull(BuildContext context, ImageProvider img) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: Image(
                image: img,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Icon(Icons.broken_image_outlined,
                      color: C.muted, size: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// رسم بياني خطي بسيط — نفس شكل الرسم اللي كان متعمل بـ SVG في نسخة الويب
class LineChartView extends StatelessWidget {
  final List<ChartPoint> points;
  final String suffix;
  final double height;
  final String emptyMsg;
  const LineChartView(
    this.points, {
    super.key,
    this.suffix = '',
    this.height = 150,
    this.emptyMsg =
        'محتاج جلستين على الأقل بنفس التمرين عشان نرسم الرسم البياني.',
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2 || points.every((p) => p.value == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(emptyMsg,
            style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.6)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(points, suffix),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<ChartPoint> points;
  final String suffix;
  _LinePainter(this.points, this.suffix);

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 42.0, padR = 10.0, padT = 14.0, padB = 22.0;
    final values = points.map((p) => p.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final stepX = (size.width - padL - padR) / (points.length - 1);

    final axis = Paint()
      ..color = C.border
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(padL, padT), Offset(padL, size.height - padB), axis);
    canvas.drawLine(Offset(padL, size.height - padB),
        Offset(size.width - padR, size.height - padB), axis);

    final pts = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = padL + i * stepX;
      final y = padT +
          (size.height - padT - padB) * (1 - (points[i].value - minV) / range);
      pts.add(Offset(x, y));
    }

    // تدرج تحت الخط
    final fill = Path()..moveTo(pts.first.dx, size.height - padB);
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(pts.last.dx, size.height - padB);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33F2542D), Color(0x00F2542D)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final line = Paint()
      ..color = C.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);

    for (var i = 0; i < pts.length; i++) {
      final pr = points[i].isPR;
      canvas.drawCircle(pts[i], pr ? 5 : 3.2,
          Paint()..color = pr ? C.good : C.accent);
    }

    _label(canvas, '${numStr(maxV)}$suffix', Offset(padL - 6, padT));
    _label(canvas, '${numStr(minV)}$suffix',
        Offset(padL - 6, size.height - padB - 6));
  }

  void _label(Canvas canvas, String text, Offset rightAnchor) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: const TextStyle(fontSize: 9.5, color: C.muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightAnchor.dx - tp.width, rightAnchor.dy));
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}

/// خريطة الانتظام (8 أسابيع × 7 أيام)
class HeatmapView extends StatelessWidget {
  final int weeks;
  const HeatmapView({super.key, this.weeks = 8});

  @override
  Widget build(BuildContext context) {
    final cells = Analytics.consistencyGrid(weeks: weeks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: cells.map((c) {
            final active = c[0], future = c[1];
            return Opacity(
              opacity: future ? 0.3 : 1,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? C.good : C.panel2,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: active ? C.good : C.border),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legendCell(C.good),
            const SizedBox(width: 6),
            const Text('يوم اتعمل فيه تمرين',
                style: TextStyle(fontSize: 11, color: C.muted)),
            const SizedBox(width: 12),
            _legendCell(C.panel2),
            const SizedBox(width: 6),
            const Text('مفيش تمرين',
                style: TextStyle(fontSize: 11, color: C.muted)),
          ],
        ),
      ],
    );
  }

  Widget _legendCell(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color == C.good ? C.good : C.border),
        ),
      );
}

/// شريط التقييم من 1 لـ 10
class RatingScale extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;
  const RatingScale({super.key, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(10, (i) {
        final n = i + 1;
        final sel = value == n;
        return InkWell(
          onTap: () => onChanged(n),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 32,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? C.accent : C.panel2,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: sel ? C.accent : C.border),
            ),
            child: Text('$n',
                style: TextStyle(
                  color: sel ? Colors.white : C.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
          ),
        );
      }),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, color: C.muted)),
      );
}

/// عنوان الشاشة بنفس ستايل الهيدر بتاع نسخة الويب (eyebrow + عنوان)
PreferredSizeWidget saqrAppBar({
  required String eyebrow,
  required String title,
  List<Widget>? actions,
  bool showBack = true,
  Widget? leading,
}) {
  return AppBar(
    automaticallyImplyLeading: showBack,
    leading: leading,
    titleSpacing: 4,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (eyebrow.isNotEmpty)
          Text(eyebrow,
              style: const TextStyle(
                color: C.accent,
                fontSize: 10.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              )),
        Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: C.text)),
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: C.border),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context,
  String message, {
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.panel,
      surfaceTintColor: Colors.transparent,
      content: Text(message,
          style: const TextStyle(fontSize: 14.5, height: 1.7, color: C.text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: const TextStyle(color: C.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: danger ? C.danger : C.accent,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
}) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.panel,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontSize: 15, color: C.text)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: C.text),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء', style: TextStyle(color: C.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('تمام',
              style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
