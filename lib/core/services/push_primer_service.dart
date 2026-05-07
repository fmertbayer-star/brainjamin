import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_permission_service.dart';
import 'server_time_service.dart';

final class PushPrimerService {
  PushPrimerService._();

  static const _cooldownDuration = Duration(days: 7);
  static const _anonCooldownPrefKey = 'bj_push_primer_cooldown_until';
  static const _userFieldCooldown = 'pushPrimerCooldownUntil';
  static const _userFieldFcmToken = 'fcm_token';
  static const _userFieldFcmTokenUpdatedAt = 'fcm_token_updated_at';

  static Future<bool> shouldShowPrimer() async {
    final status = await PushPermissionService.getCurrentStatus();
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.denied:
      case AuthorizationStatus.provisional:
        return false;
      case AuthorizationStatus.notDetermined:
        break;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final cooldownUntil = user.isAnonymous ?
      await _readAnonymousCooldown() :
      await _readPermanentCooldown(user.uid);

    if (cooldownUntil == null) {
      return true;
    }
    final now = ServerTimeService.now();
    if (now.isBefore(cooldownUntil)) {
      return false;
    }
    return true;
  }

  static Future<void> writeCooldown() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final cooldownUntil = Timestamp.fromDate(
      ServerTimeService.now().add(_cooldownDuration),
    );

    if (user.isAnonymous) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _anonCooldownPrefKey,
        cooldownUntil.millisecondsSinceEpoch,
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      _userFieldCooldown: cooldownUntil,
    }, SetOptions(merge: true));
  }

  static Future<AuthorizationStatus> requestAndCaptureToken() async {
    final status = await PushPermissionService.requestPermission();
    if (status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional) {
      return status;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return status;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        return status;
      }

      await _writeTokenToFirestore(user, token);
    } catch (error, stackTrace) {
      debugPrint('[PushPrimerService] token capture failed: $error');
      debugPrint(stackTrace.toString());
    }

    return status;
  }

  static Future<void> captureTokenIfAuthorized() async {
    try {
      final status = await PushPermissionService.getCurrentStatus();
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        return;
      }

      await _writeTokenToFirestore(user, token);
    } catch (_) {
      return;
    }
  }

  static Future<DateTime?> _readAnonymousCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_anonCooldownPrefKey);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<DateTime?> _readPermanentCooldown(String uid) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snapshot.data();
    final value = data?[_userFieldCooldown];
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  static Future<void> _writeTokenToFirestore(User user, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      _userFieldFcmToken: token,
      _userFieldFcmTokenUpdatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
