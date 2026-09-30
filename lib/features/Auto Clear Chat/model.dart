// Fixed set of durations the user can pick from
enum AutoClearOption { off, fiveMinutes, oneHour, sixHours, twentyFourHours, sevenDays }

extension AutoClearOptionData on AutoClearOption {
  // Minutes saved in the database. null means auto-delete is off
  int? get minutes {
    switch (this) {
      case AutoClearOption.off:
        return null;
      case AutoClearOption.fiveMinutes:
        return 5;
      case AutoClearOption.oneHour:
        return 60;
      case AutoClearOption.sixHours:
        return 60 * 6;
      case AutoClearOption.twentyFourHours:
        return 60 * 24;
      case AutoClearOption.sevenDays:
        return 60 * 24 * 7;
    }
  }

  // Text shown to the user
  String get label {
    switch (this) {
      case AutoClearOption.off:
        return 'Off';
      case AutoClearOption.fiveMinutes:
        return '5 minutes (testing)';
      case AutoClearOption.oneHour:
        return '1 hour';
      case AutoClearOption.sixHours:
        return '6 hours';
      case AutoClearOption.twentyFourHours:
        return '24 hours';
      case AutoClearOption.sevenDays:
        return '7 days';
    }
  }

  // Turns a minutes value (read from the database) back into an option
  static AutoClearOption fromMinutes(int? minutes) {
    if (minutes == null) return AutoClearOption.off;
    if (minutes == 5) return AutoClearOption.fiveMinutes;
    if (minutes == 60) return AutoClearOption.oneHour;
    if (minutes == 60 * 6) return AutoClearOption.sixHours;
    if (minutes == 60 * 24) return AutoClearOption.twentyFourHours;
    if (minutes == 60 * 24 * 7) return AutoClearOption.sevenDays;
    return AutoClearOption.off;
  }
}