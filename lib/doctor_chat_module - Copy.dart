import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_uikit/agora_uikit.dart';

// ============== AGORA CONFIG (ใส่ค่าจริงก่อนทดสอบ) ==========
const String kAgoraAppId = 'YOUR_AGORA_APP_ID';
const String? kAgoraTempToken =
    null; // dev ชั่วคราว; โปรดักชันควรใช้ Token Server
// ============================================================

// Supabase client + helper
final SupabaseClient _sb = Supabase.instance.client;
String? get _uid => _sb.auth.currentUser?.id;

// ====================== MODELS =============================
class Booking {
  final String id;
  final String userId;
  final String doctorId;
  final DateTime slotDate; // คอลัมน์ DATE
  final String fullName;
  final String phone;
  final String status;

  Booking({
    required this.id,
    required this.userId,
    required this.doctorId,
    required this.slotDate,
    required this.fullName,
    required this.phone,
    required this.status,
  });

  factory Booking.fromMap(Map m) => Booking(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        doctorId: m['doctor_id'] as String,
        // Supabase จะส่ง DATE กลับมาเป็นสตริง -> parse ได้เลย (ตีความเป็น 00:00)
        slotDate: DateTime.parse(m['slot_date'] as String).toLocal(),
        fullName: (m['full_name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        status: (m['status'] ?? 'booked') as String,
      );
}

class DocChat {
  final String id;
  final String bookingId;
  final String senderId;
  final String role; // 'user' | 'doctor'
  final String text;
  final DateTime createdAt;

  DocChat({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  factory DocChat.fromMap(Map m) => DocChat(
        id: m['id'] as String,
        bookingId: m['booking_id'] as String,
        senderId: m['sender_id'] as String,
        role: (m['role'] ?? 'user') as String,
        text: (m['text'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
// ============================================================

// ===================== DB SERVICE ==========================
class DoctorDB {
  static String _fmtYmd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// ดึง "นัดล่าสุดตั้งแต่วันนี้ขึ้นไป" ของผู้ใช้
  static Future<Booking?> fetchLatestBooking() async {
    final userId = _uid;
    if (userId == null) return null;

    final today = DateTime.now();
    final ymd = DateTime(today.year, today.month, today.day);

    final rows = await _sb
        .from('doctor_bookings')
        .select()
        .eq('user_id', userId)
        .inFilter('status', ['booked', 'confirmed'])
        .gte('slot_date', _fmtYmd(ymd)) // DATE → 'YYYY-MM-DD'
        .order('slot_date', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return Booking.fromMap(rows.first as Map);
  }

  static Future<String> createBooking({
    required DateTime slotDate, // ใช้เฉพาะวัน
    required String doctorId,
    required String fullName,
    required String phone,
  }) async {
    final userId = _uid;
    if (userId == null) throw Exception('Not signed in');

    final data = await _sb
        .from('doctor_bookings')
        .insert({
          'user_id': userId,
          'doctor_id': doctorId,
          'slot_date':
              _fmtYmd(DateTime(slotDate.year, slotDate.month, slotDate.day)),
          'full_name': fullName,
          'phone': phone,
          'status': 'booked',
        })
        .select()
        .single();

    return data['id'] as String;
  }

  static Stream<List<DocChat>> chatStream(String bookingId) {
    return _sb
        .from('doctor_messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at')
        .map((rows) => rows.map((e) => DocChat.fromMap(e as Map)).toList());
  }

  static Future<void> sendChat({
    required String bookingId,
    required String text,
  }) async {
    final userId = _uid;
    if (userId == null) throw Exception('Not signed in');

    await _sb.from('doctor_messages').insert({
      'booking_id': bookingId,
      'sender_id': userId,
      'role': 'user',
      'text': text,
    });
  }
}
// ============================================================

// =================== BOOKING HELPER ========================
class BookingHelper {
  /// เด้งฟอร์ม "ชื่อ-นามสกุล + เบอร์" ก่อน insert ลง doctor_bookings
  static Future<String?> confirmAndCreateBooking({
    required BuildContext context,
    required DateTime slotDate,
    required String doctorId,
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('กรอกข้อมูลก่อนจอง'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                ),
                const SizedBox(height: 8),
                Text('วันนัด: ${_fmtThaiDate(slotDate)}'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ยกเลิก')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('ยืนยันจอง')),
            ],
          ),
        ) ??
        false;

    if (!ok) return null;

    final fullName = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (fullName.isEmpty || phone.length < 9) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรอกชื่อ-นามสกุล และเบอร์ให้ถูกต้อง')),
        );
      }
      return null;
    }

    final id = await DoctorDB.createBooking(
      slotDate: slotDate,
      doctorId: doctorId,
      fullName: fullName,
      phone: phone,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('จองสำเร็จ')));
    }
    return id;
  }
}
// ============================================================

// =================== DRAWER MENU TILE ======================
class DoctorChatMenuTile extends StatelessWidget {
  const DoctorChatMenuTile({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Booking?>(
      future: DoctorDB.fetchLatestBooking(),
      builder: (ctx, snap) {
        final hasBooking = (snap.data != null);
        return ListTile(
          leading: const Icon(Icons.medical_services_outlined),
          title: const Text('คุยกับหมอ'),
          enabled: hasBooking,
          onTap: hasBooking
              ? () => Navigator.of(context).pushNamed('/doctorChat')
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ยังไม่มีคิว ไปจองคิวก่อนนะ')),
                  ),
        );
      },
    );
  }
}
// ============================================================

// =================== HUB PAGE + TABS =======================
class DoctorChatHubPage extends StatefulWidget {
  const DoctorChatHubPage({super.key});
  @override
  State<DoctorChatHubPage> createState() => _DoctorChatHubPageState();
}

class _DoctorChatHubPageState extends State<DoctorChatHubPage> {
  Booking? _booking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await DoctorDB.fetchLatestBooking();
    setState(() {
      _booking = b;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_booking == null) {
      return _EmptyState(
        title: 'ยังไม่มีคิว',
        subtitle: 'ไปจองคิวก่อนเพื่อเปิดแชทคุยกับหมอ',
        action: () => Navigator.pushNamed(context, '/booking'),
      );
    }

    final b = _booking!;
    // อนุญาตเมื่อถึง "วันนัด"
    final today = DateTime.now();
    final ready = !DateTime(today.year, today.month, today.day)
        .isBefore(DateTime(b.slotDate.year, b.slotDate.month, b.slotDate.day));

    if (!ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('คุยกับหมอ')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available, size: 48),
              const SizedBox(height: 8),
              Text('วันนัดของคุณ: ${_fmtThaiDate(b.slotDate)}'),
              const SizedBox(height: 4),
              const Text('ถึงวันนัดแล้วจะเปิดให้แชท/โทรได้อัตโนมัติ'),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('คุยกับหมอ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'แชท'),
              Tab(text: 'โทรเสียง'),
              Tab(text: 'วิดีโอคอล')
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TextChatTab(bookingId: b.id),
            _VoiceCallTab(channelName: b.id),
            _VideoCallTab(channelName: b.id),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback action;
  const _EmptyState(
      {required this.title, required this.subtitle, required this.action});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คุยกับหมอ')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton(onPressed: action, child: const Text('ไปจองคิว')),
          ],
        ),
      ),
    );
  }
}

