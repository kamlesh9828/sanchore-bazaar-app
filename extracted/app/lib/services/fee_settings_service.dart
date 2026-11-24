import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'worker_api.dart';

class FeeSettingsService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchFees() =>
      db.collection('settings').doc('fees').snapshots();

  Future<void> save({
    required double commissionPercent,
    required double deliveryPayout,
    required double customerDeliveryCharge,
    required double platformFee,
    String deliveryPayer = 'company',
  }) async {
    if (auth.currentUser == null) throw Exception('कृपया पहले लॉगिन करें।');
    if (commissionPercent < 0 || commissionPercent > 100 ||
        deliveryPayout < 0 || customerDeliveryCharge < 0 || platformFee < 0 ||
        !['company', 'customer', 'shopkeeper', 'split'].contains(deliveryPayer)) {
      throw Exception('शुल्क की सभी राशियाँ सही भरें।');
    }
    await WorkerApi.post('/api/saveFeeSettings', {
      'commissionPercent': commissionPercent,
      'deliveryPayout': deliveryPayout,
      'customerDeliveryCharge': customerDeliveryCharge,
      'platformFee': platformFee,
      'deliveryPayer': deliveryPayer,
    });
  }
}
