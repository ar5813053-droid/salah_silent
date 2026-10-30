import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/prayer_schedule_service.dart';
import '../../widgets/duration_selector.dart';
import '../schedule/schedule_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PrayerScheduleService _service;

  @override
  void initState() {
    super.initState();
    _service = PrayerScheduleController.instance;
    _service.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  Future<void> _changeDefaultDuration() async {
    await DurationSelector.show(
      context,
      currentMinutes: _service.defaultDurationMinutes,
      onSelected: (m) => _service.setDefaultDuration(m),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Reset prayer timings?'),
        content: const Text(
          'This restores example default times, enables all five prayers, '
          'and applies your global default silent duration.\n\n'
          'Call history and other data are not deleted.',
          style: TextStyle(color: AppColors.mutedGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.softGold),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prayer timings reset to example defaults'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Schedule',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Default silent duration'),
                  subtitle: Text(
                    '${_service.defaultDurationMinutes} minutes '
                    '(for new / reset prayers)',
                    style: const TextStyle(color: AppColors.mutedGrey),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.mutedGrey),
                  onTap: _changeDefaultDuration,
                ),
                const Divider(height: 1, color: AppColors.surface),
                ListTile(
                  title: const Text('Reset prayer timings'),
                  subtitle: const Text(
                    'Restore example defaults · does not clear call history',
                    style: TextStyle(color: AppColors.mutedGrey, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.restart_alt,
                      color: AppColors.mutedGrey),
                  onTap: _confirmReset,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              title: Text('Salah Silent'),
              subtitle: Text(
                'Milestone 1 · Prayer Schedule + SQLite\n'
                'Times are user-configured examples only.',
                style: TextStyle(color: AppColors.mutedGrey, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
