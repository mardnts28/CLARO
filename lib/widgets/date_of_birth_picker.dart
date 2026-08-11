import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../generated/l10n/app_localizations.dart';

class DateOfBirthPicker extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onDateChanged;
  final bool requireAdult;

  const DateOfBirthPicker({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    required this.onDateChanged,
    this.requireAdult = true,
  });

  @override
  State<DateOfBirthPicker> createState() => _DateOfBirthPickerState();
}

class _DateOfBirthPickerState extends State<DateOfBirthPicker> {
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;

  late int _selectedMonth;
  late int _selectedDay;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _initializeDate();
  }

  void _initializeDate() {
    final now = DateTime.now();
    final maxDate = widget.lastDate ?? DateTime(now.year - 18, now.month, now.day);
    final minDate = widget.firstDate ?? DateTime(1900);

    DateTime initial = widget.initialDate ?? maxDate;

    // Ensure initial date is within valid range
    if (initial.isAfter(maxDate)) {
      initial = maxDate;
    }
    if (initial.isBefore(minDate)) {
      initial = minDate;
    }

    _selectedMonth = initial.month;
    _selectedDay = initial.day;
    _selectedYear = initial.year;

    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
    _yearController = FixedExtentScrollController(initialItem: _selectedYear - minDate.year);
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  List<int> _getValidDays(int month, int year) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (index) => index + 1);
  }

  DateTime? _getSelectedDate() {
    final now = DateTime.now();
    final maxDate = widget.lastDate ?? DateTime(now.year - 18, now.month, now.day);
    final minDate = widget.firstDate ?? DateTime(1900);

    try {
      final date = DateTime(_selectedYear, _selectedMonth, _selectedDay);

      // Check if date is valid
      if (date.month != _selectedMonth) {
        return null; // Invalid date (e.g., Feb 30)
      }

      // Check if date is within valid range
      if (date.isAfter(maxDate) || date.isBefore(minDate)) {
        return null;
      }

      // Check if user is at least 18 years old if required
      if (widget.requireAdult) {
        final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
        if (date.isAfter(eighteenYearsAgo)) {
          return null;
        }
      }

      return date;
    } catch (e) {
      return null;
    }
  }

  void _onMonthChanged(int index) {
    setState(() {
      _selectedMonth = index + 1;
      // Adjust day if it exceeds the new month's days
      final validDays = _getValidDays(_selectedMonth, _selectedYear);
      if (_selectedDay > validDays.length) {
        _selectedDay = validDays.length;
        _dayController.jumpToItem(_selectedDay - 1);
      }
      _notifyDateChanged();
    });
  }

  void _onDayChanged(int index) {
    setState(() {
      _selectedDay = index + 1;
      _notifyDateChanged();
    });
  }

  void _onYearChanged(int index) {
    final now = DateTime.now();
    final minDate = widget.firstDate ?? DateTime(1900);
    setState(() {
      _selectedYear = minDate.year + index;
      // Adjust day if it exceeds the new year/month's days
      final validDays = _getValidDays(_selectedMonth, _selectedYear);
      if (_selectedDay > validDays.length) {
        _selectedDay = validDays.length;
        _dayController.jumpToItem(_selectedDay - 1);
      }
      _notifyDateChanged();
    });
  }

  void _notifyDateChanged() {
    final date = _getSelectedDate();
    widget.onDateChanged(date);
  }

  String _getMonthName(int month, AppLocalizations loc) {
    switch (month) {
      case 1:
        return loc.january;
      case 2:
        return loc.february;
      case 3:
        return loc.march;
      case 4:
        return loc.april;
      case 5:
        return loc.may;
      case 6:
        return loc.june;
      case 7:
        return loc.july;
      case 8:
        return loc.august;
      case 9:
        return loc.september;
      case 10:
        return loc.october;
      case 11:
        return loc.november;
      case 12:
        return loc.december;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;
    final loc = AppLocalizations.of(context)!;

    final now = DateTime.now();
    final maxDate = widget.lastDate ?? DateTime(now.year - 18, now.month, now.day);
    final minDate = widget.firstDate ?? DateTime(1900);

    final validDays = _getValidDays(_selectedMonth, _selectedYear);
    final years = List.generate(maxDate.year - minDate.year + 1, (index) => minDate.year + index);
    final months = List.generate(12, (index) => index + 1);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              loc.dateOfBirth,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Wheels
          Expanded(
            child: Row(
              children: [
                // Month wheel
                Expanded(
                  flex: 2,
                  child: ListWheelScrollView.useDelegate(
                    controller: _monthController,
                    itemExtent: 40,
                    onSelectedItemChanged: _onMonthChanged,
                    physics: const FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: months.length,
                      builder: (context, index) {
                        final isSelected = index == _selectedMonth - 1;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              _getMonthName(months[index], loc),
                              style: TextStyle(
                                fontSize: isSelected ? 16 : 14,
                                color: isSelected ? primaryColor : colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Day wheel
                Expanded(
                  flex: 1,
                  child: ListWheelScrollView.useDelegate(
                    controller: _dayController,
                    itemExtent: 40,
                    onSelectedItemChanged: _onDayChanged,
                    physics: const FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: validDays.length,
                      builder: (context, index) {
                        final isSelected = index == _selectedDay - 1;
                        return Center(
                          child: Text(
                            validDays[index].toString(),
                            style: TextStyle(
                              fontSize: isSelected ? 16 : 14,
                              color: isSelected ? primaryColor : colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Year wheel
                Expanded(
                  flex: 1,
                  child: ListWheelScrollView.useDelegate(
                    controller: _yearController,
                    itemExtent: 40,
                    onSelectedItemChanged: _onYearChanged,
                    physics: const FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: years.length,
                      builder: (context, index) {
                        final isSelected = years[index] == _selectedYear;
                        return Center(
                          child: Text(
                            years[index].toString(),
                            style: TextStyle(
                              fontSize: isSelected ? 16 : 14,
                              color: isSelected ? primaryColor : colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
