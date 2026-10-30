import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/native_alarm_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await NativeAlarmService.instance.getCallHistory();
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Clear call history?'),
        content: const Text(
          'This removes all detected call notifications stored by Salah Silent.',
          style: TextStyle(color: AppColors.mutedGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.softGold),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NativeAlarmService.instance.clearCallHistory();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _clear),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softGold))
          : RefreshIndicator(
              color: AppColors.softGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Records come from call notifications visible to the notification '
                      'listener during an active silent session. This is not a full call log '
                      'and does not use READ_CALL_LOG.',
                      style: TextStyle(color: AppColors.mutedGrey, fontSize: 12, height: 1.4),
                    ),
                  ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No call notifications recorded yet',
                          style: TextStyle(color: AppColors.mutedGrey),
                        ),
                      ),
                    )
                  else
                    ..._items.map((item) {
                      final ts = item['timestamp'];
                      final when = ts is int
                          ? DateFormat('EEE d MMM · h:mm a')
                              .format(DateTime.fromMillisecondsSinceEpoch(ts))
                          : '—';
                      final prayer = (item['prayerName'] as String?)?.trim();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            (item['caller'] as String?) ?? 'Unknown Caller',
                            style: const TextStyle(color: AppColors.white),
                          ),
                          subtitle: Text(
                            '${item['callType'] ?? 'incoming'}'
                            '${prayer != null && prayer.isNotEmpty ? ' · $prayer' : ''}'
                            '${item['duringSilent'] == true ? ' · during silent' : ''}\n'
                            '$when',
                            style: const TextStyle(color: AppColors.mutedGrey, height: 1.35),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.mutedGrey),
                            onPressed: () async {
                              final id = item['id'] as String?;
                              if (id != null) {
                                await NativeAlarmService.instance.deleteCallHistoryItem(id);
                                await _load();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
