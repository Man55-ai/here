import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// OnboardingFlow:
/// 1) เลือกภาษา (ใช้ภาพ 1.png เป็นภาพประกอบ)
/// 2) สไลด์ 4 หน้า:
///    - EN ใช้ภาพ 2-5.png (จบที่หน้า 5)
///    - TH ใช้ภาพ 6-9.png (จบที่หน้า 9)
///
/// โค้ดไม่ผูก storage ตรง ๆ — ให้ main.dart ส่ง callback เข้ามา
class OnboardingFlow extends StatefulWidget {
  final String? initialLang; // 'th' | 'en' | null
  final Future<void> Function(String lang) onPickLanguage;
  final Future<void> Function() onMarkSeen;
  final VoidCallback onFinish;

  const OnboardingFlow({
    super.key,
    this.initialLang,
    required this.onPickLanguage,
    required this.onMarkSeen,
    required this.onFinish,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  String? _lang;

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang; // ถ้าโหลดได้แล้วให้ข้ามหน้าเลือกภาษา
  }

  @override
  Widget build(BuildContext context) {
    // ยังไม่เลือกภาษา → หน้าเลือกภาษา (โชว์ภาพ 1.png)
    if (_lang == null) {
      return LanguageSelectPage(
        onPicked: (code) async {
          await widget.onPickLanguage(code);
          if (!mounted) return;
          setState(() => _lang = code);
        },
      );
    }

    // เลือกแล้ว → ไป PageView ของภาษานั้น ๆ
    return IntroSlidesPage(
      lang: _lang!,
      onFinish: () async {
        await widget.onMarkSeen();
        if (!mounted) return;
        widget.onFinish(); // ใน main จะเช็คแล้วไป /home หรือ /login
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// หน้าเลือกภาษา (ภาพประกอบ = assets/images/1.png)
/// ---------------------------------------------------------------------------
class LanguageSelectPage extends StatelessWidget {
  final void Function(String langCode) onPicked;
  const LanguageSelectPage({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    // ปรับสัดส่วนรูปหลักได้ 0.55–0.70 ตามความชอบ
    final heroHeight = h * 0.62;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== รูป 1.png เต็ม ๆ กลางจอ =====
            SizedBox(
              height: heroHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    'assets/1.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain, // โชว์ใหญ่ ๆ แต่ไม่บิดสัดส่วน
                  ),
                ),
              ),
            ),

            // เว้นระยะเล็กน้อย
            const SizedBox(height: 8),

            // ===== ปุ่มเลือกภาษา (ตัวจริง ไม่ใช่จากรูป) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LangTile(
                    label: 'ภาษาไทย',
                    subtitle: 'Thai',
                    onTap: () => onPicked('th'),
                  ),
                  const SizedBox(height: 12),
                  _LangTile(
                    label: 'English',
                    subtitle: 'English',
                    onTap: () => onPicked('en'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingFormInline extends StatefulWidget {
  const _OnboardingFormInline({super.key});
  @override
  State<_OnboardingFormInline> createState() => _OnboardingFormInlineState();
}

class _OnboardingFormInlineState extends State<_OnboardingFormInline> {
  final _formKey = GlobalKey<FormState>();
  final _full = TextEditingController();
  final _nick = TextEditingController();
  final _school = TextEditingController();
  String? _gender;
  DateTime? _dob;
  bool _saving = false;

  @override
  void dispose() {
    _full.dispose();
    _nick.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = sb.Supabase.instance.client.auth.currentUser!.id;
    await sb.Supabase.instance.client.from('profiles').upsert({
      'id': uid,
      'full_name': _full.text.trim(),
      'display_name': _nick.text.trim(),
      'school': _school.text.trim().isEmpty ? null : _school.text.trim(),
      'gender': _gender,
      'birthday': _dob?.toIso8601String(),
    });
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าข้อมูลผู้ใช้')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text('ยินดีต้อนรับ! กรอกข้อมูลสั้น ๆ เพื่อเริ่มใช้ HereMe',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _full,
                  decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรอกชื่อเต็ม' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nick,
                  decoration: const InputDecoration(labelText: 'ชื่อแสดง'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรอกชื่อแสดง' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _school,
                  decoration:
                      const InputDecoration(labelText: 'โรงเรียน (ถ้ามี)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ชาย')),
                    DropdownMenuItem(value: 'female', child: Text('หญิง')),
                    DropdownMenuItem(value: 'other', child: Text('อื่น ๆ')),
                    DropdownMenuItem(
                        value: 'prefer_not', child: Text('ไม่ระบุ')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  decoration: const InputDecoration(labelText: 'เพศ'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dob == null
                      ? 'วันเกิด (ตัวเลือก)'
                      : 'วันเกิด: ${_dob!.toLocal().toString().split(' ')[0]}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 80),
                      lastDate: DateTime(now.year + 1),
                      initialDate: DateTime(now.year - 15, now.month, now.day),
                    );
                    if (picked != null) setState(() => _dob = picked);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('บันทึกและเริ่มใช้งาน'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCheckInSheetInline extends StatefulWidget {
  const _DailyCheckInSheetInline({super.key});
  @override
  State<_DailyCheckInSheetInline> createState() =>
      _DailyCheckInSheetInlineState();
}

class _DailyCheckInSheetInlineState extends State<_DailyCheckInSheetInline> {
  int _mood = 4; // 1..6
  final _summary = TextEditingController();
  final List<String> _symptomsAll = const [
    'ปวดหัว',
    'ปวดท้อง',
    'เหนื่อยล้า',
    'นอนไม่หลับ',
    'กังวล',
    'เศร้า',
    'โกรธ',
    'เครียด',
    'ไม่มีแรงจูงใจ',
    'โดนบูลลี่'
  ];
  final Set<String> _picked = {};
  bool _saving = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final uid = sb.Supabase.instance.client.auth.currentUser!.id;
    final now = DateTime.now();
    await sb.Supabase.instance.client.from('mood_checkins').upsert({
      'user_id': uid,
      'checkin_date': DateTime(now.year, now.month, now.day)
          .toIso8601String()
          .substring(0, 10),
      'mood_score': _mood,
      'how_was_today':
          _summary.text.trim().isEmpty ? null : _summary.text.trim(),
      'symptoms': _picked.isEmpty ? null : _picked.toList(),
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999))),
          Text('เช็คอินวันนี้เป็นอย่างไรบ้าง?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('ระดับความสุขวันนี้ (1–6)'),
          Slider(
            value: _mood.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            label: _mood.toString(),
            onChanged: (v) => setState(() => _mood = v.round()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _summary,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'วันนี้เป็นยังไง (สรุปสั้น ๆ)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('อาการที่รู้สึก (เลือกได้หลายข้อ)')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _symptomsAll
                .map((s) => FilterChip(
                      label: Text(s),
                      selected: _picked.contains(s),
                      onSelected: (sel) => setState(() {
                        if (sel)
                          _picked.add(s);
                        else
                          _picked.remove(s);
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('บันทึกเช็คอินวันนี้'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _LangTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF6F9F7),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, child: Icon(Icons.flag)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// สไลด์ Onboarding
/// - ถ้า lang == 'en' → ใช้ภาพ 2,3,4,5.png
/// - ถ้า lang == 'th' → ใช้ภาพ 6,7,8,9.png
/// ปุ่ม Next/Skip และหน้าสุดท้ายเป็น Start Now/เริ่มต้นใช้งาน
/// ---------------------------------------------------------------------------

class IntroSlidesPage extends StatefulWidget {
  final String lang; // 'th' | 'en'
  final VoidCallback onFinish;
  const IntroSlidesPage(
      {super.key, required this.lang, required this.onFinish});

  @override
  State<IntroSlidesPage> createState() => _IntroSlidesPageState();
}

class _IntroSlidesPageState extends State<IntroSlidesPage> {
  final _pc = PageController();
  int _idx = 0;

  late final List<String> _images = widget.lang == 'en'
      ? const ['assets/2.png', 'assets/3.png', 'assets/4.png', 'assets/5.png']
      : const ['assets/6.png', 'assets/7.png', 'assets/8.png', 'assets/9.png'];

  void _next() {
    if (_idx < _images.length - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.lang == 'th';
    final isLast = _idx == _images.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // ===== รูปเต็มหน้า (คงสัดส่วน, กินพื้นที่เท่าที่จอรองรับ) =====
          PageView.builder(
            controller: _pc,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) {
              final img = _images[i];
              return Center(
                child: Padding(
                  // เผื่อขอบนิดหน่อยให้เนื้อหาไม่ติดขอบ
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    img,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain, // โชว์เต็มที่โดยไม่บิดสัดส่วน
                  ),
                ),
              );
            },
          ),

          // ===== แผงควบคุมด้านล่าง (Indicator + ปุ่ม Next/Skip) =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  // ทำให้ล่างดูอ่านปุ่มชัดขึ้น
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.85),
                      Colors.white,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(count: _images.length, index: _idx),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        child: Text(
                          isLast
                              ? (th ? 'เริ่มต้นใช้งาน' : 'Start Now')
                              : (th ? 'ต่อไป' : 'Next'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onFinish,
                        child: Text(th ? 'ข้าม' : 'Skip'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({super.key, required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 22 : 8,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
