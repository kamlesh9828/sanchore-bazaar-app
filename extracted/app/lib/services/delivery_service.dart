
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'worker_api.dart';

class DeliveryService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  StreamSubscription<Position>? gpsSubscription;
  Timer? presenceTimer;

  String get uid {
    final user = auth.currentUser;
    if (user == null) throw Exception('कृपया पहले लॉगिन करें।');
    return user.uid;
  }

  // Assigned orders
  Stream<QuerySnapshot<Map<String, dynamic>>> myOrders() {
    return db.collection('orders')
        .where('deliveryBoyId', isEqualTo: uid)
        .snapshots();
  }


  Stream<QuerySnapshot<Map<String, dynamic>>> myOffers() => db.collection('orders')
      .where('deliveryOfferTo', isEqualTo: uid).snapshots();

  Future<void> setAvailability(bool available) async {
    double? latitude;
    double? longitude;
    if (available) {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('फ़ोन का GPS चालू करें।');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw Exception('ऐप को लोकेशन की अनुमति दें।');
      }
      final position = await Geolocator.getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    }
    await WorkerApi.post('/api/setDeliveryAvailability', {
      'available': available,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    presenceTimer?.cancel();
    if (available) {
      presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
        try {
          final p = await Geolocator.getCurrentPosition();
          await WorkerApi.post('/api/updateDeliveryPresence', {
            'latitude': p.latitude, 'longitude': p.longitude,
          });
        } catch (_) {
          // A failed heartbeat is retried on the next two-minute tick.
        }
      });
    }
  }

  Future<void> respondToOffer({required String orderId, required bool accept}) async {
    await WorkerApi.post('/api/respondDeliveryOffer', {'orderId': orderId, 'accept': accept});
  }

  // Start live GPS tracking for an assigned order
  Future<void> startTracking(String orderId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('फ़ोन का GPS चालू करें।');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw Exception('ऐप को लोकेशन की अनुमति दें।');
    }

    final orderRef = db.collection('orders').doc(orderId);
    final order = await orderRef.get();

    if (!order.exists || order.data()?['deliveryBoyId'] != uid ||
        !['ready', 'assigned', 'picked_up'].contains(order.data()?['status'])) {
      throw Exception('यह सक्रिय ऑर्डर आपको नहीं सौंपा गया है।');
    }

    await gpsSubscription?.cancel();

    gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) async {
      try {
        await WorkerApi.post('/api/updateDeliveryLocation', {
          'orderId': orderId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      } catch (_) {
        // Location update failed; retry on next GPS event.
      }
    });
  }

  // Stop tracking
  Future<void> stopTracking() async {
    await gpsSubscription?.cancel();
    gpsSubscription = null;
  }

  // Update delivery status
  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    const allowed = [
      'picked_up',
      'delivered',
    ];

    if (!allowed.contains(status)) {
      throw Exception('Invalid status');
    }

    await WorkerApi.post('/api/updateStaffOrder', {
      'orderId': orderId,
      'status': status,
    });

    if (status == 'delivered') {
      await stopTracking();
    }
  }

  // Delivery earnings
  Stream<QuerySnapshot<Map<String, dynamic>>> myEarnings() {
    return db.collection('delivery_earnings')
        .where('deliveryBoyId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void dispose() {
    presenceTimer?.cancel();
    stopTracking();
  }
}
