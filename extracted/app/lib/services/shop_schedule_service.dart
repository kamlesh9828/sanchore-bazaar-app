import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_api.dart';

class ShopScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveSchedule({
    required String shopId,
    required Map<String, dynamic> weeklySchedule,
    required List<String> holidays,
  }) async {
    if (shopId.trim().isEmpty) throw Exception('दुकान चुनें।');
    await WorkerApi.post('/api/updateShopSchedule', {
      'shopId': shopId,
      'weeklySchedule': weeklySchedule,
      'holidays': holidays,
    });
  }

  Future<void> setShopOpen(
      {required String shopId, required bool isOpen}) async {
    if (shopId.trim().isEmpty) throw Exception('दुकान चुनें।');
    await WorkerApi.post('/api/updateShopSchedule', {
      'shopId': shopId,
      'isOpen': isOpen,
    });
  }


  Future<void> setDeliveryEstimate({required String shopId, required int minutes}) async {
    if (minutes < 5 || minutes > 240) throw Exception('समय 5 से 240 मिनट के बीच रखें');
    await WorkerApi.post('/api/updateShopSchedule', {
      'shopId': shopId,
      'estimatedDeliveryMinutes': minutes,
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchShop(String shopId) =>
      _db.collection('shops').doc(shopId).snapshots();
}
