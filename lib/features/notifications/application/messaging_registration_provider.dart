import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final messagingFirestoreProvider =
    Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final messagingRegistrationProvider =
    Provider<void>((ref) {
  final session =
      ref.watch(authSessionProvider).valueOrNull;

  final userId = session?.userId;

  if (userId == null) {
    return;
  }

  final messaging =
      ref.watch(firebaseMessagingProvider);

  final firestore =
      ref.watch(messagingFirestoreProvider);

  Future<void> saveToken(String token) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .doc(token)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> register() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final allowed =
        settings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            settings.authorizationStatus ==
                AuthorizationStatus.provisional;

    if (!allowed) {
      return;
    }

    final token = await messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }
  }

  unawaited(register());

  final subscription =
      messaging.onTokenRefresh.listen(saveToken);

  ref.onDispose(subscription.cancel);
});
