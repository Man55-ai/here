// lib/guide.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ------------ Model ------------
class CareerSuggestion {
  final String title;
  final String reason;
  final int fitScore; // 0-100
  final List<String> nextSteps;

  CareerSuggestion({
    required this.title,
    required this.reason,
    required this.fitScore,
    required this.nextSteps,
  });

  factory CareerSuggestion.fromJson(Map<String, dynamic> j) => CareerSuggestion(
        title: (j['title'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        fitScore: int.tryParse('${j['fit_score']}') ?? 0,
        nextSteps: (j['next_steps'] as List?)?.map((e) => '$e').toList() ?? [],
      );
}

/// ------------ Engine ------------
class CareerGuideEngine {
  final SupabaseClient sp;
  CareerGuideEngine(this.sp);

  /// รวมข้อความล่าสุดจากตาราง messages (ผู้ใช้ปัจจุบัน)
  Future<String> buildContext({int limit = 40}) async {
    final uid = sp.auth.currentUser?.id;
    if (uid == null) return '';

    final rows = await sp
        .from('messages')
        .select('role,text,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    // สลับกลับเป็นลำดับเวลาเก่า→ใหม่ แล้วทำสรุป
    final list = (rows as List)
        .reversed
        .map((m) {
          final role = (m['role'] ?? 'ai').toString();
          final text = (m['text'] ?? '').toString().trim();
          if (text.isEmpty) return '';
          return '${role == 'user' ? 'User' : 'AI'}: $text';
        })
        .where((s) => s.isNotEmpty)
        .toList();

    // ตัดความยาวเพื่อกัน payload ใหญ่เกิน
    final ctx = list.join('\n');
    return ctx.length > 4000 ? ctx.substring(ctx.length - 4000) : ctx;
  }

  /// เรียก Edge Function `career_guide`
  Future<List<CareerSuggestion>> analyzeAndRecommend(String context) async {
    final res = await sp.functions.invoke(
      'career_guide',
      body: {'context': context},
    );
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => CareerSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}

/// ------------ UI Page ------------
class CareerGuidePage extends StatefulWidget {
  const CareerGuidePage({super.key});

  @override
  State<CareerGuidePage> createState() => _CareerGuidePageState();
}

class _CareerGuidePageState extends State<CareerGuidePage> {
  final sp = Supabase.instance.client;
  late final CareerGuideEngine _engine = CareerGuideEngine(sp);

  bool _loading = true;
  String? _error;
  String _contextPreview = '';
  List<CareerSuggestion> _recs = const [];

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    _setStateSafe(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) ดึงบริบท
      final ctx = await _engine.buildContext(limit: 40);
      if (!mounted) return;
      _contextPreview = _makePreview(ctx);

      // 2) เรียกฟังก์ชัน (ถ้าไม่มีบริบท จะส่งสตริงว่าง ๆ ได้)
      final recs = await _engine.analyzeAndRecommend(ctx);
      if (!mounted) return;

      _setStateSafe(() {
        _recs = recs;
      });
    } catch (e) {
      if (!mounted) return;
      _setStateSafe(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      _setStateSafe(() => _loading = false);
    }
  }

  String _makePreview(String ctx) {
    if (ctx.trim().isEmpty) {
      return 'ยังไม่มีบริบทจากการสนทนา กรุณาพูดคุยในแชทสักเล็กน้อย แล้วกดรีเฟรชอีกครั้ง';
    }
    final t = ctx.split('\n');
    final last = t.sublist(max(0, t.length - 6)).join('\n');
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Life Planner & Career Guide')),
      body: RefreshIndicator(
        onRefresh: _run,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // บริบทจากการสนทนา (พรีวิว)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('บริบทจากการสนทนา',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    _contextPreview,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurface.withOpacity(.8)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _run,
                      icon: const Icon(Icons.refresh),
                      label: const Text('วิเคราะห์อีกครั้ง'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )),
            ] else if (_error != null) ...[
              _Card(
                color: cs.errorContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เกิดข้อผิดพลาด',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: cs.onErrorContainer)),
                    const SizedBox(height: 8),
                    Text('$_error',
                        style:
                            TextStyle(color: cs.onErrorContainer, height: 1.2)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _run,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                      ),
                    )
                  ],
                ),
              )
            ] else if (_recs.isEmpty) ...[
              _Card(
                child: Text(
                  'ยังไม่มีคำแนะนำอาชีพจากบริบทที่พบ\n'
                  'ลองคุยในหน้าแชทเกี่ยวกับสิ่งที่ชอบ/ทักษะ/โปรเจกต์ แล้วกด “วิเคราะห์อีกครั้ง”',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ] else ...[
              Text('อาชีพที่แนะนำ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final r in _recs) _SuggestionCard(r),
              const SizedBox(height: 12),
              Text(
                'หมายเหตุ: นี่เป็นคำแนะนำจากโมเดลเบื้องต้นเท่านั้น '
                'ควรพิจารณาตามประสบการณ์ ความสนใจ และบริบทส่วนตัวเพิ่มเติม',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ------------ small widgets ------------
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
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final CareerSuggestion rec;
  const _SuggestionCard(this.rec);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                rec.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${rec.fitScore}%',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          ]),
          const SizedBox(height: 8),
          Text(rec.reason),
          if (rec.nextSteps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Next steps', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final s in rec.nextSteps)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(s)),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
