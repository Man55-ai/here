// lib/hereme_patch_bundle.dart
// รวม UI/บริการใหม่: หน้า Home สวย ๆ, กราฟหัวข้อแชท, Guide วิเคราะห์อาชีพ, รายการโปรด
// วิธีใช้: import 'hereme_patch_bundle.dart'; แล้วเพิ่ม routes + ใช้ EnhancedHomeBody เป็น body ของ Home

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ======== Common Supabase client ========
sb.SupabaseClient get _c => sb.Supabase.instance.client;

// =================== Enhanced Home (สวยขึ้น) ===================
class EnhancedHomeBody extends StatelessWidget {
  final VoidCallback onOpenTopicsChart;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenMatching;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenFavorites;

  const EnhancedHomeBody({
    super.key,
    required this.onOpenTopicsChart,
    required this.onOpenChat,
    required this.onOpenGuide,
    required this.onOpenMatching,
    required this.onOpenHistory,
    required this.onOpenFavorites,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          elevation: 0,
          backgroundColor: cs.surface,
          automaticallyImplyLeading: false, // ✅ กันไอคอนเมนูซ้ำ
          toolbarHeight: 0, // ✅ ไม่ต้องมีทูลบาร์ซ้ำ (ให้เห็นแต่ gradient)
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withOpacity(.10),
                  cs.secondary.withOpacity(.10)
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _AffirmationCard(),
          ),
        ),
        // ปุ่มใหญ่ตรงกลาง → กราฟหัวข้อแชท
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _BigCenterButton(
              label: "ดูสถิติหัวข้อที่คุยกับแชท",
              subtitle: "สรุปและจัดอันดับหัวข้อที่คุย",
              icon: Icons.auto_graph_rounded,
              onTap: onOpenTopicsChart,
            ),
          ),
        ),
        // Grid ฟีเจอร์
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _FeatureCard(
                  icon: Icons.chat_bubble_rounded,
                  title: "Safe Emotional Sharing",
                  onTap: onOpenChat),
              _FeatureCard(
                  icon: Icons.school_rounded,
                  title: "Life Planner & Guide",
                  onTap: onOpenGuide),
              _FeatureCard(
                  icon: Icons.volunteer_activism_rounded,
                  title: "Mentor Matching",
                  onTap: onOpenMatching),
              _FeatureCard(
                  icon: Icons.favorite_rounded,
                  title: "รายการโปรด",
                  onTap: onOpenFavorites),
            ],
          ),
        ),
        // CTA ประวัติ
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _CTA(
                icon: Icons.history_rounded,
                label: "ประวัติแชท / แยกตามหัวข้อ",
                onTap: onOpenHistory),
          ),
        ),
      ],
    );
  }
}

class _AffirmationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withOpacity(.08),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.wb_sunny_rounded, size: 28),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Affirmation ประจำวัน",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("ก้าวเล็ก ๆ วันนี้ คือก้าวใหญ่ในอนาคตของเรา ✨",
              style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]),
    );
  }
}

class _BigCenterButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _BigCenterButton(
      {super.key,
      required this.label,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(colors: [
            cs.primary.withOpacity(.15),
            cs.secondary.withOpacity(.15)
          ]),
        ),
        child: Row(children: [
          CircleAvatar(
              radius: 28,
              backgroundColor: cs.surface,
              child: Icon(icon, size: 28, color: cs.primary)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ])),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _FeatureCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: cs.shadow.withOpacity(.06),
                blurRadius: 10,
                offset: const Offset(0, 6))
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 28, color: cs.primary),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ]),
      ),
    );
  }
}

class _CTA extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CTA(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: cs.surfaceContainerHighest),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.titleSmall)),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

