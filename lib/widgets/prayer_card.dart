import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/prayer_schedule.dart';

class PrayerCard extends StatelessWidget {
  final PrayerSchedule schedule;
  final bool isNext;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEditTime;
  final VoidCallback onEditDuration;

  const PrayerCard({
    super.key,
    required this.schedule,
    this.isNext = false,
    required this.onEnabledChanged,
    required this.onEditTime,
    required this.onEditDuration,
  });

  @override
  Widget build(BuildContext context) {
    final muted = !schedule.enabled;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isNext
            ? const BorderSide(color: AppColors.softGold, width: 1.2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        schedule.prayerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: muted
                                  ? AppColors.mutedGrey
                                  : AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (isNext) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'NEXT',
                            style: TextStyle(
                              color: AppColors.softGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: schedule.enabled,
                  activeColor: AppColors.softGold,
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEditTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: muted
                                ? AppColors.mutedGrey
                                : AppColors.softGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            schedule.formattedTime,
                            style: TextStyle(
                              color: muted
                                  ? AppColors.mutedGrey
                                  : AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.mutedGrey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: onEditDuration,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: muted
                              ? AppColors.mutedGrey
                              : AppColors.softGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          schedule.durationLabel,
                          style: TextStyle(
                            color: muted
                                ? AppColors.mutedGrey
                                : AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
