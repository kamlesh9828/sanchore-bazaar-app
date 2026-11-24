
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fee_settings_service.dart';
import 'worker_api.dart';

class AdminService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  String get uid {
    final user = auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  Future<void> checkAdmin() async {
    final doc = await db.collection('users').doc(uid).get();

    if (!doc.exists ||
        doc.data()?['role'] != 'admin' ||
        doc.data()?['approved'] != true) {
      throw Exception('Admin permission required');
    }
  }

  // Pending shops
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingShops() {
    return db.collection('shop_requests').where('status', isEqualTo: 'pending').snapshots();
  }

  // Admin approval creates the shop; rejection stores a reason for the owner.
  Future<void> reviewShopRequest(String requestId, bool approved, {String reason = ''}) async {
    await checkAdmin();
    await WorkerApi.post('/api/admin/reviewShopRequest', {
      'requestId': requestId, 'approved': approved, if (!approved) 'reason': reason.trim(),
    });
  }

  @Deprecated('Use reviewShopRequest; shops are created only after Admin approval.')
  Future<void> approveShop(String shopId, bool approved) async {
    throw Exception('पुराने दुकान approval का उपयोग बंद है। नई रिक्वेस्ट सूची से मंजूरी दें।');
  }

  // Pending staff
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingStaff() {
    return db.collection('users')
        .where('approved', isEqualTo: false)
        .snapshots();
  }

  // Approve shopkeeper or delivery worker
  Future<void> approveStaff(String userId, bool approved) async {
    await checkAdmin();

    final ref = db.collection('users').doc(userId);
    final doc = await ref.get();

    if (!doc.exists) throw Exception('User not found');

    final role = doc.data()?['role'];

    if (role != 'shopkeeper' && role != 'delivery') {
      throw Exception('Invalid staff role');
    }

    await WorkerApi.post('/api/approveStaff', {'userId': userId, 'approved': approved});
  }

  // All orders for admin
  Stream<QuerySnapshot<Map<String, dynamic>>> allOrders() {
    return db.collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Assign order to delivery worker
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryBoyId,
  }) async {
    await checkAdmin();
    await WorkerApi.post('/api/assignDelivery', {
      'orderId': orderId,
      'deliveryBoyId': deliveryBoyId,
    });
  }

  // Service area management
  Future<void> addServiceArea({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    if (radiusKm <= 0 || radiusKm > 100) {
      throw Exception('Invalid service radius');
    }

    await WorkerApi.post('/api/admin/addServiceArea', {
      'name': name.trim(), 'latitude': latitude, 'longitude': longitude,
      'radiusKm': radiusKm,
    });
  }

  Future<List<Map<String, dynamic>>> serviceAreas() async {
    final response = await WorkerApi.post('/api/admin/listServiceAreas', <String, dynamic>{});
    final raw = response['areas'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addPinCodeArea({required String name, required String pinCode}) async {
    final pin = pinCode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) throw Exception('सही 6 अंकों का PIN कोड भरें।');
    await WorkerApi.post('/api/admin/addServiceArea', {
      'name': name.trim().isEmpty ? 'PIN $pin' : name.trim(), 'pinCode': pin,
    });
  }

  Future<void> deleteServiceArea(String areaId) async {
    await WorkerApi.post('/api/admin/deleteServiceArea', {'areaId': areaId});
  }

  Future<void> updateServiceArea(
      String areaId, bool active) async {
    await WorkerApi.post('/api/admin/updateServiceArea', {'areaId': areaId, 'active': active});
  }

  // Promotions
  Future<void> addPromotion({
    required String title,
    required String description,
    required double discountPercent,
  }) async {
    await checkAdmin();

    if (discountPercent < 0 || discountPercent > 100) {
      throw Exception('Invalid discount');
    }

    await db.collection('promotions').add({
      'title': title,
      'description': description,
      'discountPercent': discountPercent,
      'active': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> promotions() {
    return db.collection('promotions').snapshots();
  }

  Future<void> setPromotionStatus(
      String promotionId, bool active) async {
    await checkAdmin();

    await db.collection('promotions').doc(promotionId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Complaints
  Stream<QuerySnapshot<Map<String, dynamic>>> complaints() {
    return db.collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> resolveComplaint(String complaintId) async {
    await checkAdmin();

    await db.collection('complaints').doc(complaintId).update({
      'status': 'resolved',
      'resolvedBy': uid,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> listCodAccounts() async {
    await checkAdmin();
    final response = await WorkerApi.post('/api/admin/listCodAccounts', <String, dynamic>{});
    List<Map<String, dynamic>> rows(dynamic value) => value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    return {'customers': rows(response['customers']), 'shops': rows(response['shops'])};
  }

  Future<void> setCodOverride({required String targetType, required String targetId, required bool enabled}) async {
    await checkAdmin();
    await WorkerApi.post('/api/admin/setCodOverride', {
      'targetType': targetType, 'targetId': targetId, 'enabled': enabled,
    });
  }

  Future<void> deactivateStaff(String userId) async {
    await checkAdmin();
    await WorkerApi.post('/api/admin/deactivateStaff', {'userId': userId});
  }

  Future<void> reactivateStaff(String userId) async {
    await checkAdmin();
    await WorkerApi.post('/api/admin/reactivateStaff', {'userId': userId});
  }

  Future<void> saveCodEnabled(bool enabled) async {
    await checkAdmin();
    await WorkerApi.post('/api/admin/savePaymentSettings', {'codEnabled': enabled});
  }

  // Fee settings: use secure backend function, not direct write.
  Future<void> saveFees({
    required double commissionPercent,
    required double deliveryPayout,
    required double customerDeliveryCharge,
    required double platformFee,
    String deliveryPayer = 'company',
  }) async {
    await checkAdmin();
    await FeeSettingsService().save(
      commissionPercent: commissionPercent,
      deliveryPayout: deliveryPayout,
      customerDeliveryCharge: customerDeliveryCharge,
      platformFee: platformFee,
      deliveryPayer: deliveryPayer,
    );
  }
  Future<void> markDeliveryEarningPaid({required String recordId, required String paymentReference}) async {
    await checkAdmin();
    if (paymentReference.trim().length < 3) throw Exception('Payment reference likhein');
    await WorkerApi.post('/api/admin/markDeliveryEarningPaid', {
      'recordId': recordId, 'paymentReference': paymentReference.trim(),
    });
  }

  Future<void> markShopkeeperSettlementPaid({required String recordId, required String paymentReference}) async {
    await checkAdmin();
    if (paymentReference.trim().length < 3) throw Exception('Payment reference likhein');
    await WorkerApi.post('/api/admin/markShopkeeperSettlementPaid', {
      'recordId': recordId, 'paymentReference': paymentReference.trim(),
    });
  }

  Future<void> markRefundObligationPaid({required String recordId, required String paymentReference}) async {
    await checkAdmin();
    if (paymentReference.trim().length < 3) throw Exception('Payment reference likhein');
    await WorkerApi.post('/api/admin/markRefundObligationPaid', {
      'recordId': recordId, 'paymentReference': paymentReference.trim(),
    });
  }

}
