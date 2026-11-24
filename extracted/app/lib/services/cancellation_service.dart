
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

class CancellationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> requestCancellation({
    required String orderId,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    if (reason.trim().isEmpty) throw Exception('Cancellation ka reason likhein');

    final orderRef = _db.collection('orders').doc(orderId);
    final order = await orderRef.get();

    if (!order.exists || order.data()?['customerId'] != user.uid) {
      throw Exception('ऑर्डर नहीं मिला।');
    }

    final status = order.data()?['status'];

    if (status != 'placed' && status != 'accepted') {
      throw Exception('इस ऑर्डर को अब रद्द नहीं किया जा सकता।');
    }

    final existing = await _db
        .collection('cancellationRequests')
        .where('orderId', isEqualTo: orderId)
        .where('customerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('रद्द करने का अनुरोध पहले ही भेजा जा चुका है।');
    }

    await _db.collection('cancellationRequests').add({
      'orderId': orderId,
      'customerId': user.uid,
      'reason': reason.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> reviewCancellation({required String requestId, required bool approve, String adminNote = ''}) async {
    if (_auth.currentUser == null) throw Exception('कृपया पहले लॉगिन करें।');
    await WorkerApi.post('/api/admin/reviewCancellation', {
      'requestId': requestId, 'approve': approve, 'adminNote': adminNote,
    });
  }

}
