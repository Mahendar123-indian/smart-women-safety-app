// lib/features/notifications/providers/notification_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// INDUSTRIAL SENTINEL — NOTIFICATION STATE MANAGER v5.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ [PERFORMANCE] Optimistic UI Updates: Instantly removes swiped items
//    before Firebase syncs, preventing the notorious Dismissible crash.
// ✅ [SYNC] Real-time Firestore streaming for multi-device consistency.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/notifications_screen.dart'; // Imports AppNotification model

class NotificationProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _sub;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  String get _uid => _auth.currentUser?.uid ?? '';

  void init() {
    if (_uid.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _sub?.cancel();
    _sub = _firestore
        .collection('contactNotifications')
        .where('recipientUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _notifications = snap.docs.map(AppNotification.fromFirestore).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  List<AppNotification> getFiltered(NotifCategory? cat) {
    if (cat == null) return _notifications;
    return _notifications.where((n) => n.category == cat).toList();
  }

  int getUnreadCount(NotifCategory? cat) {
    return getFiltered(cat).where((n) => !n.isRead).length;
  }

  // ✅ OPTIMISTIC DELETE: Prevents Dismissible tree crashes
  Future<void> deleteNotification(String id) async {
    // 1. Remove from UI instantly
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    // 2. Delete from Cloud silently
    try {
      await _firestore.collection('contactNotifications').doc(id).delete();
    } catch (_) {}
  }

  Future<void> clearAll(NotifCategory? cat) async {
    final list = getFiltered(cat);
    if (list.isEmpty) return;

    // 1. Remove from UI instantly
    _notifications.removeWhere((n) => cat == null || n.category == cat);
    notifyListeners();

    // 2. Delete from Cloud
    final batch = _firestore.batch();
    for (final n in list) {
      batch.delete(_firestore.collection('contactNotifications').doc(n.id));
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();

      try {
        await _firestore.collection('contactNotifications').doc(id).update({
          'isRead': true,
          'read': true,
        });
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead(NotifCategory? cat) async {
    final unread = getFiltered(cat).where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    for (var n in unread) {
      n.isRead = true;
    }
    notifyListeners();

    final batch = _firestore.batch();
    for (final n in unread) {
      batch.update(
        _firestore.collection('contactNotifications').doc(n.id),
        {'isRead': true, 'read': true},
      );
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}