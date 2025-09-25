// lib/mood_service.dart
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, RealtimeChannel;
import 'package:supabase/supabase.dart'
    show PostgresChangeEvent, PostgresChangeFilter;

/// โมเดลเก็บค่ามูดรายวัน
class MoodEntry {
  final DateTime date;
  final int mood;
  MoodEntry({required this.date, required this.mood});
}

class MoodService {
  static final _sp = Supabase.instance.client;
  static String? get _uid => _sp.auth.currentUser?.id;

  /// แปลงวันเป็น 'YYYY-MM-DD' ปลอดภัยเรื่อง timezone
  static String _d(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// อ่านค่ามูดของเดือน (เรียงจากวันที่น้อย→มาก)
  static Future<List<MoodEntry>> fetchByMonth(int year, int month) async {
    final uid = _uid;
    if (uid == null) return [];
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);

    final rows = await _sp
        .from('mood_history')
        .select()
        .eq('user_id', uid)
        .gte('date', _d(first))
        .lte('date', _d(last))
        .order('date', ascending: true);

    return (rows as List)
        .map((r) => MoodEntry(
              date: DateTime.parse(r['date'] as String),
              mood: (r['mood'] as num).toInt(),
            ))
        .toList();
  }

  /// อัปเดต/บันทึกมูดย้อนหลัง (คีย์ซ้ำวันเดิมจะถูกอัปเดต)
  static Future<void> upsertForDate(DateTime when, int mood) async {
    final uid = _uid;
    if (uid == null) return;
    final day = _d(DateTime(when.year, when.month, when.day));
    await _sp.from('mood_history').upsert(
      {'user_id': uid, 'date': day, 'mood': mood},
      onConflict: 'user_id,date',
    );
  }

  /// วันนี้แบบเร็ว ๆ
  static Future<void> upsertToday(int mood) =>
      upsertForDate(DateTime.now(), mood);

  /// สมัคร realtime: มีการเปลี่ยนแปลงมูดของ "ผู้ใช้คนนี้" ให้เรียก onChange()
  static RealtimeChannel? subscribeMyMoodHistory(void Function() onChange) {
    final uid = _uid;
    if (uid == null) return null;

    final ch = _sp.channel('realtime:mood_history:$uid');

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mood_history',
          callback: (payload) {
            // กรองเฉพาะแถวของ user นี้เอง
            final row = payload.newRecord ?? payload.oldRecord ?? {};
            if (row['user_id'] == uid) onChange();
          },
        )
        .subscribe();

    return ch;
  }
}
