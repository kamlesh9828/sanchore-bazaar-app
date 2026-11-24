import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String get uid => auth.currentUser?.uid ?? (throw Exception('कृपया पहले लॉगिन करें।'));
  CollectionReference<Map<String, dynamic>> get _ref => db.collection('users').doc(uid).collection('addresses');
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAddresses() => _ref.orderBy('createdAt', descending: true).snapshots();

  Future<String> addAddress({required String label, required String address, String customerName = '', String phone = '', String pinCode = '', String house = '', String street = '', String area = '', String landmark = '', String city = '', String district = '', String state = '', double? latitude, double? longitude}) async {
    if (address.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(pinCode.trim())) throw Exception('पूरा पता और 6 अंकों का PIN Code सही भरें');
    if (customerName.trim().length < 2 || phone.replaceAll(RegExp(r'\D'), '').length < 10) throw Exception('ग्राहक का नाम और 10 अंकों का मोबाइल नंबर भरें');
    final data = <String, dynamic>{'label': label.trim().isEmpty ? 'Home' : label.trim(), 'customerName': customerName.trim(), 'phone': phone.trim(), 'address': address.trim(), 'pinCode': pinCode.trim(), 'house': house.trim(), 'street': street.trim(), 'area': area.trim(), 'landmark': landmark.trim(), 'city': city.trim(), 'district': district.trim(), 'state': state.trim(), 'createdAt': FieldValue.serverTimestamp()};
    if (latitude != null && longitude != null) data['location'] = GeoPoint(latitude, longitude);
    final doc = await _ref.add(data); return doc.id;
  }
  Future<void> updateAddress(String id, {required String label, required String address, String customerName = '', String phone = '', String pinCode = '', String house = '', String street = '', String area = '', String landmark = '', String city = '', String district = '', String state = '', double? latitude, double? longitude}) async {
    final data = <String, dynamic>{'label': label.trim(), 'customerName': customerName.trim(), 'phone': phone.trim(), 'address': address.trim(), 'pinCode': pinCode.trim(), 'house': house.trim(), 'street': street.trim(), 'area': area.trim(), 'landmark': landmark.trim(), 'city': city.trim(), 'district': district.trim(), 'state': state.trim(), 'updatedAt': FieldValue.serverTimestamp()};
    if (latitude != null && longitude != null) data['location'] = GeoPoint(latitude, longitude);
    await _ref.doc(id).update(data);
  }
  Future<void> deleteAddress(String id) => _ref.doc(id).delete();
}
