import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/native_alarm_service.dart';
import '../../services/prayer_schedule_service.dart';
import '../../widgets/duration_selector.dart';
import '../schedule/schedule_screen.dart';
import '../permission_setup/permission_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PrayerScheduleService _service;
  Map<String, dynamic> _alarmStatus = {};
  bool _statusLoading = true;

  @override
  void initState() {
    super.initState();
    _service = PrayerScheduleController.instance;
    _service.addListener(_onUpdate);
    _loadAlarmStatus();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAlarmStatus() async {
    setState(() => _statusLoading = true);
    final status = await NativeAlarmService.instance.getStatus();
    if (mounted) {
      setState(() {
        _alarmStatus = status;
        _statusLoading = false;
      });
    }
  }

  Future<void> _refreshAlarms() async {
    setState(() => _statusLoading = true);
    final status = await _service.refreshNativeAlarms();
    if (mounted) {
      setState(() {
        _alarmStatus = status;
        _statusLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prayer alarms refreshed'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
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
      await _loadAlarmStatus();
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

  String _formatEpoch(dynamic epoch) {
    if (epoch == null) return '—';
    final ms = epoch is int ? epoch : int.tryParse(epoch.toString());
    if (ms == null || ms <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('EEE d MMM, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final exactGranted = _alarmStatus['exactAlarmGranted'] == true;
    final activeCount = _alarmStatus['activeAlarmCount'] ?? 0;
    final nextName = _alarmStatus['nextPrayerName'];
    final nextAt = _alarmStatus['nextTriggerEpochMillis'];
    final lastRefresh = _alarmStatus['lastRefreshEpochMillis'];
    final lastError = _alarmStatus['lastError'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Card(
            child: ListTile(
              leading: const Icon(Icons.security_outlined, color: AppColors.softGold),
              title: const Text('Permissions & Reliability'),
              subtitle: const Text(
                'Exact alarms, DND, notification access, battery',
                style: TextStyle(color: AppColors.mutedGrey, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.mutedGrey),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PermissionSetupScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Alarm scheduling',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Exact alarm permission'),
                  subtitle: Text(
                    exactGranted
                        ? 'Granted — exact alarms available'
                        : 'Not granted — open Settings to allow Alarms & reminders',
                    style: TextStyle(
                      color: exactGranted
                          ? AppColors.mutedGrey
                          : Colors.orangeAccent,
                    ),
                  ),
                  trailing: exactGranted
                      ? const Icon(Icons.check_circle, color: AppColors.softGold)
                      : TextButton(
                          onPressed: () async {
                            await NativeAlarmService.instance
                                .openExactAlarmSettings();
                            await Future.delayed(const Duration(seconds: 1));
                            await _loadAlarmStatus();
                          },
                          child: const Text('Grant'),
                        ),
                ),
                const Divider(height: 1, color: AppColors.surface),
                ListTile(
                  title: const Text('Active prayer alarms'),
                  subtitle: Text(
                    _statusLoading ? 'Loading…' : '$activeCount scheduled',
                    style: const TextStyle(color: AppColors.mutedGrey),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surface),
                ListTile(
                  title: const Text('Next scheduled Salah'),
                  subtitle: Text(
                    nextName == null
                        ? 'None (enable a prayer in Schedule)'
                        : '$nextName · ${_formatEpoch(nextAt)}',
                    style: const TextStyle(color: AppColors.mutedGrey),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surface),
                ListTile(
                  title: const Text('Last scheduling update'),
                  subtitle: Text(
                    _formatEpoch(lastRefresh),
                    style: const TextStyle(color: AppColors.mutedGrey),
                  ),
                ),
                if (lastError != null && lastError.isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.surface),
                  ListTile(
                    title: const Text('Scheduling error'),
                    subtitle: Text(
                      lastError,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                ],
                const Divider(height: 1, color: AppColors.surface),
                ListTile(
                  title: const Text('Refresh prayer schedules'),
                  subtitle: const Text(
                    'Re-register all enabled alarms from saved times',
                    style: TextStyle(color: AppColors.mutedGrey, fontSize: 12),
                  ),
                  trailing: _statusLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.softGold,
                          ),
                        )
                      : const Icon(Icons.refresh, color: AppColors.softGold),
                  onTap: _statusLoading ? null : _refreshAlarms,
                ),
              ],
            ),
          ),
          if (!exactGranted) ...[
            const SizedBox(height: 8),
            const Text(
              'Without exact alarm permission, Android may delay prayer '
              'alarms by several minutes (inexact). Grant “Alarms & reminders” '
              'in Special app access for reliable timing.',
              style: TextStyle(color: AppColors.mutedGrey, fontSize: 12, height: 1.4),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Silent mode access',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: NativeAlarmService.instance.checkNotificationPolicyAccess(),
            builder: (context, snap) {
              final granted = snap.data == true;
              return Card(
                child: ListTile(
                  title: const Text('Do Not Disturb access'),
                  subtitle: Text(
                    granted
                        ? 'Granted — ringer silent mode can be applied'
                        : 'Required on many devices for reliable silence',
                    style: TextStyle(
                      color: granted ? AppColors.mutedGrey : Colors.orangeAccent,
                    ),
                  ),
                  trailing: granted
                      ? const Icon(Icons.check_circle, color: AppColors.softGold)
                      : TextButton(
                          onPressed: () async {
                            await NativeAlarmService.instance
                                .openNotificationPolicySettings();
                          },
                          child: const Text('Grant'),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
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
            'Notification preferences',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 8),
          const _NotificationPrefsCard(),
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
                'Milestone 5 · Notifications, Jumuah and call history\n'
                'Silent mode activation arrives in Milestone 3.',
                style: TextStyle(color: AppColors.mutedGrey, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _NotificationPrefsCard extends StatefulWidget {
  const _NotificationPrefsCard();

  @override
  State<_NotificationPrefsCard> createState() => _NotificationPrefsCardState();
}

class _NotificationPrefsCardState extends State<_NotificationPrefsCard> {
  Map<String, dynamic> _prefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await NativeAlarmService.instance.getNotificationPrefs();
    if (mounted) setState(() { _prefs = p; _loading = false; });
  }

  Future<void> _set(String key, bool value) async {
    final next = {
      'silentActivated': _prefs['silentActivated'] == true,
      'callDuringSalah': _prefs['callDuringSalah'] == true,
      'sessionRestore': _prefs['sessionRestore'] == true,
      'permissionWarning': _prefs['permissionWarning'] == true,
    };
    next[key] = value;
    final updated = await NativeAlarmService.instance.setNotificationPrefs(next);
    if (mounted) setState(() => _prefs = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(child: ListTile(title: Text('Loading…')));
    }
    Widget tile(String key, String title, String subtitle) {
      return SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.mutedGrey, fontSize: 12)),
        value: _prefs[key] != false,
        activeColor: AppColors.softGold,
        onChanged: (v) => _set(key, v),
      );
    }
    return Card(
      child: Column(
        children: [
          tile('silentActivated', 'Silent activation', 'When a Salah silent session starts'),
          const Divider(height: 1, color: AppColors.surface),
          tile('callDuringSalah', 'Calls during Salah', 'When a call notification is detected'),
          const Divider(height: 1, color: AppColors.surface),
          tile('sessionRestore', 'Session restore', 'When sound is restored or restore is skipped'),
          const Divider(height: 1, color: AppColors.surface),
          tile('permissionWarning', 'Permission warnings', 'Occasional alerts if access is missing'),
        ],
      ),
    );
  }
}
