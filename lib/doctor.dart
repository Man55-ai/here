// lib/doctor.dart
// ===============================================================
// ใช้ได้ทั้ง 2 แบบ:
// 1) ถ้ามี doctorId -> ส่ง doctorId เข้ามา
// 2) ถ้ายังไม่มี doctorId -> ส่งข้อมูลเดิม (name/role/phone/email/avatar/bio)
//    หน้าโปรไฟล์จะ ensure แถวในตาราง `doctors` ให้อัตโนมัติ แล้วใช้ id นั้น
// ===============================================================
import 'doctor_chat_module.dart' as dc;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'favorites_service.dart';
import 'doctor_chat_module.dart';

// ---------------------------------------------------------------
// Models
// ---------------------------------------------------------------

class Doctor {
  final String id;
  final String fullName;
  final String? title;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final String? bio;

  const Doctor({
    required this.id,
    required this.fullName,
    this.title,
    this.avatarUrl,
    this.phone,
    this.email,
    this.bio,
  });

  factory Doctor.fromMap(Map<String, dynamic> m) => Doctor(
        id: m['id'] as String,
        fullName: (m['full_name'] ?? m['name'] ?? '') as String,
        title: m['title'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        bio: m['bio'] as String?,
      );
}

class DoctorBooking {
  final String id;
  final String doctorId;
  final String userId;
  final DateTime slotDate;

  const DoctorBooking({
    required this.id,
    required this.doctorId,
    required this.userId,
    required this.slotDate,
  });

