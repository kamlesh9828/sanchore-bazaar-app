import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

/// COD status reader and Admin's manual payment confirmation.
/// This does not collect money or verify a bank transfer automatically.
class PaymentService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> selectCashOnDelivery(String orderId) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw Exception('कृपया पहले लॉगिन करें।');
    final snap = await db.collection('orders').doc(orderId).get();
    if (!snap.exists || snap.data()?['customerId'] != uid) throw Exception('Order access denied');
    if (snap.data()?['paymentMethod'] != 'cod') throw Exception('इस ऑर्डर में सामान मिलने पर नकद भुगतान नहीं चुना गया है।');
  }

  Future<Map<String, dynamic>> initiatePaytm(String sessionId) =>
      WorkerApi.post('/api/paytm/initiate', {'sessionId': sessionId});

  Future<bool> verifyPaytm(String sessionId) async {
    final result = await WorkerApi.post('/api/paytm/verify', {'orderId': sessionId});
    return result['paid'] == true;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPayment(String orderId) =>
      db.collection('orders').doc(orderId).snapshots();

  Future<void> markPaidByAuthorizedStaff(String orderId, String transactionId) async {
    if (auth.currentUser == null) throw Exception('कृपया पहले लॉगिन करें।');
    if (transactionId.trim().length < 3) throw Exception('रसीद या लेन-देन संदर्भ संख्या जरूरी है।');
    await WorkerApi.post('/api/admin/markOrderPaid', {
      'orderId': orderId,
      'transactionId': transactionId.trim(),
    });
  }
}
