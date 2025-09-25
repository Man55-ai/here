// lib/journal.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final sp = Supabase.instance.client;

  DateTime _month = DateTime.now();
  DateTime _selected = DateTime.now();
  bool _loading = true;
  String? _error;
  String _summary = '—';
  Set<DateTime> _daysWithNotes = {};

  @override
  void initState() {
    super.initState();
    _loadMonthAndDay();
  }

  void _set(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMonthAndDay() async {
    _set(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await _fetchDaysWithEntriesForMonth(_month);
      _daysWithNotes = days;
      await _loadSummaryFor(_selected);
    } catch (e) {
      _set(() => _error = e.toString());
    } finally {
      _set(() => _loading = false);
    }
  }

  Future<Set<DateTime>> _fetchDaysWithEntriesForMonth(DateTime month) async {
    final uid = sp.auth.currentUser?.id;
    if (uid == null) return {};
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    final rows = await sp
        .from('messages')
        .select('created_at')
        .eq('user_id', uid)
        .gte('created_at', first.toIso8601String())
        .lt('created_at', last.add(const Duration(days: 1)).toIso8601String());

    final set = <DateTime>{};
    for (final m in rows as List) {
      final dt = DateTime.tryParse('${m['created_at']}');
      if (dt != null) set.add(_norm(dt));
    }
    return set;
  }

  Future<void> _loadSummaryFor(DateTime day) async {
    _set(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = sp.auth.currentUser?.id;
      if (uid == null) throw Exception('โปรดเข้าสู่ระบบก่อนใช้งานสมุดบันทึก');

      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      final rows = await sp
          .from('messages')
          .select('role,text,created_at')
          .eq('user_id', uid)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at');

      if ((rows as List).isEmpty) {
        _summary = 'วันนี้ยังไม่มีบทสนทนาหรือบันทึก';
        return;
      }

      final context = rows
          .map((r) {
            final role = (r['role'] ?? 'ai').toString();
            final text = (r['text'] ?? '').toString().trim();
            if (text.isEmpty) return '';
            return '${role == 'user' ? 'User' : 'AI'}: $text';
          })
          .where((s) => s.isNotEmpty)
          .join('\n');

      // พยายามเรียก Edge Function (ถ้ามี)
      try {
        final res = await sp.functions.invoke('journal_summarize', body: {
          'date': _isoDate(start),
          'context': context,
        });
        final data = res.data;
        if (data is Map && data['summary'] is String) {
          _summary = data['summary'] as String;
        } else {
          _summary = _localHeuristicSummary(context);
        }
      } catch (_) {
        _summary = _localHeuristicSummary(context);
      }
    } catch (e) {
      _set(() => _error = e.toString());
    } finally {
      _set(() => _loading = false);
    }
  }

  String _localHeuristicSummary(String ctx) {
    final lc = ctx.toLowerCase();
    const pos = ['ดี', 'ชอบ', 'สนุก', 'สำเร็จ', 'ขอบคุณ', 'ภูมิใจ', 'รัก'];
    const neg = ['เครียด', 'เศร้า', 'กังวล', 'ท้อ', 'เหนื่อย', 'โกรธ'];
    int p = 0, n = 0;
    for (final w in pos) {
      p += RegExp(w).allMatches(lc).length;
    }
    for (final w in neg) {
      n += RegExp(w).allMatches(lc).length;
    }
    final tone =
        p >= n ? 'โดยรวมอารมณ์เป็นบวก' : 'โดยรวมอารมณ์ค่อนข้างลบเล็กน้อย';
    final sample = ctx.split('\n').take(4).join('\n');
    return '$tone\n\nไฮไลต์จากบทสนทนา:\n$sample';
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalDetailPage(day: _selected)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _norm(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('สมุดบันทึกรายวัน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Hero(tag: 'journal-hero', child: _CoverImage()),
          const SizedBox(height: 16),
          _MonthHeader(
            month: _month,
            onPrev: () {
              setState(() => _month = DateTime(_month.year, _month.month - 1));
              _loadMonthAndDay();
            },
            onNext: () {
              setState(() => _month = DateTime(_month.year, _month.month + 1));
              _loadMonthAndDay();
            },
          ),
          const SizedBox(height: 8),
          _CalendarGrid(
            month: _month,
            selected: _selected,
            isEnabled: (d) => !d.isAfter(today), // อนาคต = เทา/ปิดแตะ
            hasNote: (d) => _daysWithNotes.contains(_norm(d)),
            onTap: (d) {
              if (d.isAfter(today)) return;
              setState(() => _selected = _norm(d));
              _loadSummaryFor(d);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Legend(color: Colors.green, label: 'มีบันทึก'),
              const SizedBox(width: 12),
              _Legend(color: cs.outlineVariant, label: 'อนาคต/ปิดแตะ'),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _Card(
              color: cs.errorContainer,
              child: Text(
                'เกิดข้อผิดพลาด: $_error',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            )
          else ...[
            // การ์ดสรุป (กดได้)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openDetail(context),
              child: _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('สรุปความรู้สึก • ${_isoDate(_selected)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_summary),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openDetail(context),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('ดูฉบับเต็ม'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openDetail(context),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('แตะการ์ดสรุปเพื่อเปิดฉบับเต็ม'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'หมายเหตุ: นี่คือบันทึกเชิงช่วยคิด ไม่ใช่คำแนะนำทางการแพทย์ หากมีความเสี่ยง โปรดติดต่อผู้เชี่ยวชาญ',
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

// ---------- Detail page ----------
class JournalDetailPage extends StatefulWidget {
  final DateTime day;
  const JournalDetailPage({super.key, required this.day});

  @override
  State<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends State<JournalDetailPage> {
  final sp = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String _longSummary = '—';
  List<Map<String, dynamic>> _messages = const [];

  DateTime get _start =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);
  DateTime get _end => _start.add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = sp.auth.currentUser?.id;
      if (uid == null) throw Exception('โปรดเข้าสู่ระบบก่อนใช้งาน');

      // ข้อความทั้งวัน
      final rows = await sp
          .from('messages')
          .select('role,text,created_at')
          .eq('user_id', uid)
          .gte('created_at', _start.toIso8601String())
          .lt('created_at', _end.toIso8601String())
          .order('created_at');

      _messages =
          (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();

      final ctx = _messages
          .map((r) {
            final role = (r['role'] ?? 'ai').toString();
            final text = (r['text'] ?? '').toString().trim();
            if (text.isEmpty) return '';
            return '${role == 'user' ? 'User' : 'AI'}: $text';
          })
          .where((s) => s.isNotEmpty)
          .join('\n');

      // ลอง Edge Function โหมด long
      String longSum;
      try {
        final res = await sp.functions.invoke('journal_summarize', body: {
          'mode': 'long',
          'date': _start.toIso8601String().substring(0, 10),
          'context': ctx,
        });
        final data = res.data;
        longSum = (data is Map && data['summary'] is String)
            ? data['summary'] as String
            : _fallbackLong(ctx);
      } catch (_) {
        longSum = _fallbackLong(ctx);
      }

      if (!mounted) return;
      setState(() => _longSummary = longSum);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fallbackLong(String ctx) {
    final lines = ctx.split('\n').where((e) => e.trim().isNotEmpty).toList();
    final sample = lines.take(8).join('\n');
    return '''
สรุปฉบับยาว (อัตโนมัติ)
- โฟกัสอารมณ์รวม + ประเด็นหลักจากบทสนทนา
- คำแนะนำเบื้องต้น: จัดรายการสิ่งเล็ก ๆ ที่ทำได้ 1–2 ข้อ แล้วติดตามผลวันถัดไป

ไฮไลต์จากบทสนทนา:
$sample
''';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleDate =
        '${widget.day.year}-${widget.day.month.toString().padLeft(2, '0')}-${widget.day.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text('บันทึก • $titleDate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Hero(tag: 'journal-hero', child: _CoverImage()),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _Card(
              color: cs.errorContainer,
              child: Text('เกิดข้อผิดพลาด: $_error',
                  style: TextStyle(color: cs.onErrorContainer)),
            )
          else ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สรุปฉบับเต็ม',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_longSummary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('บทสนทนาของวันนั้น',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_messages.isEmpty)
              _Card(child: Text('ยังไม่มีบทสนทนาในวันนี้'))
            else
              ..._messages.map((m) {
                final role = (m['role'] ?? 'ai').toString();
                final text = (m['text'] ?? '').toString();
                final t = DateTime.tryParse('${m['created_at']}');
                final time = t == null
                    ? ''
                    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: role == 'user'
                        ? cs.primaryContainer.withOpacity(.4)
                        : cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${role == 'user' ? 'ผู้ใช้' : 'AI'} • $time',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.outline)),
                      const SizedBox(height: 4),
                      Text(text),
                    ],
                  ),
                );
              }),
          ],
          const SizedBox(height: 24),
          Text(
            'หมายเหตุ: นี่คือบันทึกเชิงช่วยคิด ไม่ใช่คำแนะนำทางการแพทย์',
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

// ---------- small reusable widgets ----------
class _CoverImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200&q=80',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
              child: Container(color: Colors.black.withOpacity(.25))),
          Positioned.fill(
            child: Center(
              child: Text(
                'สมุดบันทึก',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color.withOpacity(.2),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: child,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader(
      {required this.month, required this.onPrev, required this.onNext});

  static const _th = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  @override
  Widget build(BuildContext context) {
    final label = '${_th[month.month - 1]} ${month.year}';
    return Row(children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Expanded(
          child: Center(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleLarge))),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final bool Function(DateTime) isEnabled;
  final bool Function(DateTime) hasNote;
  final void Function(DateTime) onTap;

  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.isEnabled,
    required this.hasNote,
    required this.onTap,
  });

  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = first.weekday % 7; // 0=Sun..6=Sat
    final days = last.day;
    final cs = Theme.of(context).colorScheme;

    final cells = <Widget>[];
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    cells.addAll(names.map((n) =>
        Center(child: Text(n, style: Theme.of(context).textTheme.bodySmall))));

    for (int i = 0; i < firstWeekday; i++) cells.add(const SizedBox());

    for (int d = 1; d <= days; d++) {
      final date = _norm(DateTime(month.year, month.month, d));
      final enabled = isEnabled(date);
      final noted = hasNote(date);
      final isSel = _norm(selected) == date;

      Color border = Theme.of(context).dividerColor.withOpacity(.25);
      Color bg = Colors.white;
      if (!enabled) {
        bg = cs.surfaceVariant.withOpacity(.25);
      } else if (noted) {
        bg = Colors.green.withOpacity(.12);
      }
      if (isSel) border = cs.primary;

      cells.add(GestureDetector(
        onTap: enabled ? () => onTap(date) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: isSel ? 2 : 1),
          ),
          child: Center(
            child: Text('$d', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ));
    }

    while (cells.length % 7 != 0) cells.add(const SizedBox());

    return GridView.count(
      crossAxisCount: 7,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
