import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/native_alarm_service.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = await NativeAlarmService.instance.getPermissionStatuses();
      if (mounted) {
        setState(() {
          _data = statuses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _section(String key) {
    final v = _data[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final readiness = _section('readiness');
    final device = _section('device');
    final level = readiness['level'] as String? ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions & Reliability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading && _data.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.softGold),
            )
          : RefreshIndicator(
              color: AppColors.softGold,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  _ReadinessBanner(level: level, readiness: readiness),
                  const SizedBox(height: 20),
                  _sectionTitle('Essential permissions'),
                  _PermissionCard(
                    title: 'Exact Alarms',
                    subtitle:
                        'Alarms & reminders — required for prayer-time scheduling that is not delayed by Doze.',
                    status: _section('exactAlarm'),
                    onEnable: () async {
                      await NativeAlarmService.instance.openExactAlarmSettings();
                    },
                  ),
                  _PermissionCard(
                    title: 'Do Not Disturb access',
                    subtitle:
                        'Required so Salah Silent can switch the ringer to silent and restore it safely.',
                    status: _section('notificationPolicy'),
                    onEnable: () async {
                      await NativeAlarmService.instance
                          .openNotificationPolicySettings();
                    },
                  ),
                  _PermissionCard(
                    title: 'Notification listener',
                    subtitle:
                        'Detects incoming and missed call notifications during silent sessions. '
                        'Does not read the call log or set Salah Silent as the dialer.',
                    status: _section('notificationListener'),
                    onEnable: () async {
                      await NativeAlarmService.instance
                          .openNotificationListenerSettings();
                    },
                  ),
                  _PermissionCard(
                    title: 'Notifications',
                    subtitle:
                        'App notifications (Android 13+ runtime permission and channel toggle).',
                    status: _section('postNotifications'),
                    onEnable: () async {
                      await NativeAlarmService.instance
                          .openAppNotificationSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Background reliability'),
                  _InfoCard(
                    title: 'Battery optimization',
                    status: _section('batteryOptimization'),
                    body: (_section('batteryOptimization')['note'] as String?) ??
                        'Check manually in system battery settings.',
                    buttonLabel: 'Open battery settings',
                    onOpen: () =>
                        NativeAlarmService.instance.openBatterySettings(),
                  ),
                  _InfoCard(
                    title: 'Autostart & background activity',
                    status: const {'status': 'check_manually'},
                    body: device['isXiaomiFamily'] == true
                        ? 'Xiaomi / POCO / Redmi: open Security or Settings and allow '
                            'Autostart for Salah Silent if the option exists. Menu names '
                            'vary by MIUI/HyperOS version — the app cannot change these for you.'
                        : 'Some devices restrict background apps. If alarms are delayed, '
                            'allow background activity for Salah Silent in system settings.',
                    buttonLabel: 'Open app details',
                    onOpen: () =>
                        NativeAlarmService.instance.openAppDetailsSettings(),
                  ),
                  _InfoCard(
                    title: 'Battery Saver',
                    status: const {'status': 'check_manually'},
                    body:
                        'When Battery Saver is on, Android may delay alarms. Prefer normal '
                        'power mode when reliable prayer silent timing matters.',
                    buttonLabel: null,
                    onOpen: null,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('This device'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${device['manufacturer'] ?? '—'} · ${device['model'] ?? '—'}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Android ${device['release'] ?? '?'} (API ${device['sdkInt'] ?? '?'})',
                            style: const TextStyle(
                              color: AppColors.mutedGrey,
                              fontSize: 13,
                            ),
                          ),
                          if (device['isXiaomiFamily'] == true) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'POCO / Xiaomi guidance',
                              style: TextStyle(
                                color: AppColors.softGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '• Enable Autostart for Salah Silent if listed\n'
                              '• Allow background activity when offered\n'
                              '• Keep exact alarms enabled\n'
                              '• Avoid aggressive Battery Saver during prayer hours\n'
                              '• After force-stop, open the app once so receivers work again',
                              style: TextStyle(
                                color: AppColors.mutedGrey,
                                height: 1.45,
                                fontSize: 13,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Keep exact alarms and Do Not Disturb access enabled. '
                              'If silent mode or alarms are delayed, review battery restrictions for this app.',
                              style: TextStyle(
                                color: AppColors.mutedGrey,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Salah Silent never claims 100% reliability. OEM battery policies can still delay work.',
                    style: TextStyle(
                      color: AppColors.mutedGrey,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.softGold,
            ),
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  final String level;
  final Map<String, dynamic> readiness;

  const _ReadinessBanner({required this.level, required this.readiness});

  @override
  Widget build(BuildContext context) {
    late Color border;
    late String title;
    late String body;
    switch (level) {
      case 'ready':
        border = AppColors.softGold;
        title = 'Ready';
        body =
            'Essential permissions for scheduling and silent mode are enabled.';
        break;
      case 'limited_reliability':
        border = Colors.orangeAccent;
        title = 'Limited reliability';
        body =
            'Essential permissions look OK, but battery restrictions may delay alarms.';
        break;
      case 'action_required':
      default:
        border = Colors.orangeAccent;
        title = 'Action required';
        body =
            'One or more essential permissions are missing. Enable them below.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: border,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: AppColors.mutedGrey, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, dynamic> status;
  final Future<void> Function() onEnable;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status['granted'] == true;
    final label = status['status']?.toString() ?? 'unknown';
    final display = switch (label) {
      'enabled' => 'Enabled',
      'not_enabled' => 'Not enabled',
      'restricted' => 'Restricted',
      'not_applicable' => 'Not applicable',
      _ => 'Unknown',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  granted ? Icons.check_circle : Icons.error_outline,
                  size: 20,
                  color: granted ? AppColors.softGold : Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              display,
              style: TextStyle(
                color: granted ? AppColors.softGold : Colors.orangeAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.mutedGrey,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (!granted) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await onEnable();
                  },
                  child: const Text('Open Settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> status;
  final String body;
  final String? buttonLabel;
  final Future<void> Function()? onOpen;

  const _InfoCard({
    required this.title,
    required this.status,
    required this.body,
    required this.buttonLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final st = status['status']?.toString() ?? 'check_manually';
    final statusLabel = switch (st) {
      'unrestricted' => 'Unrestricted (API)',
      'optimized' => 'Optimized / restricted (API)',
      'unknown' => 'Unknown',
      _ => 'Check manually',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusLabel,
              style: const TextStyle(color: AppColors.mutedGrey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.mutedGrey,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (buttonLabel != null && onOpen != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async => onOpen!(),
                  child: Text(buttonLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