// =================== Favorites Service & Page ===================
class FavoriteItem {
  final String id;
  final String type;
  final String refId;
  final DateTime createdAt;
  FavoriteItem(
      {required this.id,
      required this.type,
      required this.refId,
      required this.createdAt});
  factory FavoriteItem.fromMap(Map<String, dynamic> m) => FavoriteItem(
        id: m['id'] as String,
        type: m['type'] as String,
        refId: m['ref_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class FavoritesService {
  FavoritesService._();
  static final I = FavoritesService._();
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Future<void> toggle(String type, String refId) async {
    final uid = _client.auth.currentUser!.id;
    final existing = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('type', type)
        .eq('ref_id', refId)
        .maybeSingle();
    if (existing != null) {
      await _client.from('favorites').delete().eq('id', existing['id']);
    } else {
      await _client
          .from('favorites')
          .insert({'user_id': uid, 'type': type, 'ref_id': refId});
    }
  }

  Future<List<FavoriteItem>> listByType(String type) async {
    final uid = _client.auth.currentUser!.id;
    final res = await _client
        .from('favorites')
        .select()
        .eq('user_id', uid)
        .eq('type', type)
        .order('created_at', ascending: false);
    return (res as List).map((e) => FavoriteItem.fromMap(e)).toList();
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<FavoriteItem> mentors = [];
  List<FavoriteItem> chats = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      mentors = await FavoritesService.I.listByType('mentor');
      chats = await FavoritesService.I.listByType('chat');
    } catch (e) {
      // แสดงคู่มือสั้น ๆ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'ยังไม่ได้ตั้งค่าตาราง favorites – ดูคู่มือใน README/SQL')),
        );
      }
      mentors = [];
      chats = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('รายการโปรด'),
            bottom: TabBar(
                controller: _tab,
                tabs: const [Tab(text: 'ผู้เชี่ยวชาญ'), Tab(text: 'แชท')])),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tab, children: [
                _FavList(items: mentors, empty: 'ยังไม่มีผู้เชี่ยวชาญที่ถูกใจ'),
                _FavList(items: chats, empty: 'ยังไม่มีห้องแชทที่ถูกใจ'),
              ]));
  }
}

class _FavList extends StatelessWidget {
  final List<FavoriteItem> items;
  final String empty;
  const _FavList({required this.items, required this.empty});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(empty));
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                    color:
                        Theme.of(context).colorScheme.shadow.withOpacity(.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListTile(
              title: Text('${it.type.toUpperCase()} • ${it.refId}'),
              subtitle: Text('บันทึกเมื่อ ${it.createdAt.toLocal()}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {/* TODO: ไปหน้ารายละเอียดโดยใช้ it.refId */},
            ),
          );
        });
  }
}

// =================== Topics Chart (จาก messages) ===================
class TopicsChartPage extends StatefulWidget {
  const TopicsChartPage({super.key});
  @override
  State<TopicsChartPage> createState() => _TopicsChartPageState();
}

class _TopicsChartPageState extends State<TopicsChartPage> {
  Map<String, int> counts = {};
  bool loading = true;
  static const Map<String, List<String>> keywordMap = {
    'การเรียน': [
      'สอบ',
      'การบ้าน',
      'เกรด',
      'เรียน',
      'ครู',
      'โรงเรียน',
      'มหาลัย'
    ],
    'เพื่อน': ['เพื่อน', 'โดนบูลลี่', 'กลุ่ม', 'สังคม', 'ชวน'],
    'ครอบครัว': ['พ่อ', 'แม่', 'ครอบครัว', 'บ้าน', 'พี่น้อง'],
    'ความรัก': ['แฟน', 'ชอบ', 'รัก', 'เลิก', 'อกหัก', 'ความสัมพันธ์'],
    'สุขภาพใจ': ['เครียด', 'ซึมเศร้า', 'วิตก', 'กังวล', 'เหนื่อย', 'หมดไฟ'],
    'สุขภาพกาย': ['ป่วย', 'นอน', 'ปวดหัว', 'ปวดท้อง', 'สุขภาพ', 'ออกกำลังกาย'],
    'การเงิน': ['เงิน', 'รายได้', 'รายจ่าย', 'ลงทุน', 'งานพาร์ทไทม์'],
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    List data = [];
    try {
      final res = await _c
          .from('messages')
          .select('content, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1000);
      data = res as List;
    } catch (_) {
      data = [];
    }
    final Map<String, int> temp = {for (final k in keywordMap.keys) k: 0};
    for (final row in data) {
      final content = (row['content'] ?? '').toString().toLowerCase();
      for (final entry in keywordMap.entries) {
        for (final kw in entry.value) {
          if (content.contains(kw.toLowerCase())) {
            temp[entry.key] = (temp[entry.key] ?? 0) + 1;
            break;
          }
        }
      }
    }
    setState(() {
      counts = temp;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
        appBar: AppBar(title: const Text('หัวข้อที่คุยกับแชท')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: entries.isEmpty
                    ? const Center(child: Text('ยังไม่มีข้อมูลหัวข้อ'))
                    : BarChart(BarChartData(
                        titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: true)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, meta) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= entries.length)
                                        return const SizedBox.shrink();
                                      return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6.0),
                                          child: Text(entries[i].key,
                                              style: const TextStyle(
                                                  fontSize: 10)));
                                    }))),
                        barGroups: [
                          for (int i = 0; i < entries.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(toY: entries[i].value.toDouble())
                            ])
                        ],
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true),
                      ))));
  }
}

