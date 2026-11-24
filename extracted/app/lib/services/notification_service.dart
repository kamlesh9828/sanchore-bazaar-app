
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> myNotifications() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    final ref =
        _db.collection('notifications').doc(notificationId);

    final doc = await ref.get();

    if (!doc.exists || doc.data()?['userId'] != user.uid) {
      throw Exception('सूचना नहीं मिली।');
    }

    await ref.update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
