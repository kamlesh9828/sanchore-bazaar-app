import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

class RefundService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String get uid => auth.currentUser?.uid ?? (throw Exception('कृपया पहले लॉगिन करें।'));

  Future<String> requestRefund({required String orderId, required String reason}) async {
    if (reason.trim().isEmpty) throw Exception('Refund ka reason likhein');
    final order = await db.collection('orders').doc(orderId).get();
    if (!order.exists || order.data()?['customerId'] != uid) throw Exception('Order access denied');
    if (order.data()?['status'] != 'delivered' || order.data()?['paymentStatus'] != 'paid') {
      throw Exception('Refund sirf delivered aur paid order par maang sakte hain');
    }
    final existing = await db.collection('refundRequests').where('orderId', isEqualTo: orderId)
        .where('customerId', isEqualTo: uid).where('status', isEqualTo: 'pending').limit(1).get();
    if (existing.docs.isNotEmpty) throw Exception('इस ऑर्डर का रिफंड अनुरोध पहले से लंबित है।');
    final ref = await db.collection('refundRequests').add({'orderId': orderId,
      'customerId': uid, 'reason': reason.trim(), 'status': 'pending',
      'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myRefundRequests() => db.collection('refundRequests')
      .where('customerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

  Future<void> reviewRefund({required String requestId, required bool approve,
      String? adminNote}) async {
    await WorkerApi.post('/api/admin/reviewRefund', {
      'requestId': requestId,
      'approve': approve,
      'adminNote': adminNote ?? '',
    });
  }
}
