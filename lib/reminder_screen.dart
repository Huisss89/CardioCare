import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const String _healthRemindersKey = 'health_record_reminders';
const String _medicineRemindersKey = 'medicine_reminders';
const int _healthIdBase = 100;
const int _medicineIdBase = 1000;

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

class Reminder {
  final int id;
  final String type;
  final int hour;
  final int minute;
  final bool enabled;
  final String? label;
  final String repeatType; // 'daily' | 'weekly'
  final int? selectedDay; // 1=Mon, 7=Sun, for weekly only

  Reminder({
    required this.id,
    required this.type,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.label,
    this.repeatType = 'daily',
    this.selectedDay,
  });

  String get timeStr =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'label': label,
        'repeatType': repeatType,
        'selectedDay': selectedDay,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as int,
        type: j['type'] as String,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        enabled: j['enabled'] as bool? ?? true,
        label: j['label'] as String?,
        repeatType: j['repeatType'] as String? ?? 'daily',
        selectedDay: j['selectedDay'] as int?,
      );

  Reminder copyWith({
    int? hour,
    int? minute,
    bool? enabled,
    String? label,
    String? repeatType,
    int? selectedDay,
  }) =>
      Reminder(
        id: id,
        type: type,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        label: label ?? this.label,
        repeatType: repeatType ?? this.repeatType,
        selectedDay: selectedDay ?? this.selectedDay,
      );
}