// =================== Career Guide (Smart) ===================
class CareerGuideSmartPage extends StatefulWidget {
  const CareerGuideSmartPage({super.key});
  @override
  State<CareerGuideSmartPage> createState() => _CareerGuideSmartPageState();
}

class _CareerGuideSmartPageState extends State<CareerGuideSmartPage> {
  bool loading = true;
  Map<String, double> scores = {};
  List<String> suggestions = [];
  static const Map<String, List<String>> keywordMap = {
    'ธุรกิจ/การเงิน': [
      'หุ้น',
      'กองทุน',
      'ธุรกิจ',
      'การเงิน',
      'บัญชี',
      'ลงทุน',
      'ผู้ประกอบการ'
    ],
    'สายสุขภาพ': ['หมอ', 'พยาบาล', 'สุขภาพ', 'โรงพยาบาล', 'รักษา', 'กายภาพ'],
    'ไอที/วิศวะ': [
      'เขียนโปรแกรม',
      'โค้ด',
      'แอป',
      'วิศวะ',
      'เทคโนโลยี',
      'คอมพิวเตอร์'
    ],
    'สังคม/ครู': ['สอน', 'ครู', 'สังคม', 'จิตอาสา', 'กิจกรรม', 'ชุมชน'],
    'ศิลป์/ครีเอทีฟ': ['ออกแบบ', 'วาด', 'ศิลปะ', 'ดีไซน์', 'โฆษณา', 'ครีเอทีฟ'],
    'สื่อ/คอนเทนต์': [
      'วิดีโอ',
      'ยูทูป',
      'ตัดต่อ',
      'สื่อสาร',
      'สื่อ',
      'พอดแคสต์'
    ],
  };
  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    List data = [];
    try {
      final res = await _c
          .from('messages')
          .select('content, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1000);
      data = res as List;
    } catch (_) {
      data = [];
    }
    final Map<String, double> temp = {for (final k in keywordMap.keys) k: 0};
    for (final row in data) {
      final content = (row['content'] ?? '').toString().toLowerCase();
      for (final e in keywordMap.entries) {
        for (final kw in e.value) {
          if (content.contains(kw.toLowerCase())) {
            temp[e.key] = (temp[e.key] ?? 0) + 1;
            break;
          }
        }
      }
    }
    final ranked = temp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<String> recs = [];
    for (final e in ranked.take(3)) {
      switch (e.key) {
        case 'ธุรกิจ/การเงิน':
          recs.addAll(
              ['ที่ปรึกษาการเงิน', 'นักวิเคราะห์การลงทุน', 'ผู้ประกอบการ']);
          break;
        case 'สายสุขภาพ':
          recs.addAll(['นักจิตวิทยา', 'แพทย์', 'ผู้เชี่ยวชาญฟื้นฟู']);
          break;
        case 'ไอที/วิศวะ':
          recs.addAll(['นักพัฒนาซอฟต์แวร์', 'วิศวกรข้อมูล', 'นักวิจัย AI']);
          break;
        case 'สังคม/ครู':
          recs.addAll(['ครูแนะแนว', 'นักสังคมสงเคราะห์', 'ผู้ประสานงานชุมชน']);
          break;
        case 'ศิลป์/ครีเอทีฟ':
          recs.addAll(['นักออกแบบกราฟิก', 'ครีเอทีฟโฆษณา', 'นักออกแบบ UX/UI']);
          break;
        case 'สื่อ/คอนเทนต์':
          recs.addAll(
              ['คอนเทนต์ครีเอเตอร์', 'โปรดิวเซอร์วิดีโอ', 'นักสื่อสารองค์กร']);
          break;
      }
    }
    setState(() {
      loading = false;
      scores = temp;
      suggestions = recs.toSet().toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Life Planner & Career Guide')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('วิเคราะห์จากหัวข้อที่คุณคุยกับแชทล่าสุด',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scores.entries
                        .map((e) =>
                            Chip(label: Text('${e.key}: ${e.value.toInt()}')))
                        .toList()),
                const SizedBox(height: 16),
                Text('อาชีพที่แนะนำ',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...suggestions.map((s) => _JobCard(title: s)),
                const SizedBox(height: 24),
                const Text('คำแนะนำถัดไป'),
                const SizedBox(height: 8),
                const Text(
                    '• สร้างเป้าหมายระยะสั้น/กลาง/ยาว\n• เลือกกิจกรรมเสริมทักษะที่เกี่ยวข้อง\n• นัดคุยกับผู้เชี่ยวชาญเพื่อวางแผนรายละเอียด'),
              ]));
  }
}

class _JobCard extends StatelessWidget {
  final String title;
  const _JobCard({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        const Icon(Icons.workspace_premium_rounded),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}
