import 'dart:convert';
import 'dart:io';

import 'package:push_demo/firebase_options.dart';
import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:push_demo/notifications/local_notifications_manager.dart';

class PushManager {
  static Future<void> initialize() async {
    if (kIsWeb) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register with FCM
    // It requests a registration token for sending messages to users from your App server or other trusted server environment.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('Registration fcmToken=$newToken');
      }
      if (ChatClient.getInstance.currentUserId != null) {
        // register the FCM token for the user
        ChatClient.getInstance.pushManager.updateFCMPushToken(newToken);
      }
    });

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      
      debugPrint('Handling a foreground message: ${message.messageId}');
      debugPrint('Message data: ${message.data}');
      debugPrint('Message notification: ${message.notification?.title}');
      debugPrint('Message notification: ${message.notification?.body}');

      if (Platform.isAndroid) {
        final agoraChat = jsonDecode(message.data['EPush'] as String);
        if (agoraChat != null) {
          await LocalNotificationsManager.showNotification(
            title: message.notification?.title as String,
            body: message.notification?.body,
            payload: message.data['EPush'] as String,
          );
        }
      } else if (Platform.isIOS) {
        final agoraChat = message.data['EPush'] as Map<Object?, Object?>?;
        if (agoraChat!= null ) {
          await LocalNotificationsManager.showNotification(
            title: message.notification?.title as String,
            body: message.notification?.body,
            payload: Platform.isIOS ? jsonEncode(agoraChat): agoraChat as String,
          );
        }
      }
      
    });

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Define the background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await Firebase.initializeApp();

    if (kDebugMode) {
      print("Handling a background message: ${message.messageId}");
      print('Message data: ${message.data}');
      print('Message notification: ${message.notification?.title}');
      print('Message notification: ${message.notification?.body}');
    }
  }

  // Request permission
  static Future<bool> requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (kDebugMode) {
      print('Permission granted: ${settings.authorizationStatus}');
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  static Future<bool> registerPushToken() async {
    if (kIsWeb) return false;

    final messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();

    if (kDebugMode) {
      print('Registration Token=$token');
    }
    if (token != null) {
      try {
        if (Platform.isIOS) {
          await ChatClient.getInstance.pushManager.updateAPNsDeviceToken(token);
        } else {
          await ChatClient.getInstance.pushManager.updateFCMPushToken(token);
        }
      } on ChatError catch (e) {
        debugPrint("bind fcm token error: ${e.code}, desc: ${e.description}");
      }
      return true;
    }
    return false;
  }

}
