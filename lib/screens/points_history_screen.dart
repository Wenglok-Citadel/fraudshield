import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await SupabaseService.instance.pointsHistory(limit: 50);
    if (!mounted) return;
    setState(() {
      _history = res
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points History'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No history yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final item = _history[i];
                    final change = item['change'] as int;
                    final positive = change >= 0;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: positive
                              ? Colors.green[100]
                              : Colors.red[100],
                          child: Icon(
                            positive ? Icons.add : Icons.remove,
                            color: positive
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(item['reason'] ?? ''),
                        subtitle:
                            Text(item['created_at'].toString()),
                        trailing: Text(
                          '${positive ? '+' : ''}$change',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: positive
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
