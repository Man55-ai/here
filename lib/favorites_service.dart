import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService {
  static final _sp = Supabase.instance.client;
  static String? get _uid => _sp.auth.currentUser?.id;

  /// เช็คว่าเป็นรายการโปรดไหม
  static Future<bool> isFavorite({
    required String type, // 'doctor' | 'thread'
    required String targetId,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _sp
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('type', type)
        .eq('target_id', targetId)
        .maybeSingle();
    return row != null;
  }

  /// toggle: ถ้าไม่มี -> เพิ่ม, ถ้ามี -> ลบ
  static Future<bool> toggle({
    required String type,
    required String targetId,
    String? label,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    final isFav = await isFavorite(type: type, targetId: targetId);
    if (!isFav) {
      await _sp.from('favorites').insert({
        'user_id': uid,
        'type': type,
        'target_id': targetId,
        if (label != null) 'label': label,
      });
      return true;
    } else {
      await _sp
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('type', type)
          .eq('target_id', targetId);
      return false;
    }
  }

  /// ดึงลิสต์รายการโปรดทั้งหมดของผู้ใช้
  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _sp
        .from('favorites')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
