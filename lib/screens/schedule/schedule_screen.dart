import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/prayer_schedule.dart';
import '../../services/prayer_schedule_service.dart';
import '../../widgets/duration_selector.dart';
import '../../widgets/prayer_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
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

  Future<void> _pickTime(PrayerSchedule schedule) async {
    final initial = TimeOfDay(hour: schedule.hour, minute: schedule.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.cardDark,
              hourMinuteTextColor: AppColors.white,
              dialHandColor: AppColors.softGold,
              dialBackgroundColor: AppColors.surface,
              entryModeIconColor: AppColors.softGold,
            ),
            colorScheme: const ColorScheme.dark(
              primary: AppColors.softGold,
              onPrimary: AppColors.deepNavy,
              surface: AppColors.cardDark,
              onSurface: AppColors.white,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      await _service.setTime(schedule.prayerName, picked.hour, picked.minute);
    }
  }

  Future<void> _pickDuration(PrayerSchedule schedule) async {
    await DurationSelector.show(
      context,
      currentMinutes: schedule.durationMinutes,
      onSelected: (m) => _service.setDuration(schedule.prayerName, m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextName = _service.nextPrayer?.schedule.prayerName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Schedule'),
      ),
      body: _service.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softGold))
          : _service.error != null
              ? _ErrorBody(
                  message: _service.error!,
                  onRetry: () => _service.init(),
                )
              : RefreshIndicator(
                  color: AppColors.softGold,
                  onRefresh: () => _service.init(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Times below are examples you set manually. '
                          'They are not calculated local prayer times.
'
                          "Jumu'ah replaces Dhuhr on Fridays only; configure your local mosque time.",
                          style: TextStyle(
                            color: AppColors.mutedGrey,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      ..._service.schedules.map((s) {
                        return PrayerCard(
                          schedule: s,
                          isNext: s.prayerName == nextName && s.enabled,
                          onEnabledChanged: (v) =>
                              _service.setEnabled(s.prayerName, v),
                          onEditTime: () => _pickTime(s),
                          onEditDuration: () => _pickDuration(s),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Singleton holder so Home / Schedule / Settings share one service instance.
class PrayerScheduleController {
  PrayerScheduleController._();
  static final PrayerScheduleService instance = PrayerScheduleService();
}
