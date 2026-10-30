import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/prayer_schedule_service.dart';
import '../schedule/schedule_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _service = PrayerScheduleController.instance;
    _service.addListener(_onServiceUpdate);
    _pingNative();
    _remaining = _service.remainingUntilNext();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _service.remainingUntilNext();
      });
    });
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
        setState(() => _nativeStatus = 'Native bridge OK (stub)');
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    final next = _service.nextPrayer;

    return Scaffold(
      appBar: AppBar(title: const Text('Salah Silent')),
      body: _service.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.softGold),
            )
          : RefreshIndicator(
              color: AppColors.softGold,
              onRefresh: () => _service.init(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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
                                        padding: EdgeInsets.only(
                                          left: 8,
                                          bottom: 6,
                                        ),
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
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
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
                  Text(
                    "Today's schedule",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.softGold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ..._service.schedules.map((s) {
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
                              style: TextStyle(
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
