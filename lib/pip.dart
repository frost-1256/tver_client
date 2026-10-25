import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Android picture-in-picture bridge (MainActivity implements the channel).
/// All calls are no-ops on other platforms.
class Pip {
  static const _channel = MethodChannel('jp.maffo.tver_client/pip');

  static bool get supported => Platform.isAndroid;

  static final _modeController = StreamController<bool>.broadcast();
  static bool _handlerInstalled = false;

  /// Emits true when the activity enters PiP, false when it leaves.
  static Stream<bool> get modeChanges {
    _installHandler();
    return _modeController.stream;
  }

  static void _installHandler() {
    if (_handlerInstalled || !supported) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipModeChanged') {
        _modeController.add(call.arguments == true);
      }
    });
  }

  /// When enabled, leaving the app (home swipe) during playback shrinks
  /// the player into a PiP window automatically (Android 12+; on older
  /// versions MainActivity enters PiP from onUserLeaveHint).
  static Future<void> setAutoEnter(bool enabled) async {
    if (!supported) return;
    _installHandler();
    try {
      await _channel.invokeMethod('setAutoEnter', enabled);
    } catch (_) {
      // PiP is best-effort.
    }
  }

  /// Enters PiP right now. Returns false when unavailable.
  static Future<bool> enter() async {
    if (!supported) return false;
    _installHandler();
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } catch (_) {
      return false;
    }
  }
}
