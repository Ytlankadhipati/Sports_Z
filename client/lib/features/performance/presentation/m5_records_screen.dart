import 'package:flutter/material.dart';
import '../data/m5_repository.dart';

/// Shared read-only list shell used by M5's record, evidence and verification hubs.
/// Detailed create/edit forms should use M1's sport config and M2's ConfigFormRenderer.
class M5RecordsScreen extends StatefulWidget {
  const M5RecordsScreen({super.key, required this.title, required this.load});
  final String title;
  final Future<List<dynamic>> Function(M5Repository repository) load;
  @override State<M5RecordsScreen> createState() => _M5RecordsScreenState();
}
class _M5RecordsScreenState extends State<M5RecordsScreen> {
  final repo = M5Repository();
  late Future<List<dynamic>> future;
  @override void initState() { super.initState(); future = widget.load(repo); }
  Future<void> refresh() async { setState(() => future = widget.load(repo)); await future; }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<List<dynamic>>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline), const SizedBox(height: 8), const Text('Could not load data.'),
        TextButton(onPressed: refresh, child: const Text('Retry')),
      ]));
      final rows = snap.data ?? [];
      if (rows.isEmpty) return const Center(child: Text('Nothing here yet. Add your first record.'));
      return RefreshIndicator(onRefresh: refresh, child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
        itemCount: rows.length, separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) { final row = Map<String, dynamic>.from(rows[index] as Map);
          final title = row['title'] ?? row['metric_key'] ?? row['filename'] ?? row['domain'] ?? 'Record';
          final subtitle = row['verification_status'] ?? row['status'] ?? row['recorded_at']?.toString() ?? '';
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.sports)), title: Text('$title'), subtitle: Text('$subtitle'));
        },
      ));
    }),
  );
}
