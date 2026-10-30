import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../widgets/glass.dart';
import '../../services/stats_service.dart';
import '../../services/native_alarm_service.dart';
import '../../services/prayer_schedule_service.dart';
import '../schedule/schedule_screen.dart';
import '../permission_setup/permission_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('com.salahsilent.app/native');
  late final PrayerScheduleService _service;
  Timer? _ticker;
  String _nativeStatus = '';
  Duration? _remaining;
  Map<String, dynamic> _session = {};
  Map<String, dynamic> _readiness = {};
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _service = PrayerScheduleController.instance;
    _service.addListener(_onServiceUpdate);
    _pingNative();
    _refreshSession();
    _remaining = _service.remainingUntilNext();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _service.remainingUntilNext();
        if (_session['active'] == true) {
          final end = _session['endEpoch'];
          if (end is int) {
            final left = end - DateTime.now().millisecondsSinceEpoch;
            _session = Map<String, dynamic>.from(_session)
              ..['remainingMillis'] = left.clamp(0, 1 << 62);
            if (left <= 0) {
              _refreshSession();
            }
          }
        }
      });
    });
    _eventSub = NativeAlarmService.instance.onAlarmFired.listen((event) {
      final type = event['type'];
      if (type == 'silent_activated') {
        final mins = event['durationMinutes'];
        StatsService.instance.recordSession(mins is int ? mins : 10);
      } else if (type == 'silent_restored') {
        StatsService.instance.recordRestore(skipped: false);
      } else if (type == 'restoration_skipped') {
        StatsService.instance.recordRestore(skipped: true);
      }
      if (type == 'silent_activated' ||
          type == 'session_extended' ||
          type == 'silent_restored' ||
          type == 'restoration_skipped' ||
          type == 'prayer_alarm') {
        _refreshSession();
      }
    });
  }

  Future<void> _refreshSession() async {
    final status = await NativeAlarmService.instance.getSilentSessionStatus();
    final ready = await NativeAlarmService.instance.getReadinessSummary();
    if (mounted) {
      setState(() {
        _session = status;
        _readiness = ready;
      });
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      _remaining = _service.remainingUntilNext();
    });
  }

  Future<void> _pingNative() async {
    try {
      final result = await _channel.invokeMethod('pingSilentSessionManager');
      if (mounted) setState(() => _nativeStatus = result.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _nativeStatus = 'Native bridge OK');
      }
    }
  }

  Future<void> _confirmRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Restore sound now?'),
        content: const Text(
          'This ends the active silent session and restores the previous '
          'sound state if it is still safe to do so.',
          style: TextStyle(color: AppColors.mutedGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.softGold),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NativeAlarmService.instance.cancelSilentSession();
      await _refreshSession();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silent session ended'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _eventSub?.cancel();
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  String _formatCountdown(Duration? d) {
    if (d == null) return '—';
    final total = d.inSeconds;
    if (total <= 0) return '00:00:00';
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatMillis(dynamic ms) {
    if (ms is! int) return '00:00';
    final total = (ms ~/ 1000).clamp(0, 86400);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    final next = _service.nextPrayer;
    final silentActive = _session['active'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Salah Silent')),
      body: _service.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.softGold),
            )
          : RefreshIndicator(
              color: AppColors.softGold,
              onRefresh: () async {
                await _service.init();
                await _refreshSession();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/branding/salah_silent_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Salah Silent',
                              style: TextStyle(
                                color: AppColors.softGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                            Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _PermissionBanner(readiness: _readiness),
                  const SizedBox(height: 12),


                  if (silentActive) ...[
                    Card(
                      color: AppColors.cardDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: AppColors.softGold,
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SILENT MODE ACTIVE',
                              style: TextStyle(
                                color: AppColors.softGold,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_session['prayerName'] ?? 'Salah'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatMillis(_session['remainingMillis']),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2,
                              ),
                            ),
                            const Text(
                              'remaining',
                              style: TextStyle(
                                color: AppColors.mutedGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_session['endEpoch'] is int)
                              Text(
                                'Restores ~ ${DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(_session['endEpoch'] as int))}',
                                style: const TextStyle(
                                  color: AppColors.mutedGrey,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _confirmRestore,
                                icon: const Icon(Icons.volume_up_outlined),
                                label: const Text('Restore Sound Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.softGold,
                                  side: const BorderSide(color: AppColors.softGold),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        child: next == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No upcoming Salah',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: AppColors.softGold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Enable at least one prayer in Schedule.',
                                    style: TextStyle(color: AppColors.mutedGrey),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Next Salah',
                                    style: TextStyle(
                                      color: AppColors.mutedGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        next.schedule.prayerName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: AppColors.softGold,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          next.schedule.formattedTime,
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (next.isTomorrow)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8, bottom: 6),
                                          child: Text(
                                            'tomorrow',
                                            style: TextStyle(
                                              color: AppColors.mutedGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _formatCountdown(_remaining),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Silent for ${next.schedule.durationLabel}',
                                    style: const TextStyle(
                                      color: AppColors.mutedGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    "Today's schedule",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.softGold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ..._service.schedulesForDay(DateTime.now()).map((s) {
                    final isNext = next != null &&
                        s.prayerName == next.schedule.prayerName;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: isNext
                            ? Border.all(color: AppColors.softGold, width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.prayerName,
                              style: TextStyle(
                                color: s.enabled
                                    ? AppColors.white
                                    : AppColors.mutedGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            s.formattedTime,
                            style: TextStyle(
                              color: s.enabled
                                  ? AppColors.white
                                  : AppColors.mutedGrey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
                            child: Text(
                              s.enabled ? s.durationLabel : 'Off',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: AppColors.mutedGrey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            s.enabled
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: s.enabled
                                ? AppColors.softGold
                                : AppColors.mutedGrey,
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_nativeStatus.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Native: $_nativeStatus',
                      style: const TextStyle(
                        color: AppColors.mutedGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final Map<String, dynamic> readiness;
  const _PermissionBanner({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final level = readiness['level'] as String? ?? '';
    if (level.isEmpty) return const SizedBox.shrink();

    String text;
    Color color;
    if (level == 'ready') {
      text = 'System Ready';
      color = AppColors.softGold;
    } else if (readiness['exactAlarmOk'] != true) {
      text = 'Exact alarm permission required';
      color = Colors.orangeAccent;
    } else if (readiness['dndOk'] != true) {
      text = 'Silent-mode access required';
      color = Colors.orangeAccent;
    } else if (readiness['listenerOk'] != true) {
      text = 'Call history access unavailable';
      color = AppColors.mutedGrey;
    } else {
      text = 'Background limits may affect reliability';
      color = Colors.orangeAccent;
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PermissionSetupScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                level == 'ready' ? Icons.verified_outlined : Icons.info_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedGrey),
            ],
          ),
        ),
      ),
    );
  }
}
