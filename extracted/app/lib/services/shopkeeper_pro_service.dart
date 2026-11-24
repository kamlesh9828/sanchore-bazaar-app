import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

class ShopkeeperProService {
  Future<Map<String, dynamic>> info(String shopId) =>
      WorkerApi.post('/api/shopkeeper/proInfo', {'shopId': shopId});

  Future<Map<String, dynamic>> createPayment({required String shopId, required String planId}) =>
      WorkerApi.post('/api/shopkeeper/createProPayment', {'shopId': shopId, 'planId': planId});

  Future<Map<String, dynamic>> initiatePayment(String sessionId) =>
      WorkerApi.post('/api/paytm/initiate', {'sessionId': sessionId});

  Stream<QuerySnapshot<Map<String, dynamic>>> myShops() =>
      FirebaseFirestore.instance.collection('shops')
          .where('ownerId', isEqualTo: _uid)
          .snapshots();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? ''; 
}
