
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:illinois/model/Inbox.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/utils/Utils.dart';

/// Inbox service does rely on Service initialization API so it does not override service interfaces and is not registered in Services.
class Inbox with Service implements NotificationsListener {

  String   _fcmToken;
  bool     _isServiceInitialized;
  DateTime _pausedDateTime;

  // Singletone instance

  static final Inbox _instance = Inbox._internal();

  factory Inbox() {
    return _instance;
  }

  Inbox._internal();

  // Service

  @override
  void createService() {
    NotificationService().subscribe(this, [
      FirebaseMessaging.notifyToken,
      Auth2.notifyLoginChanged,
      AppLivecycle.notifyStateChanged,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {
    _fcmToken = Storage().inboxFirebaseMessagingToken;
    _isServiceInitialized = true;
    _processFcmToken();
  }

  @override
  Set<Service> get serviceDependsOn {
    return Set.from([FirebaseMessaging(), Storage(), Config(), Auth2()]);
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == FirebaseMessaging.notifyToken) {
      _processFcmToken();
    }
    else if (name == Auth2.notifyLoginChanged) {
      _processFcmToken();
    }
    else if (name == AppLivecycle.notifyStateChanged) {
      _onAppLivecycleStateChanged(param); 
    }
  }

  void _onAppLivecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedDateTime = DateTime.now();
    }
    else if (state == AppLifecycleState.resumed) {
      if (_pausedDateTime != null) {
        Duration pausedDuration = DateTime.now().difference(_pausedDateTime);
        if (Config().refreshTimeout < pausedDuration.inSeconds) {
          _processFcmToken();
        }
      }
    }
  }

  // Inbox APIs

  Future<List<InboxMessage>> loadMessages({DateTime startDate, DateTime endDate, String category, Iterable messageIds, int offset, int limit }) async {
    
    String urlParams = "";
    
    if (offset != null) {
      if (urlParams.isNotEmpty) {
        urlParams += "&";
      }
      urlParams += "offset=$offset";
    }
    
    if (limit != null) {
      if (urlParams.isNotEmpty) {
        urlParams += "&";
      }
      urlParams += "limit=$limit";
    }

    if (startDate != null) {
      if (urlParams.isNotEmpty) {
        urlParams += "&";
      }
      urlParams += "start_date=${startDate.millisecondsSinceEpoch}";
    }

    if (endDate != null) {
      if (urlParams.isNotEmpty) {
        urlParams += "&";
      }
      urlParams += "end_date=${endDate.millisecondsSinceEpoch}";
    }

    if (urlParams.isNotEmpty) {
      urlParams = "?$urlParams";
    }

    dynamic body = (messageIds != null) ? AppJson.encode({ "ids": List.from(messageIds) }) : null;

    String url = (Config().notificationsUrl != null) ? "${Config().notificationsUrl}/api/messages$urlParams" : null;
    Response response = await Network().get(url, body: body, auth: NetworkAuth.User);
    return (response?.statusCode == 200) ? (InboxMessage.listFromJson(AppJson.decodeList(response?.body)) ?? []) : null;
  }

  Future<bool> deleteMessages(Iterable messageIds) async {
    String url = (Config().notificationsUrl != null) ? "${Config().notificationsUrl}/api/messages" : null;
    String body = AppJson.encode({
      "ids": (messageIds != null) ? List.from(messageIds) : null
    });

    Response response = await Network().delete(url, body: body, auth: NetworkAuth.User);
    return (response?.statusCode == 200);
  }

  Future<bool> sendMessage(InboxMessage message) async {
    String url = (Config().notificationsUrl != null) ? "${Config().notificationsUrl}/api/message" : null;
    String body = AppJson.encode(message?.toJson());

    Response response = await Network().post(url, body: body, auth: NetworkAuth.User);
    return (response?.statusCode == 200);
  }

  Future<bool> subscribeToTopic({String topic, String token}) async {
    return _manageFCMSubscription(topic: topic, token: token, action: 'subscribe');
  }

  Future<bool> unsubscribeFromTopic({String topic, String token}) async {
    return _manageFCMSubscription(topic: topic, token: token, action: 'unsubscribe');
  }

  Future<bool> _manageFCMSubscription({String topic, String token, String action}) async {
    if ((Config().notificationsUrl != null) && (topic != null) && (token != null) && (action != null)) {
      String url = "${Config().notificationsUrl}/api/topic/$topic/$action";
      String body = AppJson.encode({
        'token': token
      });
      Response response = await Network().post(url, body: body, auth: NetworkAuth.User);
      Log.d("FCMTopic_$action($topic) => ${(response?.statusCode == 200) ? 'Yes' : 'No'}");
      return (response?.statusCode == 200);
    }
    return false;
  }

  // FCM Token

  void _processFcmToken() {
    if (_isServiceInitialized == true) {
      String fcmToken = FirebaseMessaging().token;
      if (Auth2().isLoggedIn) {
        if ((fcmToken != null) && (fcmToken != _fcmToken)) {
          _updateFCMToken(token: fcmToken, previousToken: _fcmToken).then((bool result) {
            if (result) {
              Storage().inboxFirebaseMessagingToken = _fcmToken = fcmToken;
            }
          });
        }
      }
      else if (_fcmToken != null) {
        _updateFCMToken(token: _fcmToken).then((bool result) {
          if (result) {
            Storage().inboxFirebaseMessagingToken = _fcmToken = null;
          }
        });
      }
    }
  }

  Future<bool> _updateFCMToken({String token, String previousToken, NetworkAuth auth}) async {
    if ((Config().notificationsUrl != null) && ((token != null) || (previousToken != null))) {
      String url = "${Config().notificationsUrl}/api/token";
      String body = AppJson.encode({
        'token': token,
        'previous_token': previousToken
      });
      if (auth == null) {
        auth = Auth2().isLoggedIn ? NetworkAuth.User : NetworkAuth.App;
      }
      Response response = await Network().post(url, body: body, auth: auth);
      Log.d("FCMToken_update(${(token != null) ? 'token' : 'null'}, ${(previousToken != null) ? 'token' : 'null'}) => ${(response?.statusCode == 200) ? 'Yes' : 'No'}");
      return (response?.statusCode == 200);
    }
    return false;
  }

}