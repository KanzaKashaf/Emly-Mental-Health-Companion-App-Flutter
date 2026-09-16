import '../../core/data/repositories/therapy_repository.dart';

class CbtActivityLockUtils {
  CbtActivityLockUtils._();

  /// Backend stores completedAt in history.
  /// We lock if any backend completedAt falls on the user's current local day.
  static bool completedTodayFromHistory(
    List<TherapyActivityHistoryItem> history,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return history.any((item) {
      final completedAt = item.completedAt;
      if (completedAt == null) return false;

      final localCompletedAt = completedAt.toLocal();
      final completedDay = DateTime(
        localCompletedAt.year,
        localCompletedAt.month,
        localCompletedAt.day,
      );

      return completedDay == today;
    });
  }

  static bool isDailyLimitError(String message) {
    final m = message.trim().toLowerCase();

    return m.contains('once per day') ||
        m.contains('try again after') ||
        m.contains('completed this activity today') ||
        m.contains('come back tomorrow') ||
        m.contains('already completed');
  }

  static String completedTodayMessage() {
    return 'You have completed this activity today. It will unlock again tomorrow.';
  }
}