String _fmtThaiDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${(d.year + 543)}';

// ---------------------- Text Chat ------------------------
class _TextChatTab extends StatefulWidget {
  final String bookingId;
  const _TextChatTab({required this.bookingId});
  @override
  State<_TextChatTab> createState() => _TextChatTabState();
}

class _TextChatTabState extends State<_TextChatTab> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<DocChat>>(
            stream: DoctorDB.chatStream(widget.bookingId),
            builder: (ctx, snap) {
              final msgs = snap.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m.senderId == _uid;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            mine ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.role == 'doctor' ? 'หมอ' : 'ฉัน',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700)),
                          Text(m.text),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'พิมพ์ข้อความ...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final t = _ctrl.text.trim();
                  if (t.isEmpty) return;
                  await DoctorDB.sendChat(bookingId: widget.bookingId, text: t);
                  _ctrl.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------- Voice Call (Agora) ---------------
class _VoiceCallTab extends StatefulWidget {
  final String channelName;
  const _VoiceCallTab({required this.channelName});
  @override
  State<_VoiceCallTab> createState() => _VoiceCallTabState();
}

class _VoiceCallTabState extends State<_VoiceCallTab> {
  late AgoraClient _client;

  @override
  void initState() {
    super.initState();
    _client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: kAgoraAppId,
        channelName: widget.channelName,
        tempToken: kAgoraTempToken,
      ),
      enabledPermission: const [Permission.microphone],
    );
    _client.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AgoraVideoViewer(
          client: _client,
          layoutType: Layout.oneToOne,
          enableHostControls: true,
          showNumberOfUsers: true,
          disabledVideoWidget:
              const Center(child: Icon(Icons.headset_mic, size: 64)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AgoraVideoButtons(
            client: _client,
            addScreenSharing: false,
            enabledButtons: const [
              BuiltInButtons.toggleMic,
              BuiltInButtons.toggleCamera,
              BuiltInButtons.switchCamera,
              BuiltInButtons.callEnd,
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------- Video Call (Agora) ---------------
class _VideoCallTab extends StatefulWidget {
  final String channelName;
  const _VideoCallTab({required this.channelName});
  @override
  State<_VideoCallTab> createState() => _VideoCallTabState();
}

class _VideoCallTabState extends State<_VideoCallTab> {
  late AgoraClient _client;

  @override
  void initState() {
    super.initState();
    _client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: kAgoraAppId,
        channelName: widget.channelName,
        tempToken: kAgoraTempToken,
      ),
      enabledPermission: const [Permission.microphone, Permission.camera],
    );
    _client.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AgoraVideoViewer(
          client: _client,
          layoutType: Layout.oneToOne,
          enableHostControls: true,
          showNumberOfUsers: true,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AgoraVideoButtons(client: _client),
        ),
      ],
    );
  }
}
