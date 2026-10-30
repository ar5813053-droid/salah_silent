import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/prayer_schedule_service.dart';

/// Bottom sheet to pick preset or custom silent duration (minutes).
class DurationSelector extends StatefulWidget {
  final int currentMinutes;
  final ValueChanged<int> onSelected;

  const DurationSelector({
    super.key,
    required this.currentMinutes,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentMinutes,
    required ValueChanged<int> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DurationSelector(
        currentMinutes: currentMinutes,
        onSelected: (v) {
          onSelected(v);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  State<DurationSelector> createState() => _DurationSelectorState();
}

class _DurationSelectorState extends State<DurationSelector> {
  late int _selected;
  final _customController = TextEditingController();
  String? _customError;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMinutes;
    if (!PrayerScheduleService.presetDurations.contains(_selected)) {
      _customController.text = '$_selected';
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _applyCustom() {
    final raw = _customController.text.trim();
    final value = int.tryParse(raw);
    if (value == null) {
      setState(() => _customError = 'Enter a valid number');
      return;
    }
    if (value < 1 || value > 180) {
      setState(() => _customError = 'Duration must be 1–180 minutes');
      return;
    }
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mutedGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Silent duration',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.softGold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PrayerScheduleService.presetDurations.map((m) {
              final selected = _selected == m &&
                  PrayerScheduleService.presetDurations.contains(_selected);
              return ChoiceChip(
                label: Text(m == 60 ? '60 min' : '$m min'),
                selected: selected,
                selectedColor: AppColors.softGold.withOpacity(0.25),
                labelStyle: TextStyle(
                  color: selected ? AppColors.softGold : AppColors.white,
                ),
                onSelected: (_) {
                  setState(() {
                    _selected = m;
                    _customError = null;
                  });
                  widget.onSelected(m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Custom (1–180 min)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. 25',
                    hintStyle: TextStyle(color: AppColors.mutedGrey),
                    errorText: _customError,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _applyCustom,
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
