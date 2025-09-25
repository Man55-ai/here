import 'package:flutter/material.dart';
import 'favorites_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await FavoritesService.fetchAll();
    if (mounted)
      setState(() {
        _items = rows;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายการโปรด')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? const ListTile(
                    title: Text('ยังไม่มีรายการโปรด'),
                    subtitle: Text('ลองกดหัวใจจากหน้าหมอหรือหน้าคุยกับ AI'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final type = (it['type'] ?? '') as String;
                      final label = (it['label'] ?? it['target_id']) as String;

                      IconData icon;
                      String subtitle;
                      VoidCallback? onTap;

                      if (type == 'doctor') {
                        icon = Icons.medical_services_outlined;
                        subtitle = 'ผู้เชี่ยวชาญ';
                        onTap = () {
                          Navigator.pushNamed(
                            context,
                            '/doctor',
                            arguments: {'id': it['target_id'] as String},
                          );
                        };
                      } else {
                        icon = Icons.forum_outlined;
                        subtitle = 'แชท AI';
                        onTap = () {
                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {'threadId': it['target_id'] as String},
                          );
                        };
                      }

                      return Card(
                        child: ListTile(
                          leading: Icon(icon),
                          title: Text(label),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () async {
                              await FavoritesService.toggle(
                                type: type,
                                targetId: it['target_id'] as String,
                              );
                              _load();
                            },
                          ),
                          onTap: onTap,
                        ),
                      );
                    },
                  )),
      ),
    );
  }
}