  factory DoctorBooking.fromMap(Map<String, dynamic> m) => DoctorBooking(
        id: m['id'] as String,
        doctorId: m['doctor_id'] as String,
        userId: m['user_id'] as String,
        slotDate: DateTime.parse(m['slot_date'] as String),
      );
}

// ---------------------------------------------------------------
// Service
// ---------------------------------------------------------------

class DoctorService {
  static final _sp = Supabase.instance.client;
  static String? get _uid => _sp.auth.currentUser?.id;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ===== Doctors =====
  static Future<List<Doctor>> fetchDoctors() async {
    final rows = await _sp.from('doctors').select().order('created_at');
    return (rows as List)
        .map((e) => Doctor.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Doctor?> fetchDoctorById(String doctorId) async {
    final row =
        await _sp.from('doctors').select().eq('id', doctorId).maybeSingle();
    return row == null ? null : Doctor.fromMap(row);
  }

  /// ✅ ใช้ตอน “ไม่มี doctorId” แต่มีข้อมูลเดิมของหมอจากหน้าเก่า
  /// - พยายามหาแถวเดิมด้วย email ก่อน (ถ้ามี)
  /// - ถ้าไม่เจอ ลองด้วย full_name
  /// - ถ้ายังไม่เจอ → insert แถวใหม่แล้วคืน id
  static Future<String> ensureDoctor({
    required String fullName,
    String? title,
    String? email,
    String? phone,
    String? avatarUrl,
    String? bio,
  }) async {
    Map<String, dynamic>? found;

    if (email != null && email.isNotEmpty) {
      final row = await _sp
          .from('doctors')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (row != null) found = Map<String, dynamic>.from(row);
    }

    found ??= await _sp
        .from('doctors')
        .select('id')
        .eq('full_name', fullName)
        .maybeSingle();

    if (found != null) return found['id'] as String;

    final inserted = await _sp
        .from('doctors')
        .insert({
          'full_name': fullName,
          'title': title,
          'email': email,
          'phone': phone,
          'avatar_url': avatarUrl,
          'bio': bio,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  // ===== Bookings (โหมดง่าย: 1 วัน = 1 คิว/หมอ) =====
  static Future<Set<DateTime>> myBookedDaysForMonth({
    required String doctorId,
    required DateTime month,
  }) async {
    final uid = _uid;
    if (uid == null) return {};
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    final rows = await _sp
        .from('doctor_bookings')
        .select('slot_date')
        .eq('doctor_id', doctorId)
        .eq('user_id', uid)
        .gte('slot_date', _date(first))
        .lte('slot_date', _date(last));

    final set = <DateTime>{};
    for (final m in rows as List) {
      final d = DateTime.parse(m['slot_date'] as String);
      set.add(DateTime(d.year, d.month, d.day));
    }
    return set;
  }

  static Future<Set<DateTime>> takenDaysForMonth({
    required String doctorId,
    required DateTime month,
  }) async {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    final rows = await _sp
        .from('doctor_bookings')
        .select('slot_date')
        .eq('doctor_id', doctorId)
        .gte('slot_date', _date(first))
        .lte('slot_date', _date(last));

    final set = <DateTime>{};
    for (final m in rows as List) {
      final d = DateTime.parse(m['slot_date'] as String);
      set.add(DateTime(d.year, d.month, d.day));
    }
    return set;
  }

  static Future<void> bookDay({
    required String doctorId,
    required DateTime day,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('ยังไม่ได้ล็อกอิน');

    final dateOnly = DateTime(day.year, day.month, day.day);
    final todayOnly =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (dateOnly.isBefore(todayOnly)) {
      throw Exception('ไม่สามารถจองย้อนหลังได้');
    }

    await _sp.from('doctor_bookings').insert({
      'doctor_id': doctorId,
      'user_id': uid,
      'slot_date': _date(dateOnly),
    });
  }

  static Future<void> cancelMyBooking({
    required String doctorId,
    required DateTime day,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final dateOnly = DateTime(day.year, day.month, day.day);
    await _sp
        .from('doctor_bookings')
        .delete()
        .eq('doctor_id', doctorId)
        .eq('user_id', uid)
        .eq('slot_date', _date(dateOnly));
  }
}

// ---------------------------------------------------------------
// UI: หน้าโปรไฟล์หมอ + ปฏิทินจองคิว
// ---------------------------------------------------------------

class DoctorProfilePage extends StatefulWidget {
  final String? doctorId;

  // ใช้ข้อมูลเดิมจากหน้าเก่าได้ ถ้าไม่มี doctorId
  final String? name;
  final String? role; // ใช้เป็น title
  final String? specialty;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? bio;

  const DoctorProfilePage({
    super.key,
    this.doctorId,
    this.name,
    this.role,
    this.specialty,
    this.phone,
    this.email,
    this.avatarUrl,
    this.bio,
  });

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  String? _doctorId;
  Doctor? _doctor; // จาก DB เมื่อ _doctorId พร้อม
  bool _loading = true;

  // ✅ สถานะรายการโปรด
  bool _fav = false;
  bool _loadingFav = true;

  @override
  void initState() {
    super.initState();
    _doctorId = widget.doctorId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadingFav = true;
    });

    // ถ้าไม่มี doctorId ให้ ensure จากข้อมูลเดิม
    if (_doctorId == null && (widget.name?.isNotEmpty ?? false)) {
      _doctorId = await DoctorService.ensureDoctor(
        fullName: widget.name!,
        title: widget.role,
        email: widget.email,
        phone: widget.phone,
        avatarUrl: widget.avatarUrl,
        bio: widget.bio,
      );
    }

    // ถ้ามี doctorId แล้วค่อยดึงข้อมูลหมอ + เช็ค favorite
    if (_doctorId != null) {
      _doctor = await DoctorService.fetchDoctorById(_doctorId!);
      try {
        _fav = await FavoritesService.isFavorite(
          type: 'doctor',
          targetId: _doctorId!,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _loadingFav = false;
      });
    }
  }

  Future<void> _toggleFav(String label) async {
    if (_doctorId == null) return;
    final nowFav = await FavoritesService.toggle(
      type: 'doctor',
      targetId: _doctorId!,
      label: label,
    );
    if (!mounted) return;
    setState(() => _fav = nowFav);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              nowFav ? 'เพิ่มในรายการโปรดแล้ว' : 'เอาออกจากรายการโปรดแล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ใช้ข้อมูลแสดงผล: มีจาก DB ใช้ DB, ไม่มีก็ใช้ค่าเดิมที่ส่งมา
    final name = _doctor?.fullName ?? widget.name ?? '—';
    final title = _doctor?.title ?? widget.role ?? '';
    final subtitle = title.isEmpty
        ? (widget.specialty ?? '')
        : '$title${widget.specialty == null ? '' : ' • ${widget.specialty}'}';
    final phone = _doctor?.phone ?? widget.phone ?? '-';
    final email = _doctor?.email ?? widget.email ?? '-';
    final bio = _doctor?.bio ?? widget.bio ?? '—';
    final avatarUrl = _doctor?.avatarUrl ?? widget.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้เชี่ยวชาญ'),
        actions: [
          IconButton(
            onPressed: (_doctorId == null || _loadingFav)
                ? null
                : () => _toggleFav(name),
            icon: Icon(_fav ? Icons.favorite : Icons.favorite_border),
            color: _fav ? Colors.red : null,
            tooltip: _fav ? 'เอาออกจากรายการโปรด' : 'เพิ่มในรายการโปรด',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            _InfoTile(icon: Icons.phone, text: phone),
            const SizedBox(height: 8),
            _InfoTile(icon: Icons.email, text: email),
            const SizedBox(height: 12),

            _CardBox(child: Text(bio)),

            const SizedBox(height: 20),

            // ปุ่ม "จองคิว"
            ElevatedButton.icon(
              icon: const Icon(Icons.event_available),
              label: const Text('จองคิว'),
              onPressed: (_doctorId == null)
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DoctorBookingPage(
                            doctorId: _doctorId!,
                            doctorName: name,
                            phone: phone,
                            email: email,
                          ),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _TextHintSmall(),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

class _CardBox extends StatelessWidget {
  final Widget child;
  const _CardBox({required this.child});
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

  static const _thMonths = [
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
    final label = '${_thMonths[month.month - 1]} ${month.year}';
    return Row(children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final bool Function(DateTime day) isMine;
  final bool Function(DateTime day) isTaken;
  final void Function(DateTime day) onTapDay;

  const _CalendarGrid({
    required this.month,
    required this.isMine,
    required this.isTaken,
    required this.onTapDay,
  });

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = first.weekday % 7; // 0=Sun ... 6=Sat
    final days = last.day;

    final today = _normalize(DateTime.now());

    final cells = <Widget>[];

    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    cells.addAll(names.map((n) =>
        Center(child: Text(n, style: Theme.of(context).textTheme.bodySmall))));

    for (int i = 0; i < firstWeekday; i++) cells.add(const SizedBox());

    for (int d = 1; d <= days; d++) {
      final date = DateTime(month.year, month.month, d);
      final key = _normalize(date);

      final bool isPast = key.isBefore(today);
      final bool mine = isMine(key);
      final bool taken = isTaken(key);
      final bool booked = mine || taken;

      // สีพื้น/ตัวอักษร
      Color bg, dayFg;
      final border = Theme.of(context).dividerColor.withOpacity(.25);

      if (isPast) {
        // ✅ ย้อนหลัง → เทา และปิดการแตะ
        bg = Colors.grey.withOpacity(.10);
        dayFg = Colors.grey;
      } else if (booked) {
        // ✅ จองแล้ว (วันนี้/อนาคต) → แดง
        bg = Colors.red.withOpacity(.12);
        dayFg = Colors.red;
      } else {
        // ✅ ว่าง → เขียว
        bg = Colors.green.withOpacity(.12);
        dayFg = Colors.green.shade700;
      }

      cells.add(GestureDetector(
        onTap: isPast
            ? null
            : () => onTapDay(key), // ⛔ ปิดการแตะถ้าเป็นวันย้อนหลัง
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(
            '$d',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dayFg,
                ),
          ),
        ),
      ));
    }

    while (cells.length % 7 != 0) cells.add(const SizedBox());

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 0.80,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class DoctorBookingPage extends StatefulWidget {
  final String doctorId;
  final String? doctorName;
  final String? phone;
  final String? email;

  const DoctorBookingPage({
    super.key,
    required this.doctorId,
    this.doctorName,
    this.phone,
    this.email,
  });

  @override
  State<DoctorBookingPage> createState() => _DoctorBookingPageState();
}

class _DoctorBookingPageState extends State<DoctorBookingPage> {
  DateTime _month = DateTime.now();
  bool _loading = true;
  String? _error;
  Set<DateTime> _myBooked = {};
  Set<DateTime> _taken = {};

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
      final my = await DoctorService.myBookedDaysForMonth(
          doctorId: widget.doctorId, month: _month);
      final tk = await DoctorService.takenDaysForMonth(
          doctorId: widget.doctorId, month: _month);
      setState(() {
        _myBooked = my;
        _taken = tk;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book(DateTime day) async {
    try {
      await DoctorService.bookDay(doctorId: widget.doctorId, day: day);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('จองสำเร็จ')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('จองไม่สำเร็จ: $e')));
      }
    }
  }

  static DateTime _k(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'จองคิว${widget.doctorName != null ? ' • ${widget.doctorName}' : ''}'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // เดือน
          _MonthHeader(
            month: _month,
            onPrev: () {
              setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1));
              _load();
            },
            onNext: () {
              setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1));
              _load();
            },
          ),

          const SizedBox(height: 8),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text('โหลดตารางไม่สำเร็จ\n$_error',
                    textAlign: TextAlign.center),
              ),
            )
          else
            Expanded(
              child: _CalendarGrid(
                month: _month,
                isMine: (d) => _myBooked.contains(_k(d)),
                isTaken: (d) => _taken.contains(_k(d)),
                onTapDay: (d) {
                  final key = _k(d);
                  final today = _k(DateTime.now());

                  // ❌ ห้ามจอง/แก้ไขวันที่ย้อนหลัง
                  if (key.isBefore(today)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ไม่สามารถจองย้อนหลังได้')),
                    );
                    return;
                  }

                  final mine = _myBooked.contains(key);
                  final taken = _taken.contains(key);

                  if (mine) {
                    // ของเราเอง → อนุญาตให้ยกเลิก (ถ้าอยากบล็อกยกเลิกย้อนหลังด้วย ให้ย้าย if(isBefore) มาหลังส่วนนี้)
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('ยกเลิกการจอง?'),
                        content: Text(
                            'ยกเลิกวันที่ ${key.day}/${key.month}/${key.year}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('ปิด')),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await DoctorService.cancelMyBooking(
                                  doctorId: widget.doctorId, day: key);
                              await _load();
                            },
                            child: const Text('ยกเลิกจอง'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  if (!taken) _book(key); // ว่าง → จองได้
                },
              ),
            ),

          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Legend(color: Colors.green, label: 'ว่าง'),
                SizedBox(width: 12),
                _Legend(color: Colors.red, label: 'จองแล้ว'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TextHintSmall(),
          ),
          const SizedBox(height: 12),
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
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color))),
      const SizedBox(width: 6),
      Text(label),
    ]);
  }
}

