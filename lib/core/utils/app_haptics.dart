import 'package:flutter/services.dart';

// One place for every vibration effect in the app.
// Use it anywhere like:  AppHaptics.tap();
class AppHaptics {
  // Master switch: set to false to turn off ALL vibrations in the app
  static bool enabled = true;

  // Very small tick. For buttons, play/pause, speed toggle, switches
  static void tap() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  // Light touch
  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  // Medium press. For long press menus, lock
  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  // Strong press
  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  // Mic pressed and recording started
  static void recordStart() {
    heavy();
  }

  // Recording locked (slid up)
  static void lock() {
    medium();
  }

  // Message sent: two quick taps (medium, then light)
  static Future<void> messageSent() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
  }

  // Something got deleted or cancelled: two strong taps
  static Future<void> warning() async {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  // Something went wrong (permission denied, upload failed)
  static void error() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}