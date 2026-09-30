import 'package:flutter_riverpod/flutter_riverpod.dart';import 'auto_service.dart';

final autoClearServiceProvider = Provider<AutoClearService>((ref) {
  return AutoClearService();
});