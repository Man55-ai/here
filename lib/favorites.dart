// lib/favorites.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// -------- Model --------
class FavoriteItem {
  final String id;
  final String type; // 'doctor' | 'thread' | 'journal'
  final String itemId; // target id
  final String? title;
  final String? subtitle;
  final String? image;

  FavoriteItem({
    required this.id,
    required this.type,
    required this.itemId,
    this.title,
    this.subtitle,
    this.image,
  });

  factory FavoriteItem.fromMap(Map<String, dynamic> m) => FavoriteItem(
        id: m['id'] as String,
        type: m['item_type'] as String,
        itemId: m['item_id'] as String,
        title: m['item_title'] as String?,
        subtitle: m['item_subtitle'] as String?,
        image: m['item_image'] as String?,
      );
}

/// -------- Service --------
class FavoritesService {
  static final _sp = Supabase.instance.client;
  static String? get _uid => _sp.auth.currentUser?.id;

  static Future<bool> isFavorite({
    required String type,
    required String itemId,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _sp
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('item_type', type)
        .eq('item_id', itemId)
        .maybeSingle();
    return row != null;
  }

  static Future<void> toggle({
    required String type,
    required String itemId,
    String? title,
    String? subtitle,
    String? image,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final existing = await _sp
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('item_type', type)
        .eq('item_id', itemId)
        .maybeSingle();

    if (existing == null) {
      await _sp.from('favorites').insert({
        'user_id': uid,
        'item_type': type,
        'item_id': itemId,
        'item_title': title,
        'item_subtitle': subtitle,
        'item_image': image,
      });
    } else {
      await _sp.from('favorites').delete().eq('id', existing['id']);
    }
  }

  static Future<List<FavoriteItem>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _sp
        .from('favorites')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => FavoriteItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// realtime (optional)
  static RealtimeChannel? subscribe(void Function() onChange) {
    final uid = _uid;
    if (uid == null) return null;
    final ch = _sp.channel('realtime:favorites:$uid');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'favorites',
          callback: (payload) {
            final row = payload.newRecord ?? payload.oldRecord ?? {};
            if (row['user_id'] == uid) onChange();
          },
        )
        .subscribe();
    return ch;
  }
}

/// -------- Favorites Page (tabs: Doctors / Chats) --------
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<FavoriteItem> _items = [];
  RealtimeChannel? _ch;

  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
    _ch = FavoritesService.subscribe(() {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final rows = await FavoritesService.fetchAll();
      setState(() => _items = rows);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final doctors = _items.where((e) => e.type == 'doctor').toList();
    final threads = _items.where((e) => e.type == 'thread').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการโปรดของฉัน'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'ผู้เชี่ยวชาญ'),
            Tab(text: 'แชทที่ปักหมุด'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('โหลดไม่สำเร็จ\n$_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _FavList(
                        items: doctors,
                        emptyText: 'ยังไม่มีผู้เชี่ยวชาญที่กดถูกใจ',
                        onTap: (it) {
                          // ไปหน้าโปรไฟล์หมอ
                          Navigator.of(context).pushNamed(
                            '/doctor',
                            arguments: {'id': it.itemId},
                          );
                        },
                        onDelete: (it) async {
                          await FavoritesService.toggle(
                            type: it.type,
                            itemId: it.itemId,
                          );
                          _load();
                        },
                      ),
                      _FavList(
                        items: threads,
                        emptyText: 'ยังไม่มีห้องแชทที่ปักหมุด',
                        onTap: (it) {
                          // ไปหน้าแชท/ประวัติ
                          Navigator.of(context).pushNamed(
                            '/chat', // เปลี่ยนตาม route ที่คุณใช้เปิด thread
                            arguments: {'threadId': it.itemId},
                          );
                        },
                        onDelete: (it) async {
                          await FavoritesService.toggle(
                            type: it.type,
                            itemId: it.itemId,
                          );
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        label: const Text('รีเฟรช'),
        icon: const Icon(Icons.refresh),
        backgroundColor: cs.primary,
      ),
    );
  }
}

class _FavList extends StatelessWidget {
  final List<FavoriteItem> items;
  final String emptyText;
  final void Function(FavoriteItem) onTap;
  final Future<void> Function(FavoriteItem) onDelete;

  const _FavList({
    required this.items,
    required this.emptyText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(emptyText)),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final it = items[i];
        return Dismissible(
          key: ValueKey(it.id),
          background: Container(
            color: Colors.red.withOpacity(.1),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await onDelete(it);
            return true;
          },
          child: ListTile(
            onTap: () => onTap(it),
            leading: CircleAvatar(
              backgroundImage: (it.image != null && it.image!.isNotEmpty)
                  ? NetworkImage(it.image!)
                  : null,
              child: (it.image == null || it.image!.isEmpty)
                  ? const Icon(Icons.favorite)
                  : null,
            ),
            title: Text(it.title ?? it.itemId),
            subtitle: it.subtitle == null ? null : Text(it.subtitle!),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