class _TextHintSmall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'เนื้อหานี้ไม่ใช่คำแนะนำทางการแพทย์ หากมีความเสี่ยงต่อความปลอดภัย โปรดติดต่อผู้เชี่ยวชาญหรือสายด่วนใกล้คุณ',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
    );
  }
}

class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key});
  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  DateTime? selectedDate;
  String? selectedDoctorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จองคิวพบหมอ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- ตัวอย่าง UI เลือกวัน ----------
            ListTile(
              leading: const Icon(Icons.date_range),
              title: Text(selectedDate == null
                  ? 'เลือกวันนัด'
                  : 'วันนัด: ${_fmtThaiDate(selectedDate!)}'),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 8),

            // ---------- ตัวอย่าง UI เลือกหมอ ----------
            DropdownButtonFormField<String>(
              value: selectedDoctorId,
              decoration: const InputDecoration(
                labelText: 'เลือกคุณหมอ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: '00000000-0000-0000-0000-000000000001',
                    child: Text('หมอ A')),
                DropdownMenuItem(
                    value: '00000000-0000-0000-0000-000000000002',
                    child: Text('หมอ B')),
              ],
              onChanged: (v) => setState(() => selectedDoctorId = v),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('จองคิว'),
                onPressed: () async {
                  final DateTime? slotDate = selectedDate;
                  final String? doctorId = selectedDoctorId;

                  if (slotDate == null || doctorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กรุณาเลือกวันและคุณหมอ')),
                    );
                    return;
                  }

                  final id = await BookingHelper.confirmAndCreateBooking(
                    context: context,
                    slotDate: slotDate!, // ✅ ใช้ ! เพราะเช็ค null ไปแล้ว
                    doctorId: doctorId!, // ✅ ใช้ ! เช่นกัน
                  );

                  if (id != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('จองสำเร็จ')),
                    );
                    Navigator.pop(context); // หรือไปหน้าอื่นตามฟลว์ของคุณ
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtThaiDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';
