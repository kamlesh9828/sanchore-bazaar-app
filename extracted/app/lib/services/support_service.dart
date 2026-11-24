
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createTicket({
    required String subject,
    required String message,
    String? orderId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    await _db.collection('support_tickets').add({
      'userId': user.uid,
      'subject': subject.trim(),
      'message': message.trim(),
      'orderId': orderId,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myTickets() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('कृपया पहले लॉगिन करें।');
    }

    return _db
        .collection('support_tickets')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
