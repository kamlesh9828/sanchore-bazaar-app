import 'package:firebase_auth/firebase_auth.dart';
import 'worker_api.dart';

/// Customer registration and pending staff applications.
class AuthService {
  final FirebaseAuth auth;

  AuthService({FirebaseAuth? auth}) : auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => auth.currentUser;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  Future<UserCredential> loginWithGoogle() =>
      auth.signInWithProvider(GoogleAuthProvider());

  Future<UserCredential> loginWithApple() {
    final provider = AppleAuthProvider()..addScope('email')..addScope('name');
    return auth.signInWithProvider(provider);
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) =>
      auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  Future<UserCredential> registerCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('खाता नहीं बन सका। कृपया दोबारा प्रयास करें।');
    }

    await WorkerApi.post('/api/registerCustomerProfile', {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
    });

    return credential;
  }

  Future<UserCredential> registerShopkeeper({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) =>
      _registerStaff(
        role: 'shopkeeper',
        name: name,
        phone: phone,
        email: email,
        password: password,
      );

  Future<UserCredential> registerDelivery({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) =>
      _registerStaff(
        role: 'delivery',
        name: name,
        phone: phone,
        email: email,
        password: password,
      );

  Future<UserCredential> _registerStaff({
    required String role,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (name.trim().length < 2 ||
        phone.trim().length < 8 ||
        password.length < 6) {
      throw Exception(
        'नाम, सही मोबाइल नंबर और कम से कम 6 अक्षरों का पासवर्ड भरें।',
      );
    }

    final enteredEmail = email.trim().toLowerCase();
    final signedInUser = auth.currentUser;

    // Same account already logged in: use its existing session.
    if (signedInUser != null &&
        (signedInUser.email ?? '').toLowerCase() == enteredEmail) {
      await WorkerApi.post('/api/applyStaffRegistration', {
        'role': role,
        'name': name.trim(),
        'phone': phone.trim(),
        'email': enteredEmail,
      });

      return await auth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: password,
      );
    }

    // Different old account: logout automatically.
    if (signedInUser != null) {
      await auth.signOut();
    }

    // Create and login the new staff account.
    final credential = await auth.createUserWithEmailAndPassword(
      email: enteredEmail,
      password: password,
    );

    // Submit application through Cloudflare Worker.
    await WorkerApi.post('/api/applyStaffRegistration', {
      'role': role,
      'name': name.trim(),
      'phone': phone.trim(),
      'email': enteredEmail,
    });

    return credential;
  }

  Future<void> logout() => auth.signOut();

  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
}
