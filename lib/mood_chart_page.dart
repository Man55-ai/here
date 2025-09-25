// lib/mood_chart_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'mood_service.dart';

class MoodChartPage extends StatefulWidget {
  const MoodChartPage({super.key});
  @override
  State<MoodChartPage> createState() => _MoodChartPageState();
}

class _MoodChartPageState extends State<MoodChartPage> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<MoodEntry> _points = [];

  // สำหรับบันทึกย้อนหลัง
  DateTime _editDate = DateTime.now();
  int _editMood = 3;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _load();
    _channel = MoodService.subscribeMyMoodHistory(() {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await MoodService.fetchByMonth(_month.year, _month.month);
      if (!mounted) return;
      setState(() => _points = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'เลือกเดือน',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  Future<void> _pickEditDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _editDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: now, // ไม่ให้เลือกอนาคต
      helpText: 'เลือกวันที่ต้องการบันทึก/แก้ไขอารมณ์',
    );
    if (picked != null) setState(() => _editDate = picked);
  }

  Future<void> _saveEdit() async {
    await MoodService.upsertForDate(_editDate, _editMood);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกอารมณ์เรียบร้อย')),
    );
    if (_editDate.year == _month.year && _editDate.month == _month.month) {
      _load();
    }
  }

  String _thMonthYear(DateTime d) {
    const th = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${th[d.month - 1]} ${d.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('กราฟสถิติย้อนหลัง')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('เลือกเดือน'),
              subtitle: Text(_thMonthYear(_month)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: _pickMonth,
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายเดือน • ${_thMonthYear(_month)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text('โหลดข้อมูลไม่สำเร็จ: $_error',
                      style: TextStyle(color: cs.error))
                else if (_points.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('เดือนนี้ยังไม่มีข้อมูลอารมณ์'),
                  )
                else
                  _SimpleLineChart(points: _points),
                const SizedBox(height: 8),
                const Text('สเกลอารมณ์: 1 (แย่) … 6 (ดีมาก)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('บันทึก/แก้ไขอารมณ์ย้อนหลัง',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_calendar_outlined),
                  title: const Text('วันที่'),
                  subtitle: Text(
                    '${_editDate.year}-${_editDate.month.toString().padLeft(2, '0')}-${_editDate.day.toString().padLeft(2, '0')}',
                  ),
                  onTap: _pickEditDate,
                ),
                const SizedBox(height: 8),
                Text('อารมณ์ (1–6): ${_editMood}'),
                Slider(
                  min: 1,
                  max: 6,
                  divisions: 5,
                  value: _editMood.toDouble(),
                  label: '$_editMood',
                  onChanged: (v) => setState(() => _editMood = v.round()),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saveEdit,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'เนื้อหานี้ไม่ใช่คำแนะนำทางการแพทย์ หากมีความเสี่ยงต่อความปลอดภัย โปรดติดต่อผู้เชี่ยวชาญหรือสายด่วนใกล้คุณ',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }
}

/// การ์ดเรียบ ๆ
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

/// กราฟไลน์ง่าย ๆ (ไม่ใช้แพ็กเกจ)
class _SimpleLineChart extends StatelessWidget {
  final List<MoodEntry> points;
  const _SimpleLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final ds = points
        .map((e) => Offset(e.date.day.toDouble(), e.mood.toDouble()))
        .toList()
      ..sort((a, b) => a.dx.compareTo(b.dx));

    return SizedBox(
      height: 180,
      child: CustomPaint(painter: _LinePainter(ds)),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<Offset> pts;
  _LinePainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;

    final minX = pts.first.dx, maxX = pts.last.dx;
    const minY = 1.0, maxY = 6.0;
    const pad = 16.0;
    final w = size.width - pad * 2, h = size.height - pad * 2;

    double tx(double x) =>
        pad + (x - minX) / ((maxX - minX).clamp(1, 9999)) * w;
    double ty(double y) => pad + (maxY - y) / (maxY - minY) * h;

    final grid = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1;
    for (double y = 2; y <= 6; y++) {
      canvas.drawLine(
          Offset(pad, ty(y)), Offset(size.width - pad, ty(y)), grid);
    }

    final p = Paint()
      ..color = const Color(0xFF1AAE6F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(tx(pts.first.dx), ty(pts.first.dy));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(tx(pts[i].dx), ty(pts[i].dy));
    }
    canvas.drawPath(path, p);

    final dot = Paint()..color = const Color(0xFF1AAE6F);
    for (final o in pts) {
      canvas.drawCircle(Offset(tx(o.dx), ty(o.dy)), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.pts != pts;
}
