
String formatMessageTime(DateTime messageTime) {
  final now = DateTime.now();
  final time = messageTime.toLocal();

// Check if message is from today
  final isToday = time.year == now.year &&
      time.month == now.month &&
      time.day == now.day;

// Check if message is from yesterday
  final yesterday = now.subtract(const Duration(days: 1));

  final isYesterday = time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day;

  final messageTimeText = formatTime(time);

  if (isToday) {
    return messageTimeText;
  }

  if (isYesterday) {
    return 'yesterday · $messageTimeText';
  }

  final date = '${twoDigits(time.day)}/${twoDigits(time.month)}/${time.year}';

  return '$date · $messageTimeText';
}

String formatTime(DateTime time) {
  int hour = time.hour % 12;

  if (hour == 0) {
    hour = 12;
  }

  final minute = twoDigits(time.minute);
  final amPm = time.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $amPm';
}

String twoDigits(int number) {
  return number.toString().padLeft(2, '0');
}