/// Slidable time picker using NumberPicker (scroll to select hour & minute)
Future<TimeOfDay?> showSlidableTimePicker(
  BuildContext context, {
  required int initialHour,
  required int initialMinute,
}) async {
  int hour = initialHour.clamp(0, 23);
  int minute = initialMinute.clamp(0, 59);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Color(0xFF2D3748),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                NumberPicker(
                  minValue: 0,
                  maxValue: 23,
                  value: hour,
                  zeroPad: true,
                  infiniteLoop: true,
                  itemWidth: 70,
                  itemHeight: 50,
                  onChanged: (v) => setModalState(() => hour = v),
                  textStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 22),
                  selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
                const Text(':',
                    style: TextStyle(color: Colors.white54, fontSize: 28)),
                NumberPicker(
                  minValue: 0,
                  maxValue: 59,
                  value: minute,
                  zeroPad: true,
                  infiniteLoop: true,
                  itemWidth: 70,
                  itemHeight: 50,
                  onChanged: (v) => setModalState(() => minute = v),
                  textStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 22),
                  selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, TimeOfDay(hour: hour, minute: minute)),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF48BB78)),
                  child: const Text('OK'),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<Reminder> _healthReminders = [];
  List<Reminder> _medicineReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await NotificationService.instance.initialize();
    await NotificationService.instance.ensurePermission();
    await _loadReminders();
    await _rescheduleAllReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final healthJson = prefs.getStringList(_healthRemindersKey) ?? [];
    final medicineJson = prefs.getStringList(_medicineRemindersKey) ?? [];

    final health = healthJson
        .map((s) => Reminder.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    final medicine = medicineJson
        .map((s) => Reminder.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    if (mounted) {
      setState(() {
        _healthReminders = health;
        _medicineReminders = medicine;
        _isLoading = false;
      });
    }
  }

  Future<void> _rescheduleAllReminders() async {
    for (final r in _healthReminders) {
      if (r.enabled) {
        if (r.repeatType == 'weekly' && r.selectedDay != null) {
          await NotificationService.instance.scheduleWeekly(
            r.id,
            r.hour,
            r.minute,
            r.selectedDay!,
            'Time to check your health',
            'Measure your heart rate, HRV or blood pressure',
            isMedicine: false,
          );
        } else {
          await NotificationService.instance.scheduleDaily(
            r.id,
            r.hour,
            r.minute,
            'Time to check your health',
            'Measure your heart rate, HRV or blood pressure',
            isMedicine: false,
          );
        }
      }
    }
    for (final r in _medicineReminders) {
      if (r.enabled) {
        await NotificationService.instance.scheduleDaily(
          r.id,
          r.hour,
          r.minute,
          'Time for ${r.label ?? "Medication"}',
          'Don\'t forget to take your medication',
          isMedicine: true,
        );
      }
    }
  }

  Future<void> _saveHealthReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_healthRemindersKey,
        _healthReminders.map((r) => jsonEncode(r.toJson())).toList());
  }

  Future<void> _saveMedicineReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_medicineRemindersKey,
        _medicineReminders.map((r) => jsonEncode(r.toJson())).toList());
  }

  Future<void> _addHealthReminder() async {
    final now = TimeOfDay.now();
    final time = await showSlidableTimePicker(context,
        initialHour: now.hour, initialMinute: now.minute);
    if (time == null) return;

    String repeatType = 'daily';
    int? selectedDay;
    final repeatChoice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Repeat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Daily'),
              leading: const Icon(Icons.today),
              onTap: () => Navigator.pop(ctx, 'daily'),
            ),
            ListTile(
              title: const Text('Weekly'),
              leading: const Icon(Icons.date_range),
              onTap: () => Navigator.pop(ctx, 'weekly'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (repeatChoice == null) return;
    repeatType = repeatChoice;

    if (repeatType == 'weekly') {
      final day = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Select day',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(7, (i) {
                  final d = i + 1;
                  return ChoiceChip(
                    label: Text(_weekdayNames[i]),
                    selected: false,
                    onSelected: (_) => Navigator.pop(ctx, d),
                  );
                }),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
      if (day == null) return;
      selectedDay = day;
    }

    final maxId = _healthReminders.isEmpty
        ? 0
        : _healthReminders.map((r) => r.id).reduce((a, b) => a > b ? a : b);
    final id = maxId >= _healthIdBase ? maxId + 1 : _healthIdBase;
    final reminder = Reminder(
      id: id,
      type: 'health_record',
      hour: time.hour,
      minute: time.minute,
      repeatType: repeatType,
      selectedDay: selectedDay,
    );

    setState(() => _healthReminders.add(reminder));
    await _saveHealthReminders();

    await NotificationService.instance.ensurePermission();

    if (reminder.repeatType == 'weekly' && reminder.selectedDay != null) {
      await NotificationService.instance.scheduleWeekly(
        reminder.id,
        reminder.hour,
        reminder.minute,
        reminder.selectedDay!,
        'Time to check your health',
        'Measure your heart rate, HRV or blood pressure',
        isMedicine: false,
      );
    } else {
      await NotificationService.instance.scheduleDaily(
        reminder.id,
        reminder.hour,
        reminder.minute,
        'Time to check your health',
        'Measure your heart rate, HRV or blood pressure',
        isMedicine: false,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Health reminder set for ${reminder.timeStr}'),
          backgroundColor: const Color(0xFF48BB78),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addMedicineReminder() async {
    final now = TimeOfDay.now();
    final time = await showSlidableTimePicker(context,
        initialHour: now.hour, initialMinute: now.minute);
    if (time == null) return;

    final label = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: 'BP Medication');
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Medicine name'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
                hintText: 'e.g. BP Medication, Lisinopril'),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, c.text.trim().isEmpty ? 'Medication' : c.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (label == null) return;

    final maxId = _medicineReminders.isEmpty
        ? 0
        : _medicineReminders.map((r) => r.id).reduce((a, b) => a > b ? a : b);
    final id = maxId >= _medicineIdBase ? maxId + 1 : _medicineIdBase;
    final reminder = Reminder(
        id: id,
        type: 'medicine',
        hour: time.hour,
        minute: time.minute,
        label: label);

    setState(() => _medicineReminders.add(reminder));
    await _saveMedicineReminders();

    await NotificationService.instance.ensurePermission();
    await NotificationService.instance.scheduleDaily(
      reminder.id,
      reminder.hour,
      reminder.minute,
      'Time for $label',
      'Don\'t forget to take your medication',
      isMedicine: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label reminder set for ${reminder.timeStr}'),
          backgroundColor: const Color(0xFF48BB78),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── EDIT HEALTH REMINDER ──────────────────────────────────────────────────
  Future<void> _editHealthReminder(Reminder r) async {
    // Step 1: Pick new time (pre-filled with current time)
    final time = await showSlidableTimePicker(context,
        initialHour: r.hour, initialMinute: r.minute);
    if (time == null) return;

    // Step 2: Pick repeat type (pre-selected current value)
    String repeatType = r.repeatType;
    int? selectedDay = r.selectedDay;

    final repeatChoice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Repeat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Daily'),
              leading: const Icon(Icons.today),
              trailing: r.repeatType == 'daily'
                  ? const Icon(Icons.check, color: Color(0xFF48BB78))
                  : null,
              onTap: () => Navigator.pop(ctx, 'daily'),
            ),
            ListTile(
              title: const Text('Weekly'),
              leading: const Icon(Icons.date_range),
              trailing: r.repeatType == 'weekly'
                  ? const Icon(Icons.check, color: Color(0xFF48BB78))
                  : null,
              onTap: () => Navigator.pop(ctx, 'weekly'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (repeatChoice == null) return;
    repeatType = repeatChoice;

    // Step 3: If weekly, pick day (pre-selected current day)
    if (repeatType == 'weekly') {
      final day = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Select day',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(7, (i) {
                  final d = i + 1;
                  return ChoiceChip(
                    label: Text(_weekdayNames[i]),
                    selected: r.selectedDay == d,
                    onSelected: (_) => Navigator.pop(ctx, d),
                  );
                }),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
      if (day == null) return;
      selectedDay = day;
    } else {
      selectedDay = null;
    }

    // Build updated reminder (same id, same enabled state)
    final updated = r.copyWith(
      hour: time.hour,
      minute: time.minute,
      repeatType: repeatType,
      selectedDay: selectedDay,
    );

    // Update state & persist
    final i = _healthReminders.indexWhere((x) => x.id == r.id);
    if (i < 0) return;
    setState(() => _healthReminders[i] = updated);
    await _saveHealthReminders();

    // Cancel old notification and reschedule with new settings
    await NotificationService.instance.cancel(updated.id);
    if (updated.enabled) {
      await NotificationService.instance.ensurePermission();
      if (updated.repeatType == 'weekly' && updated.selectedDay != null) {
        await NotificationService.instance.scheduleWeekly(
          updated.id,
          updated.hour,
          updated.minute,
          updated.selectedDay!,
          'Time to check your health',
          'Measure your heart rate, HRV or blood pressure',
          isMedicine: false,
        );
      } else {
        await NotificationService.instance.scheduleDaily(
          updated.id,
          updated.hour,
          updated.minute,
          'Time to check your health',
          'Measure your heart rate, HRV or blood pressure',
          isMedicine: false,
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Health reminder updated to ${updated.timeStr}'),
          backgroundColor: const Color(0xFF4FACFE),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── EDIT MEDICINE REMINDER ────────────────────────────────────────────────
  Future<void> _editMedicineReminder(Reminder r) async {
    // Step 1: Pick new time (pre-filled with current time)
    final time = await showSlidableTimePicker(context,
        initialHour: r.hour, initialMinute: r.minute);
    if (time == null) return;

    // Step 2: Edit medicine name (pre-filled with current label)
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: r.label ?? 'Medication');
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit medicine name'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
                hintText: 'e.g. BP Medication, Lisinopril'),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, c.text.trim().isEmpty ? 'Medication' : c.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (label == null) return;

    // Build updated reminder (same id, same enabled state)
    final updated = r.copyWith(
      hour: time.hour,
      minute: time.minute,
      label: label,
    );

    // Update state & persist
    final i = _medicineReminders.indexWhere((x) => x.id == r.id);
    if (i < 0) return;
    setState(() => _medicineReminders[i] = updated);
    await _saveMedicineReminders();

    // Cancel old notification and reschedule with new settings
    await NotificationService.instance.cancel(updated.id);
    if (updated.enabled) {
      await NotificationService.instance.ensurePermission();
      await NotificationService.instance.scheduleDaily(
        updated.id,
        updated.hour,
        updated.minute,
        'Time for $label',
        'Don\'t forget to take your medication',
        isMedicine: true,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label reminder updated to ${updated.timeStr}'),
          backgroundColor: const Color(0xFF4FACFE),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleReminder(Reminder r, bool enabled) async {
    final updated = r.copyWith(enabled: enabled);
    if (r.type == 'health_record') {
      final i = _healthReminders.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        setState(() => _healthReminders[i] = updated);
        await _saveHealthReminders();
      }
    } else {
      final i = _medicineReminders.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        setState(() => _medicineReminders[i] = updated);
        await _saveMedicineReminders();
      }
    }

    if (enabled) {
      if (updated.type == 'health_record') {
        if (updated.repeatType == 'weekly' && updated.selectedDay != null) {
          await NotificationService.instance.scheduleWeekly(
            updated.id,
            updated.hour,
            updated.minute,
            updated.selectedDay!,
            'Time to check your health',
            'Measure your heart rate, HRV or blood pressure',
            isMedicine: false,
          );
        } else {
          await NotificationService.instance.scheduleDaily(
            updated.id,
            updated.hour,
            updated.minute,
            'Time to check your health',
            'Measure your heart rate, HRV or blood pressure',
            isMedicine: false,
          );
        }
      } else {
        await NotificationService.instance.scheduleDaily(
          updated.id,
          updated.hour,
          updated.minute,
          'Time for ${updated.label ?? "Medication"}',
          'Don\'t forget to take your medication',
          isMedicine: true,
        );
      }
    } else {
      await NotificationService.instance.cancel(updated.id);
    }
  }

  Future<void> _deleteReminder(Reminder r) async {
    if (r.type == 'health_record') {
      setState(() => _healthReminders.removeWhere((x) => x.id == r.id));
      await _saveHealthReminders();
    } else {
      setState(() => _medicineReminders.removeWhere((x) => x.id == r.id));
      await _saveMedicineReminders();
    }
    await NotificationService.instance.cancel(r.id);
  }

  String _formatHealthLabel(Reminder r) {
    if (r.repeatType == 'weekly' &&
        r.selectedDay != null &&
        r.selectedDay! >= 1 &&
        r.selectedDay! <= 7) {
      return '${_weekdayNames[r.selectedDay! - 1]} at ${r.timeStr}';
    }
    return 'Daily at ${r.timeStr}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 32,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFED8936), Color(0xFFDD6B20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Reminders',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Health checks & medicine reminders',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFED8936))))
                : SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSection(
                        title: 'Health Record Reminders',
                        subtitle: 'Get reminded to measure HR, HRV or BP',
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFFFF6B9D),
                        gradientColors: const [
                          Color(0xFFFF6B9D),
                          Color(0xFFFFC3A0)
                        ],
                        reminders: _healthReminders,
                        onAdd: _addHealthReminder,
                        onToggle: _toggleReminder,
                        onDelete: _deleteReminder,
                        onEdit: _editHealthReminder,
                        emptyMessage: 'No health reminders yet',
                        formatLabel: _formatHealthLabel,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: 'Medicine Reminders',
                        subtitle: 'Never miss your BP medication',
                        icon: Icons.medication_rounded,
                        color: const Color(0xFF667EEA),
                        gradientColors: const [
                          Color(0xFF667EEA),
                          Color(0xFF764BA2)
                        ],
                        reminders: _medicineReminders,
                        onAdd: _addMedicineReminder,
                        onToggle: _toggleReminder,
                        onDelete: _deleteReminder,
                        onEdit: _editMedicineReminder,
                        emptyMessage: 'No medicine reminders yet',
                        formatLabel: (r) =>
                            '${r.label ?? "Medication"} • ${r.timeStr}',
                      ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    required List<Reminder> reminders,
    required VoidCallback onAdd,
    required Future<void> Function(Reminder, bool) onToggle,
    required Future<void> Function(Reminder) onDelete,
    required Future<void> Function(Reminder) onEdit,
    required String emptyMessage,
    required String Function(Reminder) formatLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748))),
                      Text(subtitle,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Material(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add_rounded,
                          color: Color(0xFF2D3748), size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(emptyMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            )
          else
            ...reminders.map((r) => _ReminderTile(
                  reminder: r,
                  color: color,
                  formatLabel: formatLabel(r),
                  onToggle: (v) => onToggle(r, v),
                  onDelete: () => onDelete(r),
                  onEdit: () => onEdit(r),
                )),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final Color color;
  final String formatLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ReminderTile({
    required this.reminder,
    required this.color,
    required this.formatLabel,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              formatLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: reminder.enabled ? const Color(0xFF2D3748) : Colors.grey,
              ),
            ),
          ),
          // ── Edit button ──────────────────────────────────────────────────
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.grey[600], size: 22),
            tooltip: 'Edit reminder',
            onPressed: onEdit,
          ),
          Switch.adaptive(value: reminder.enabled, onChanged: onToggle),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.grey[600], size: 22),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete reminder?'),
                  content: const Text('This reminder will be removed.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}
