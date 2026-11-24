import 'screens/admin_revenue_screen.dart';
import 'screens/shopkeeper_pro_screen.dart';
import 'utils/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'services/fee_settings_service.dart';
import 'services/service_area_service.dart';
import 'services/auth_service.dart';
import 'services/worker_api.dart';
import 'services/admin_service.dart';
import 'services/delivery_service.dart';
import 'services/shopkeeper_service.dart';
import 'services/cart_service.dart';
import 'services/coupon_service.dart';
import 'services/order_service.dart';
import 'services/payment_service.dart';
import 'screens/paytm_checkout_screen.dart';
import 'screens/order_success_screen.dart';
import 'screens/customer_wallet_screen.dart';
import 'screens/extended_screens.dart';
import 'services/admob_service.dart';
import 'widgets/admob_banner.dart';
import 'screens/ad_management_screens.dart';
import 'services/image_service.dart';
import 'widgets/add_product_dialog.dart';



DateTime? _sanchoreDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse((value ?? '').toString());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? firebaseInitError;
  try {
    if (kIsWeb) {
      if (!DefaultFirebaseOptions.isWebConfigured) {
        throw StateError(
            'Firebase Web config missing. Project ke Firebase Web App values build mein dene honge.');
      }
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    firebaseInitError = e;
  }

  if (firebaseInitError == null && !kIsWeb) {
    try {
      await AdMobService.initialize();
    } catch (_) {
      // App must still open if ads are unavailable.
    }
  }

  runApp(firebaseInitError == null
      ? const SanchoreBazaarApp()
      : FirebaseSetupRequiredApp(error: firebaseInitError.toString()));
}

class FirebaseSetupRequiredApp extends StatelessWidget {
  final String error;

  const FirebaseSetupRequiredApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Sanchore Bazaar Setup',
        home: Scaffold(
          appBar: AppBar(title: const Text('सांचौर बाज़ार – Firebase सेटिंग')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Firebase सेटिंग पूरी नहीं है।',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  'Firebase Console में Web App पंजीकृत करके FlutterFire की Web सेटिंग पूरी करें। Android की google-services.json फ़ाइल से Web App ID नहीं मिलती।'),
              const SizedBox(height: 12),
              SelectableText(error, style: const TextStyle(color: Colors.red)),
            ]),
          ),
        ),
      );
}

final db = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;

final ValueNotifier<int> appScreenVersion = ValueNotifier<int>(0);

class _AppScreenObserver extends NavigatorObserver {
  void _screenChanged() => appScreenVersion.value++;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _screenChanged();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _screenChanged();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _screenChanged();
}

class _GlobalBannerHost extends StatefulWidget {
  final Widget child;
  const _GlobalBannerHost({required this.child});
  @override
  State<_GlobalBannerHost> createState() => _GlobalBannerHostState();
}

class _GlobalBannerHostState extends State<_GlobalBannerHost> {
  bool _hidden = false;
  bool _adReady = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    appScreenVersion.addListener(_onScreenChanged);
  }
  void _onScreenChanged() {
    if (!mounted) return;
    setState(() {
      _version = appScreenVersion.value;
      _hidden = false;
      _adReady = false;
    });
  }
  @override
  void dispose() {
    appScreenVersion.removeListener(_onScreenChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: widget.child),
      if (!_hidden && !kIsWeb)
        SafeArea(top: false, child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AdMobBanner(
                key: ValueKey('global-banner-$_version'),
                onAdLoaded: (loaded) {
                  if (mounted && loaded && !_adReady) setState(() => _adReady = true);
                },
              ),
              if (_adReady)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'विज्ञापन छिपाएँ',
                    visualDensity: VisualDensity.compact,
                    iconSize: 19,
                    onPressed: () => setState(() => _hidden = true),
                    icon: const Icon(Icons.close),
                  ),
                ),
            ]),
          ),
        )),
    ]);
  }
}

class SanchoreBazaarApp extends StatelessWidget {
  const SanchoreBazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_AppScreenObserver()],
      builder: (context, child) => _GlobalBannerHost(child: child ?? const SizedBox.shrink()),
      title: 'सांचौर बाज़ार',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B5FEF),
          primary: const Color(0xFF5257D9),
          secondary: const Color(0xFFFFB547),
          tertiary: const Color(0xFF16A6A1),
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F5FB),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF18213B), letterSpacing: -.4),
          titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF18213B)),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF26314D)),
          bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF66708A)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171C36),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .2),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shadowColor: Color(0x125257D9),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFFE9EAF5))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF5257D9), width: 2)),
        ),
        // Brand buttons: clear contrast, soft glow and a quick press-state transition.
        elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) return const Color(0xFFB8C2CC);
            if (states.contains(MaterialState.pressed)) return const Color(0xFF075E68);
            if (states.contains(MaterialState.hovered)) return const Color(0xFF096F7A);
            return const Color(0xFF087F8C);
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          overlayColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.pressed) ? const Color(0x33FFFFFF) : const Color(0x14087F8C)),
          elevation: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.pressed) ? 1 : 5),
          shadowColor: MaterialStateProperty.all(const Color(0x55087F8C)),
          animationDuration: const Duration(milliseconds: 180),
          minimumSize: MaterialStateProperty.all(const Size(48, 52)),
          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 21, vertical: 14)),
          shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
          textStyle: MaterialStateProperty.all(const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3)),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3442A5),
          side: const BorderSide(color: Color(0xFFBFC7F5), width: 1.3),
          minimumSize: const Size(46, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          overlayColor: const Color(0x1A5257D9),
          animationDuration: const Duration(milliseconds: 180),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        )),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3442A5),
          overlayColor: const Color(0x1A5257D9),
          animationDuration: const Duration(milliseconds: 160),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        )),
        iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF3442A5),
          highlightColor: const Color(0x225257D9),
          hoverColor: const Color(0x145257D9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        )),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEFF2FF),
          selectedColor: const Color(0xFFDDE4FF),
          disabledColor: const Color(0xFFF0F2F5),
          secondarySelectedColor: const Color(0xFFD9F4F0),
          labelStyle: const TextStyle(color: Color(0xFF3442A5), fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          side: const BorderSide(color: Color(0xFFE0E5F5)),
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF101D32), contentTextStyle: TextStyle(color: Colors.white)),
      ),
      home: const AdMobLifecycle(child: SessionRestoreScreen()),
    );
  }
}

class SessionRestoreScreen extends StatelessWidget {
  const SessionRestoreScreen({super.key});

  Future<Widget> _destination() async {
    final user = auth.currentUser;
    if (user == null) return const LoginScreen();
    try {
      final doc = await db.collection('users').doc(user.uid).get();
      if (!doc.exists) return const LoginScreen();
      final data = doc.data() ?? <String, dynamic>{};
      if (data['active'] == false || (data['role'] != 'customer' && data['approved'] != true)) {
        await auth.signOut();
        return const LoginScreen();
      }
      switch ((data['role'] ?? 'customer').toString()) {
        case 'admin': return const AdminPanel();
        case 'shopkeeper': return const ShopkeeperPanel();
        case 'delivery': return const DeliveryPanel();
        default: return const CustomerHome();
      }
    } catch (_) {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _destination(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return snapshot.data!;
    },
  );
}

class AdMobLifecycle extends StatefulWidget {
  final Widget child;
  const AdMobLifecycle({super.key, required this.child});

  @override
  State<AdMobLifecycle> createState() => _AdMobLifecycleState();
}

class _AdMobLifecycleState extends State<AdMobLifecycle>
    with WidgetsBindingObserver {
  bool _wentToBackground = false;
  DateTime? _lastAppOpenAdAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wentToBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      final now = DateTime.now();
      final last = _lastAppOpenAdAt;
      if (last == null || now.difference(last) >= const Duration(hours: 4)) {
        _lastAppOpenAdAt = now;
        AdMobService.showAppOpenAdIfAvailable();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? emailError;
  String? passwordError;

  Future<void> login() async {
    setState(() {
      emailError = null;
      passwordError = null;
    });
    final enteredEmail = email.text.trim();
    if (enteredEmail.isEmpty) {
      setState(() => emailError = 'ईमेल डालना ज़रूरी है।');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(enteredEmail)) {
      setState(() => emailError = 'सही ईमेल एड्रेस डालें।');
      return;
    }
    if (password.text.isEmpty) {
      setState(() => passwordError = 'पासवर्ड डालना ज़रूरी है।');
      return;
    }

    setState(() => loading = true);

    try {
      final result = await auth.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      await result.user!.reload();
      final verifiedUser = auth.currentUser;
      final doc = await db.collection('users').doc(result.user!.uid).get();

      if (!doc.exists) {
        await auth.signOut();
        if (!mounted) return;
        message('आपकी प्रोफ़ाइल नहीं मिली। कृपया एडमिन से संपर्क करें।');
        return;
      }

      final data = doc.data()!;
      if (verifiedUser == null) {
        await auth.signOut();
        if (!mounted) return;
        message('लॉगिन सत्र नहीं मिला। दोबारा प्रयास करें।');
        return;
      }
      final role = data['role'] ?? 'customer';
      final approved = data['approved'] ?? false;

      if (role != 'customer' && approved != true) {
        await auth.signOut();
        if (!mounted) return;
        message('आपके खाते को अभी मंज़ूरी नहीं मिली है।');
        return;
      }

      if (!mounted) return;

      Widget page;
      if (role == 'admin') {
        page = const AdminPanel();
      } else if (role == 'shopkeeper') {
        page = const ShopkeeperPanel();
      } else if (role == 'delivery') {
        page = const DeliveryPanel();
      } else {
        page = const CustomerHome();
      }

      TextInput.finishAutofillContext(shouldSave: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'invalid-email') {
        setState(() => emailError = 'ईमेल का फॉर्मेट सही नहीं है।');
      } else if (['user-not-found', 'wrong-password', 'invalid-credential'].contains(e.code)) {
        setState(() => passwordError = 'ईमेल या पासवर्ड गलत है।');
      } else if (e.code == 'too-many-requests') {
        message('बहुत बार कोशिश हुई है। कुछ देर बाद दोबारा प्रयास करें।');
      } else if (e.code == 'network-request-failed') {
        message('इंटरनेट कनेक्शन जाँचें।');
      } else {
        message(e.message ?? 'लॉगिन नहीं हो पाया।');
      }
    } catch (e) {
      if (mounted) {
        message('त्रुटि: ${AppLabels.serverError(e)}');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loginWithSocial(bool apple) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final service = AuthService();
      final credential = apple
          ? await service.loginWithApple()
          : await service.loginWithGoogle();
      final user = credential.user;
      if (user == null) throw Exception('खाता पहचान नहीं मिली।');
      var doc = await db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final nameController = TextEditingController(text: user.displayName ?? '');
        final phoneController = TextEditingController();
        final details = await showDialog<List<String>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('ग्राहक प्रोफाइल पूरा करें'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'पूरा नाम')),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'मोबाइल नंबर')),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बाद में')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, [nameController.text.trim(), phoneController.text.trim()]), child: const Text('सेव करें'))],
          ),
        );
        nameController.dispose(); phoneController.dispose();
        if (details == null) { await auth.signOut(); return; }
        await WorkerApi.post('/api/registerCustomerProfile', {
          'name': details[0], 'phone': details[1], 'email': user.email ?? '',
        });
        doc = await db.collection('users').doc(user.uid).get();
      }
      if (!doc.exists) throw Exception('प्रोफाइल नहीं बन पाई। सहायता से संपर्क करें।');
      final role = doc.data()?['role'] ?? 'customer';
      final approved = doc.data()?['approved'] ?? false;
      if (role != 'customer' && approved != true) throw Exception('आपके खाते को अभी मंजूरी नहीं मिली है।');
      if (!mounted) return;
      final Widget page = role == 'admin' ? const AdminPanel() : role == 'shopkeeper' ? const ShopkeeperPanel() : role == 'delivery' ? const DeliveryPanel() : const CustomerHome();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
    } on FirebaseAuthException catch (e) {
      if (mounted) message(e.message ?? 'लॉगिन नहीं हो पाया।');
    } catch (e) {
      if (mounted) message('त्रुटि: ${AppLabels.serverError(e)}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> forgotPassword() async {
    final controller = TextEditingController(text: email.text.trim());
    final enteredEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('पासवर्ड रीसेट करें'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'रजिस्टर्ड ईमेल'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('रद्द करें')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('लिंक भेजें')),
        ],
      ),
    );
    controller.dispose();
    if (enteredEmail == null || enteredEmail.isEmpty) return;
    try {
      await AuthService().resetPassword(enteredEmail);
      if (mounted) message('पासवर्ड रीसेट लिंक ईमेल पर भेज दिया है। Inbox/Spam जाँचें।');
    } on FirebaseAuthException catch (e) {
      if (mounted) message(e.message ?? 'रीसेट लिंक नहीं भेजा जा सका।');
    } catch (e) {
      if (mounted) message('त्रुटि: ${AppLabels.serverError(e)}');
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 112, height: 112,
                decoration: BoxDecoration(color: const Color(0xFFE3F3EB), borderRadius: BorderRadius.circular(32)),
                padding: const EdgeInsets.all(13),
                child: Image.asset('assets/branding/sanchore_bazaar_app_icon.png', fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 72, color: Color(0xFF087E58))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://sanchorebazaar.bg5.net/'), mode: LaunchMode.externalApplication),
                child: const Text('SANCHORE BAZAAR',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              const Text('आपके शहर का अपना बाज़ार', style: TextStyle(color: Colors.black54, fontSize: 14)),
              const SizedBox(height: 30),
              Align(alignment: Alignment.centerLeft, child: Text('Welcome back!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(height: 5),
              const Align(alignment: Alignment.centerLeft, child: Text('लॉगिन करके अपना बाज़ार देखें', style: TextStyle(color: Colors.black54))),
              const SizedBox(height: 18),
              AutofillGroup(
                child: Column(children: [
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) { if (emailError != null) setState(() => emailError = null); },
                    decoration: InputDecoration(
                      labelText: 'ईमेल पता',
                      errorText: emailError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => loading ? null : login(),
                    onChanged: (_) { if (passwordError != null) setState(() => passwordError = null); },
                    decoration: InputDecoration(
                      labelText: 'पासवर्ड',
                      errorText: passwordError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ]),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : forgotPassword,
                  child: const Text('पासवर्ड भूल गए?'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  child: Text(loading ? 'कृपया प्रतीक्षा करें…' : 'लॉगिन करें'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : () => loginWithSocial(false),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Google से जारी रखें'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading ? null : () => loginWithSocial(true),
                icon: const Icon(Icons.apple, size: 24),
                label: const Text('Apple से जारी रखें'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const CustomerRegistrationScreen())),
                child: const Text('नए ग्राहक हैं? खाता बनाएँ'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StaffRegistrationScreen(
                                role: 'shopkeeper'))),
                child: const Text('दुकानदार पंजीकरण'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StaffRegistrationScreen(
                                role: 'delivery'))),
                child: const Text('डिलीवरी पार्टनर पंजीकरण'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => launchUrl(Uri.parse('https://sanchorebazaar.bg5.net/'), mode: LaunchMode.externalApplication),
          child: const Text('सांचौर बाज़ार'),
        ),
        actions: [
          IconButton(
              tooltip: 'मेरा वॉलेट',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerWalletScreen())),
          ),
          IconButton(
              tooltip: 'मेरा कार्ट',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartCheckoutScreen())),
          ),
          IconButton(
              tooltip: 'मेरे ऑर्डर',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerOrdersScreen()))),
          IconButton(
              tooltip: 'सहायता और संपर्क',
              icon: const Icon(Icons.support_agent),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerSupportScreen()))),
          IconButton(
              tooltip: 'मेरा खाता',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerAccountScreen()))),
          IconButton(
            tooltip: 'लॉगआउट',
            onPressed: () async {
              try {
                await auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('लॉगआउट नहीं हो सका: ${AppLabels.serverError(e)}')),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('shops')
            .where('approved', isEqualTo: true)
            .where('active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('जानकारी लोड नहीं हो सकी।'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final shops = snapshot.data!.docs.toList()..sort((a, b) {
            bool proActive(QueryDocumentSnapshot doc) {
              final d = doc.data() as Map<String, dynamic>;
              final until = _sanchoreDate(d['proUntil']);
              return d['proStatus'] == 'active' && until != null && until.isAfter(DateTime.now());
            }
            return (proActive(b) ? 1 : 0).compareTo(proActive(a) ? 1 : 0);
          });

          if (shops.isEmpty) {
            return Column(
              children: [
                ActiveAdBanners(
                  onOpenShop: (shopId, shopName) {
                    if (shopId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsScreen(
                          shopId: shopId,
                          shopName: shopName,
                        ),
                      ),
                    ).then((_) => AdMobService.maybeShowInterstitialAfterShopVisit());
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text('अभी कोई दुकान उपलब्ध नहीं है।'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            itemCount: shops.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return Container(margin: const EdgeInsets.fromLTRB(14, 14, 14, 8), padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4148A8), Color(0xFF168F99)]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('सांचौर बाज़ार में आपका स्वागत है', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('अपनी पसंद की दुकान से सामान मँगवाएँ', style: TextStyle(color: Colors.white70))]));
              if (index == 1) {
                return ActiveAdBanners(
                  onOpenShop: (shopId, shopName) {
                    if (shopId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsScreen(
                          shopId: shopId,
                          shopName: shopName,
                        ),
                      ),
                    ).then((_) => AdMobService.maybeShowInterstitialAfterShopVisit());
                  },
                );
              }
              final shopIndex = index - 2;
              final shop = shops[shopIndex].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Row(children: [Expanded(child: Text(shop['name'] ?? 'दुकान')), if (shop['proStatus'] == 'active' && _sanchoreDate(shop['proUntil'])?.isAfter(DateTime.now()) == true) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFF1C9), borderRadius: BorderRadius.circular(8)), child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF946200))))]),
                  subtitle: Text(shop['address'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopProductsScreen(
                          shopId: shops[shopIndex].id,
                          shopName: shop['name'] ?? 'दुकान',
                        ),
                      )).then((_) => AdMobService.maybeShowInterstitialAfterShopVisit()),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: OrderService().customerOrders(),
        builder: (context, ordersSnap) {
          if (!ordersSnap.hasData || ordersSnap.hasError) return const SizedBox.shrink();
          final active = ordersSnap.data!.docs.where((d) {
            final status = (d.data()['status'] ?? 'placed').toString().toLowerCase();
            return !['delivered', 'cancelled', 'canceled', 'rejected', 'payment_failed', 'failed'].contains(status);
          }).toList()..sort((a, b) {
            final av = a.data()['createdAt']; final bv = b.data()['createdAt'];
            final ad = av is Timestamp ? av.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final bd = bv is Timestamp ? bv.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });
          if (active.isEmpty) return const SizedBox.shrink();
          final order = active.first;
          final status = (order.data()['status'] ?? 'placed').toString().toLowerCase();
          final statusLabel = AppLabels.effectiveOrderStatus(status, deliveryBoyId: order.data()['deliveryBoyId']);
          return SafeArea(top: false, child: Material(color: const Color(0xFF102A43), child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerOrderDetailScreen(orderId: order.id))),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [
              const CircleAvatar(backgroundColor: Color(0xFF087E58), child: Icon(Icons.delivery_dining, color: Colors.white)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(statusLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const Text('ऑर्डर की लाइव स्थिति देखने के लिए यहाँ टैप करें', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              const Icon(Icons.chevron_right, color: Colors.white),
            ])),
          )));
        },
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.storefront_rounded, size: 25),
          const SizedBox(width: 9),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://sanchorebazaar.bg5.net/'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'SANCHORE BAZAAR',
              style: TextStyle(fontSize: 16, letterSpacing: 1.1),
            ),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'एडमिन प्रबंधन', icon: const Icon(Icons.grid_view_rounded), onPressed: () => _open(context, const AdminOperationsScreen())),
          IconButton(tooltip: 'लॉगआउट', onPressed: () async {
            await auth.signOut();
            if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF171C36), Color(0xFF4148A8), Color(0xFF168F99)]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x26101D32), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFB8F2DF).withOpacity(.16), borderRadius: BorderRadius.circular(30)), child: const Text('एडमिन नियंत्रण', style: TextStyle(color: Color(0xFFB8F2DF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
              ]),
              const SizedBox(height: 18),
              const Text('नमस्ते, एडमिन 👋', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('आपके पूरे बाज़ार का कंट्रोल सेंटर', style: TextStyle(color: Color(0xFFD7E8F1), fontSize: 13)),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(width: (MediaQuery.of(context).size.width - 130) / 2, child: _adminMetric(context, 'दुकानें', 'shops', Icons.storefront_rounded)),
                SizedBox(width: (MediaQuery.of(context).size.width - 130) / 2, child: _adminMetric(context, 'ग्राहक', 'users', Icons.people_alt_rounded)),
                SizedBox(width: (MediaQuery.of(context).size.width - 130) / 2, child: _adminMetric(context, 'कुल ऑर्डर', 'orders', Icons.receipt_long_rounded)),
                SizedBox(width: (MediaQuery.of(context).size.width - 130) / 2, child: _adminSalesMetric(context)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('orders').snapshots(),
            builder: (context, snap) {
              final urgent = (snap.data?.docs ?? []).where((d) {
                final status = (d.data()['status'] ?? '').toString().toLowerCase();
                return ['pending', 'placed', 'new', 'confirmed'].contains(status);
              }).length;
              if (urgent == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFFFF2DF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFFD79A))),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFFFDDAA), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF9A5B00))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$urgent नए / कार्रवाई वाले ऑर्डर', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF794900))), const Text('ऑर्डर सेक्शन में जाकर जल्दी जाँचें', style: TextStyle(fontSize: 11, color: Color(0xFF9A6A24)))])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF9A5B00)),
                ]),
              );
            },
          ),
          const SizedBox(height: 22),
          _adminSectionTitle('मुख्य प्रबंधन', 'बाज़ार की सभी सुविधाएँ  •  बिक्री ऑर्डर राशि के आधार पर'),
          const SizedBox(height: 10),
          _adminAction(context, icon: Icons.account_balance_wallet_rounded, title: 'मेरी कमाई और भुगतान', subtitle: 'विज्ञापन, कमीशन और बाकी भुगतान का हिसाब', tint: const Color(0xFFE5F5EC), iconColor: const Color(0xFF087E58), onTap: () => _open(context, const AdminRevenueScreen())),
          _adminAction(context, icon: Icons.campaign_rounded, title: 'विज्ञापन स्टूडियो', subtitle: 'पैकेज, भुगतान और विज्ञापन अनुरोध', tint: const Color(0xFFFFF2D8), iconColor: const Color(0xFFB87500), onTap: () => _open(context, const AdAdminScreen())),
          const SizedBox(height: 8),
          _adminAction(context, icon: Icons.insights_rounded, title: 'एडमिन टूल्स और रिपोर्ट', subtitle: 'ऑर्डर, दुकान और बिज़नेस कंट्रोल', tint: const Color(0xFFE4F1FF), iconColor: const Color(0xFF2867B2), onTap: () => _open(context, const AdminOperationsScreen())),
          const SizedBox(height: 8),
          _adminAction(context, icon: Icons.assessment_rounded, title: 'व्यवसाय और डिलीवरी रिपोर्ट', subtitle: 'जुड़ी दुकानें, Delivery Boy, ऑर्डर और कम स्टॉक की पूरी जानकारी', tint: const Color(0xFFEAF4FF), iconColor: const Color(0xFF2867B2), onTap: () => _open(context, const AdminMarketplaceReportScreen())),
          const SizedBox(height: 22),
          _adminSectionTitle('दुकान और स्टाफ', 'नए आवेदन की जाँच करें'),
          const SizedBox(height: 8),
          _adminPanelBlock('दुकान की मंज़ूरी', Icons.store_mall_directory_rounded, const PendingShopList()),
          _adminPanelBlock('स्टाफ की मंज़ूरी', Icons.badge_rounded, const PendingStaffList()),
          const SizedBox(height: 18),
          _adminSectionTitle('लाइव निगरानी', 'समस्या आने से पहले जानें'),
          const SizedBox(height: 8),
          _adminPanelBlock('कम स्टॉक वाले प्रोडक्ट', Icons.inventory_2_rounded, const AdminLowStockWatch()),
          _adminPanelBlock('डिलीवरी के लिए तैयार ऑर्डर', Icons.local_shipping_rounded, const ReadyOrdersAssignment()),
          const SizedBox(height: 18),
          _adminSectionTitle('पैसे और लोकेशन', 'चार्ज, पेमेंट और डिलीवरी सीमा'),
          const SizedBox(height: 8),
          _adminPanelBlock('चार्ज और कमीशन सेटिंग', Icons.currency_rupee_rounded, const FeeSettings()),
          _adminPanelBlock('पेमेंट और COD कंट्रोल', Icons.payments_rounded, const Column(children: [AdminCodControl(), SizedBox(height: 8), AdminCodOverrideManager()])),
          _adminPanelBlock('डिलीवरी क्षेत्र और PIN कोड', Icons.location_on_rounded, const AdminServiceAreaManager()),
        ],
      ),
    );
  }

  Widget _adminMetric(BuildContext context, String label, String collection, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.11), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.12))),
    child: StreamBuilder<QuerySnapshot>(stream: db.collection(collection).snapshots(), builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: const Color(0xFFB8F2DF), size: 18), const SizedBox(height: 7),
      Text('${snap.data?.docs.length ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD7E8F1), fontSize: 11, fontWeight: FontWeight.w700)),
    ])),
  );

  Widget _adminSalesMetric(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.11), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.12))),
    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('orders').snapshots(),
      builder: (context, snap) {
        double total = 0;
        for (final doc in snap.data?.docs ?? []) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          // This tile is completed order value, not Admin income.
          if (status != 'delivered') continue;
          final raw = data['customerTotal'] ?? data['grandTotal'] ?? data['totalAmount'] ?? data['total'] ?? data['amount'] ?? data['payableAmount'] ?? 0;
          if (raw is num) total += raw.toDouble();
          else total += double.tryParse(raw.toString()) ?? 0;
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.currency_rupee_rounded, color: Color(0xFFFFD68A), size: 18), const SizedBox(height: 7),
          Text('₹${total >= 100000 ? (total / 100000).toStringAsFixed(1) + ' लाख' : total >= 1000 ? (total / 1000).toStringAsFixed(1) + ' हज़ार' : total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const Text('पूरे हुए ऑर्डर का कुल मूल्य', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFD7E8F1), fontSize: 11, fontWeight: FontWeight.w700)),
        ]);
      },
    ),
  );

  Widget _adminSectionTitle(String title, String subtitle) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF14243A))), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF718096)))]))]));

  Widget _adminAction(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color tint, required Color iconColor, required VoidCallback onTap}) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16), onTap: onTap));

  Widget _adminPanelBlock(String title, IconData icon, Widget child) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(13, 12, 13, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFF5257D9), size: 20), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)))]), const SizedBox(height: 10), child])));
}

class AdminLowStockWatch extends StatelessWidget {
  const AdminLowStockWatch({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('स्टॉक की जानकारी अभी नहीं मिली'),
              subtitle: Text('बाद में दोबारा जाँचें।'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        final lowStock = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          if (data['active'] == false) return false;
          final stock = (data['stock'] as num?)?.toInt() ?? 0;
          final limit = (data['lowStockLimit'] as num?)?.toInt() ?? 5;
          return stock <= limit;
        }).toList()
          ..sort((a, b) {
            final aStock = (a.data()['stock'] as num?)?.toInt() ?? 0;
            final bStock = (b.data()['stock'] as num?)?.toInt() ?? 0;
            return aStock.compareTo(bStock);
          });

        if (lowStock.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('सभी सक्रिय प्रोडक्ट का स्टॉक ठीक है'),
            ),
          );
        }

        final shown = lowStock.take(6).toList();
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: Colors.deepOrange),
                title: Text('${lowStock.length} सामान का स्टॉक कम है'),
                subtitle: const Text('दुकानदार से स्टॉक भरवाने के लिए संपर्क करें।'),
              ),
              const Divider(height: 1),
              ...shown.map((doc) {
                final data = doc.data();
                final stock = (data['stock'] as num?)?.toInt() ?? 0;
                final shopId = (data['shopId'] ?? '').toString();
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: shopId.isEmpty ? null : db.collection('shops').doc(shopId).get(),
                  builder: (context, shopSnap) {
                    final shopName = shopSnap.data?.data()?['name'] ?? (shopId.isEmpty ? 'दुकान उपलब्ध नहीं' : shopId);
                    return ListTile(
                      dense: true,
                      title: Text((data['name'] ?? 'सामान').toString()),
                      subtitle: Text('दुकान: $shopName\nबचा हुआ स्टॉक: $stock ${AppLabels.unitLabel(data['unit'])}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.error_outline, color: Colors.deepOrange),
                    );
                  },
                );
              }),
              if (lowStock.length > shown.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('और ${lowStock.length - shown.length} सामान का स्टॉक कम है।'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AdminServiceAreaManager extends StatefulWidget {
  const AdminServiceAreaManager({super.key});
  @override
  State<AdminServiceAreaManager> createState() => _AdminServiceAreaManagerState();
}

class _AdminServiceAreaManagerState extends State<AdminServiceAreaManager> {
  final name = TextEditingController();
  final pin = TextEditingController();
  bool saving = false;
  late Future<List<Map<String, dynamic>>> areasFuture;

  @override
  void initState() { super.initState(); areasFuture = AdminService().serviceAreas(); }
  void _reloadAreas() { setState(() => areasFuture = AdminService().serviceAreas()); }

  @override
  void dispose() { name.dispose(); pin.dispose(); super.dispose(); }

  Future<void> addArea() async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('सही 6 अंकों का PIN कोड भरें।')));
      return;
    }
    setState(() => saving = true);
    try {
      await AdminService().addPinCodeArea(name: name.text.trim(), pinCode: pin.text.trim());
      name.clear(); pin.clear();
      if (mounted) { _reloadAreas(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('डिलीवरी PIN कोड जोड़ दिया गया।'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PIN कोड नहीं जुड़ सका। ${AppLabels.serverError(e)}')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('जिन PIN कोड पर डिलीवरी देनी है, उन्हें यहाँ जोड़ें। एक भी PIN जोड़ने के बाद ग्राहक की डिलीवरी PIN कोड से जाँची जाएगी।', style: TextStyle(fontSize: 12)),
    const SizedBox(height: 10),
    TextField(controller: name, decoration: const InputDecoration(labelText: 'क्षेत्र का नाम (जैसे सांचोर शहर)')),
    TextField(controller: pin, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6 अंकों का PIN कोड')),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: saving ? null : addArea, child: Text(saving ? 'जोड़ रहे हैं…' : '+ PIN कोड जोड़ें'))),
    const Divider(),
    FutureBuilder<List<Map<String, dynamic>>>(future: areasFuture, builder: (context, snap) {
      if (snap.hasError) return Text('डिलीवरी क्षेत्र लोड नहीं हुए: ${snap.error}');
      if (!snap.hasData) return const LinearProgressIndicator();
      final areas = snap.data!;
      if (areas.isEmpty) return const Text('अभी कोई PIN कोड/क्षेत्र नहीं जोड़ा गया है।');
      return Column(children: areas.map((data) {
        final areaId = (data['areaId'] ?? '').toString();
        final active = data['active'] == true;
        final code = (data['pinCode'] ?? '').toString();
        final description = code.isNotEmpty ? 'PIN कोड: $code' : 'GPS दूरी: ${data['radiusKm'] ?? '?'} किलोमीटर';
        return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text((data['name'] ?? 'डिलीवरी क्षेत्र').toString()), subtitle: Text(description), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Switch(value: active, onChanged: (v) async { try { await AdminService().updateServiceArea(areaId, v); _reloadAreas(); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } }), IconButton(tooltip: 'हटाएँ', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async { try { await AdminService().deleteServiceArea(areaId); _reloadAreas(); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } })]));
      }).toList());
    }),
  ])));
}

class AdminCodControl extends StatelessWidget {
  const AdminCodControl({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: db.collection('settings').doc('payment').snapshots(),
    builder: (context, snapshot) {
      final enabled = snapshot.data?.data()?['codEnabled'] != false;
      return Card(child: SwitchListTile(
        value: enabled,
        title: const Text('सामान मिलने पर नकद भुगतान', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(enabled ? 'ग्राहक सामान मिलने पर नकद भुगतान कर सकता है।' : 'नकद भुगतान बंद है। ग्राहक ऑनलाइन भुगतान चुन सकता है।'),
        secondary: const Icon(Icons.payments_outlined, color: Color(0xFF087E58)),
        onChanged: snapshot.hasError ? null : (value) async {
          try {
            await AdminService().saveCodEnabled(value);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'नकद भुगतान चालू कर दिया गया है।' : 'नकद भुगतान बंद कर दिया गया है।')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('नकद भुगतान की सेटिंग सहेजी नहीं जा सकी।')));
          }
        },
      ));
    },
  );
}

class AdminCodOverrideManager extends StatefulWidget {
  const AdminCodOverrideManager({super.key});
  @override
  State<AdminCodOverrideManager> createState() => _AdminCodOverrideManagerState();
}

class _AdminCodOverrideManagerState extends State<AdminCodOverrideManager> {
  late Future<Map<String, List<Map<String, dynamic>>>> _accounts;
  final Set<String> _saving = <String>{};
  @override
  void initState() { super.initState(); _accounts = AdminService().listCodAccounts(); }
  void _reload() => setState(() => _accounts = AdminService().listCodAccounts());

  Future<void> _set(String type, Map<String, dynamic> account, bool enabled) async {
    final id = (account['id'] ?? '').toString();
    final key = '$type:$id';
    if (id.isEmpty) return;
    setState(() => _saving.add(key));
    try {
      await AdminService().setCodOverride(targetType: type, targetId: id, enabled: enabled);
      if (!mounted) return;
      setState(() { account['codEnabled'] = enabled; _saving.remove(key); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'नकद भुगतान चालू कर दिया गया है।' : 'नकद भुगतान बंद कर दिया गया है।')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('नकद भुगतान की सेटिंग नहीं बदली। ${AppLabels.serverError(e)}')));
    }
  }

  Widget _accountList(String type, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(14), child: Text(type == 'customer' ? 'अभी कोई ग्राहक खाता नहीं मिला।' : 'अभी कोई स्वीकृत दुकान नहीं मिली।'));
    return Column(children: rows.map((account) {
      final id = (account['id'] ?? '').toString();
      final key = '$type:$id';
      final enabled = account['codEnabled'] != false;
      final name = (account['name'] ?? (type == 'customer' ? 'ग्राहक' : 'दुकान')).toString();
      final phone = (account['phone'] ?? '').toString();
      return SwitchListTile(
        dense: true, value: enabled, onChanged: _saving.contains(key) ? null : (v) => _set(type, account, v),
        secondary: Icon(type == 'customer' ? Icons.person_outline : Icons.storefront_outlined, color: enabled ? const Color(0xFF087E58) : Colors.grey),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${phone.isEmpty ? 'मोबाइल उपलब्ध नहीं' : phone} • ${enabled ? 'COD चालू' : 'COD बंद'}'),
      );
    }).toList());
  }

  @override
  Widget build(BuildContext context) => Card(child: ExpansionTile(
    leading: const Icon(Icons.tune, color: Color(0xFF087E58)),
    title: const Text('ग्राहक और दुकानदार का COD नियंत्रण', style: TextStyle(fontWeight: FontWeight.w800)),
    subtitle: const Text('हर खाते के लिए अलग से COD चालू या बंद करें'),
    children: [
      FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _accounts,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(14), child: Column(children: [Text('सूची लोड नहीं हुई: ${snap.error}'), TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('दोबारा लोड करें'))]));
          final data = snap.data ?? {'customers': <Map<String, dynamic>>[], 'shops': <Map<String, dynamic>>[]};
          final customers = data['customers'] ?? [];
          final shops = data['shops'] ?? [];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [const Expanded(child: Text('ग्राहक', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('${customers.length} खाते')])),
            _accountList('customer', customers),
            const Divider(),
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [const Expanded(child: Text('दुकानदार / दुकानें', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('${shops.length} दुकानें')])),
            _accountList('shop', shops),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('सूची रीफ्रेश करें'))),
          ]);
        },
      ),
    ],
  ));
}

class FeeSettings extends StatefulWidget {
  const FeeSettings({super.key});

  @override
  State<FeeSettings> createState() => _FeeSettingsState();
}

class _FeeSettingsState extends State<FeeSettings> {
  final commission = TextEditingController();
  final deliveryPayout = TextEditingController();
  final customerCharge = TextEditingController();
  final platformFee = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final doc = await db.collection('settings').doc('fees').get();
      final data = doc.data() ?? {};

      commission.text = '${data['commissionPercent'] ?? 5}';
      deliveryPayout.text = '${data['deliveryPayout'] ?? 30}';
      customerCharge.text = '${data['customerDeliveryCharge'] ?? 0}';
      platformFee.text = '${data['platformFee'] ?? 0}';
    } catch (_) {
      commission.text = '5';
      deliveryPayout.text = '30';
      customerCharge.text = '0';
      platformFee.text = '0';
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveSettings() async {
    final values = [
      commission.text,
      deliveryPayout.text,
      customerCharge.text,
      platformFee.text,
    ];

    final numbers = values.map(double.tryParse).toList();

    if (numbers.any((v) => v == null || v < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सही राशि भरें।')),
      );
      return;
    }

    if (numbers[0]! > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कमीशन 100 प्रतिशत से अधिक नहीं हो सकता।')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FeeSettingsService().save(
        commissionPercent: numbers[0]!,
        deliveryPayout: numbers[1]!,
        customerDeliveryCharge: numbers[2]!,
        platformFee: numbers[3]!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सेटिंग सहेज दी गई है।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('सेटिंग सहेजी नहीं जा सकी। ${AppLabels.serverError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget feeField(String title, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        feeField('कमीशन (%)', commission),
        feeField('डिलीवरी पार्टनर का भुगतान (₹)', deliveryPayout),
        feeField('ग्राहक से डिलीवरी शुल्क (₹)', customerCharge),
        feeField('प्लेटफ़ॉर्म शुल्क (₹)', platformFee),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : saveSettings,
            child: Text(saving ? 'सहेजा जा रहा है…' : 'सेटिंग सहेजें'),
          ),
        ),
      ],
    );
  }
}

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() =>
      _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState
    extends State<CustomerRegistrationScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool busy = false;
  String? nameError;
  String? phoneError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  Future<void> submit() async {
    setState(() {
      nameError = name.text.trim().length < 2 ? 'कम से कम 2 अक्षर का नाम डालें।' : null;
      phoneError = !RegExp(r'^\d{10}$').hasMatch(phone.text.trim()) ? 'सही 10 अंकों का मोबाइल नंबर डालें।' : null;
      emailError = !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()) ? 'सही ईमेल एड्रेस डालें।' : null;
      passwordError = password.text.length < 6 ? 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए।' : null;
      confirmPasswordError = password.text != confirmPassword.text ? 'दोनों पासवर्ड मेल नहीं खाते।' : null;
    });
    if ([nameError, phoneError, emailError, passwordError, confirmPasswordError].any((e) => e != null)) return;

    setState(() => busy = true);

    try {
      await AuthService().registerCustomer(
        name: name.text,
        phone: phone.text,
        email: email.text,
        password: password.text,
      );
      TextInput.finishAutofillContext(shouldSave: true);
      await auth.signOut();

      if (!mounted) return;
      _msg('आपका अकाउंट बन गया है। अब लॉगिन करें।');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        setState(() => emailError = 'इस ईमेल से अकाउंट पहले से बना हुआ है।');
      } else if (e.code == 'invalid-email') {
        setState(() => emailError = 'सही ईमेल एड्रेस डालें।');
      } else if (e.code == 'weak-password') {
        setState(() => passwordError = 'पासवर्ड कमज़ोर है। कम से कम 6 अक्षर डालें।');
      } else if (e.code == 'network-request-failed') {
        _msg('इंटरनेट कनेक्शन जाँचें।');
      } else {
        _msg(e.message ?? 'रजिस्ट्रेशन पूरा नहीं हुआ।');
      }
    } catch (e) {
      if (mounted) {
        _msg('पंजीकरण में समस्या: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _msg(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ग्राहक पंजीकरण')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, size: 32, color: Color(0xFF087E58)),
          ),
          const SizedBox(height: 14),
          const Text('अपना ग्राहक खाता बनाएँ', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('सांचौर बाज़ार से जुड़ें और अपने आसपास की दुकानों से खरीदारी करें।',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 22),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AutofillGroup(child: Column(children: [
          TextField(
              controller: name,
              onChanged: (_) { if (nameError != null) setState(() => nameError = null); },
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: 'पूरा नाम', errorText: nameError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: phone,
              onChanged: (_) { if (phoneError != null) setState(() => phoneError = null); },
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: 'मोबाइल नंबर', errorText: phoneError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: email,
              onChanged: (_) { if (emailError != null) setState(() => emailError = null); },
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: InputDecoration(
                  labelText: 'ईमेल पता', errorText: emailError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: password,
              onChanged: (_) { if (passwordError != null) setState(() => passwordError = null); },
              obscureText: hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: 'पासवर्ड (कम से कम 6 अक्षर)',
                  errorText: passwordError,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword)))),
          const SizedBox(height: 12),
          TextField(
              controller: confirmPassword,
              onChanged: (_) { if (confirmPasswordError != null) setState(() => confirmPasswordError = null); },
              obscureText: hideConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: 'पासवर्ड दोबारा भरें',
                  errorText: confirmPasswordError,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: Icon(hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => hideConfirmPassword = !hideConfirmPassword)))),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'खाता बनाया जा रहा है…' : 'खाता बनाएँ'))),
          ])))),
        ]),
      );
}

class ShopProductsScreen extends StatefulWidget {
  final String shopId, shopName;

  const ShopProductsScreen(
      {super.key, required this.shopId, required this.shopName});

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  final db = FirebaseFirestore.instance;
  final cart = CartService();

  Future<void> add(Map<String, dynamic> p, String id) async {
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final unit = (p['unit'] ?? 'नग').toString();
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    if (stock < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('यह सामान अभी स्टॉक में उपलब्ध नहीं है।')),
      );
      return;
    }

    var quantity = 1;
    final selectedQuantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: p['imageVerified'] == true && (p['imageUrl'] ?? '').toString().startsWith('https://')
                            ? Image.network(
                                p['imageUrl'].toString(),
                                cacheWidth: 136,
                                cacheHeight: 136,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(child: ProductVisual(value: p['productEmoji']?.toString(), name: p['name']?.toString(), size: 38)),
                              )
                            : ColoredBox(color: const Color(0xFFE8F4EE), child: Center(child: ProductVisual(value: p['productEmoji']?.toString(), name: p['name']?.toString(), size: 40))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (p['name'] ?? 'सामान').toString(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text('₹${price.toStringAsFixed(2)} / $unit'),
                          Text('उपलब्ध: $stock ${AppLabels.unitLabel(unit)}',
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कितनी मात्रा चाहिए?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: quantity > 1
                              ? () => setSheetState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text('$quantity',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        IconButton.filledTonal(
                          onPressed: quantity < stock
                              ? () => setSheetState(() => quantity++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('सामान का कुल मूल्य',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '₹${(price * quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF087E58),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, quantity),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087E58), foregroundColor: Colors.white),
                    child: const Text('कार्ट में जोड़ें'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selectedQuantity == null || !mounted) return;
    try {
      await cart.addItem(
        productId: id,
        shopId: widget.shopId,
        name: (p['name'] ?? 'सामान').toString(),
        price: price,
        quantity: selectedQuantity,
        unit: unit,
        imageUrl: p['imageUrl']?.toString(), productEmoji: p['productEmoji']?.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$selectedQuantity $unit कार्ट में जुड़ गया'),
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
      }
    }
  }

  String stockCountLabel(Map<String, dynamic> p, String unit) {
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    return '₹${p['price']} / ${AppLabels.unitLabel(unit)}  •  ${stock > 0 && p['active'] == true ? 'केवल $stock उपलब्ध' : 'स्टॉक समाप्त'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.shopName), actions: [
        IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartCheckoutScreen())))
      ]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Customer query must explicitly constrain active products because
          // Firestore rules only permit public reads when active == true.
          stream: db
              .collection('products')
              .where('shopId', isEqualTo: widget.shopId)
              .where('active', isEqualTo: true)
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('सामान की सूची लोड नहीं हो सकी।\nकृपया दोबारा प्रयास करें।', textAlign: TextAlign.center)));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return const Center(
                  child: Text('इस दुकान पर अभी कोई सामान उपलब्ध नहीं है।'));
            }

            return ListView(
                children: s.data!.docs.map((d) {
              final p = d.data();
              final unit = (p['unit'] ?? 'नग').toString();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: p['imageVerified'] == true &&
                                (p['imageUrl'] ?? '').toString().startsWith('https://')
                            ? Image.network(
                                p['imageUrl'].toString(),
                                cacheWidth: 136,
                                cacheHeight: 136,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: ProductVisual(
                                    value: p['productEmoji']?.toString(),
                                    name: p['name']?.toString(),
                                    size: 34,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: const Color(0xFFE8F4EE),
                                child: Center(
                                  child: ProductVisual(
                                    value: p['productEmoji']?.toString(),
                                    name: p['name']?.toString(),
                                    size: 38,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    title: Text(p['name'] ?? 'सामान', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(stockCountLabel(p, unit)),
                    trailing: FilledButton.icon(onPressed: ((p['stock'] as num?)?.toInt() ?? 0) > 0 && p['active'] == true ? () => add(p, d.id) : null, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087E58), foregroundColor: Colors.white), icon: const Icon(Icons.add_shopping_cart), label: Text(((p['stock'] as num?)?.toInt() ?? 0) > 0 && p['active'] == true ? 'जोड़ें' : 'स्टॉक समाप्त')),
                  ),
                ),
              );
            }).toList());
          }));
}

class CartCheckoutScreen extends StatefulWidget {
  const CartCheckoutScreen({super.key});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  final cart = CartService(), orders = OrderService();
  final customerName = TextEditingController();
  final customerPhone = TextEditingController();
  final house = TextEditingController();
  final street = TextEditingController();
  final area = TextEditingController();
  final landmark = TextEditingController();
  final city = TextEditingController();
  final district = TextEditingController();
  final stateName = TextEditingController(text: 'Rajasthan');
  final pinCode = TextEditingController();
  Position? checkoutPosition;
  bool busy = false;
  String paymentMethod = 'cod';
  final couponController = TextEditingController();
  String appliedCoupon = '';
  double couponDiscount = 0;
  bool couponBusy = false;
  bool useWalletPoints = false;
  int walletBalancePoints = 0;
  int checkoutStep = 0;
  String selectedAddressId = '';
  bool checkingAddress = false;
  final Map<String, bool> addressDeliveryStatus = {}; 

  @override
  void initState() {
    super.initState();
    _loadCustomerProfile();
  }

  Future<void> _loadCustomerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      customerName.text = (data['name'] ?? user.displayName ?? '').toString();
      customerPhone.text = (data['phone'] ?? '').toString();
      final savedAddress = data['defaultAddress'];
      if (savedAddress is Map) {
        house.text = (savedAddress['house'] ?? '').toString();
        street.text = (savedAddress['street'] ?? '').toString();
        area.text = (savedAddress['area'] ?? '').toString();
        landmark.text = (savedAddress['landmark'] ?? '').toString();
        city.text = (savedAddress['city'] ?? '').toString();
        district.text = (savedAddress['district'] ?? '').toString();
        stateName.text = (savedAddress['state'] ?? 'Rajasthan').toString();
        pinCode.text = (savedAddress['pinCode'] ?? '').toString();
        final lat = savedAddress['latitude'], lon = savedAddress['longitude'];
        if (lat is num && lon is num) checkoutPosition = Position(longitude: lon.toDouble(), latitude: lat.toDouble(), timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> applyCoupon(double amount) async {
    if (couponController.text.trim().isEmpty) return;
    setState(() => couponBusy = true);
    try {
      final result = await CouponService().validateCoupon(code: couponController.text, orderAmount: amount);
      if (!mounted) return;
      if (result == null) {
        throw Exception('कूपन की जाँच नहीं हो सकी। कृपया दोबारा प्रयास करें।');
      }
      final discountValue = result['discount'];
      if (discountValue is! num) {
        throw Exception('कूपन की छूट की जानकारी सही नहीं है।');
      }
      setState(() {
        appliedCoupon = (result['code'] ?? '').toString();
        couponDiscount = discountValue.toDouble();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('कूपन लागू हो गया। ₹${couponDiscount.toStringAsFixed(2)} की छूट मिली।')));
    } catch (e) {
      if (mounted) { setState(() { appliedCoupon = ''; couponDiscount = 0; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); }
    } finally { if (mounted) setState(() => couponBusy = false); }
  }

  String get fullAddress => [house.text, street.text, area.text, landmark.text, city.text, district.text, stateName.text, pinCode.text].where((x) => x.trim().isNotEmpty).join(', ');

  Future<void> useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('फ़ोन का GPS चालू करें।');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) throw Exception('ऐप को लोकेशन की अनुमति दें।');
      final position = await Geolocator.getCurrentPosition();
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {'format':'jsonv2','lat':'${position.latitude}','lon':'${position.longitude}','addressdetails':'1'});
      final response = await http.get(uri, headers: {'User-Agent':'SanchoreBazaar/1.0 (delivery address lookup)'}).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final a = (data['address'] as Map?)?.cast<String,dynamic>() ?? {};
        house.text = (a['house_number'] ?? '').toString();
        street.text = (a['road'] ?? a['pedestrian'] ?? '').toString();
        area.text = (a['suburb'] ?? a['neighbourhood'] ?? a['village'] ?? '').toString();
        landmark.text = '';
        city.text = (a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '').toString();
        district.text = (a['state_district'] ?? a['county'] ?? '').toString();
        stateName.text = (a['state'] ?? 'Rajasthan').toString();
        pinCode.text = (a['postcode'] ?? '').toString();
      }
      if (!mounted) return;
      setState(() => checkoutPosition = position);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pinCode.text.isEmpty ? 'लोकेशन मिल गई। अब PIN कोड और बाकी पता भरें।' : 'लोकेशन से पता भर दिया गया है। कृपया एक बार जाँच लें।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('लोकेशन से पता नहीं मिल सका। कृपया पता स्वयं भरें।')));
    }
  }

  Future<void> _changeCartQuantity(String productId, int quantity) async {
    try {
      await cart.updateQuantity(productId: productId, quantity: quantity);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> checkout(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final pin = pinCode.text.trim();
    if (customerName.text.trim().length < 2 || customerPhone.text.replaceAll(RegExp(r'\D'), '').length < 10 || fullAddress.trim().length < 15 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('पूरा पता, 6 अंकों का PIN, नाम और 10 अंकों का मोबाइल नंबर भरें।')));
      return;
    }
    final lat = checkoutPosition?.latitude;
    final lon = checkoutPosition?.longitude;

    final groups = <String, List<Map<String, dynamic>>>{};

    for (final d in docs) {
      final x = d.data();
      final shop = (x['shopId'] ?? '').toString();
      groups.putIfAbsent(shop, () => []).add(
          {'productId': x['productId'] ?? d.id, 'quantity': x['quantity']});
    }

    setState(() => busy = true);

    try {
      // Friendly pre-check; Worker repeats this atomically at order time.
      for (final item in docs) {
        final productId = (item.data()['productId'] ?? item.id).toString();
        final live = await db.collection('products').doc(productId).get();
        final data = live.data() ?? <String, dynamic>{};
        final stock = (data['stock'] as num?)?.toInt() ?? 0;
        final wanted = (item.data()['quantity'] as num?)?.toInt() ?? 0;
        if (!live.exists || data['active'] != true || stock < wanted) {
          throw Exception('${data['name'] ?? item.data()['name'] ?? 'एक सामान'} में केवल $stock उपलब्ध हैं। कार्ट में मात्रा बदलें या सामान हटाएँ।');
        }
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
          'name': customerName.text.trim(), 'phone': customerPhone.text.trim(),
          'defaultAddress': {'house': house.text.trim(), 'street': street.text.trim(), 'area': area.text.trim(), 'landmark': landmark.text.trim(), 'city': city.text.trim(), 'district': district.text.trim(), 'state': stateName.text.trim(), 'pinCode': pin, 'latitude': lat, 'longitude': lon, 'fullAddress': fullAddress},
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final created = await orders.createMultiShopOrder(
          groups: groups.entries
              .map((e) => {'shopId': e.key, 'items': e.value})
              .toList(),
          address: fullAddress,
          customerName: customerName.text.trim(),
          customerPhone: customerPhone.text.trim(),
          latitude: lat,
          longitude: lon,
          pinCode: pin,
          paymentMethod: paymentMethod,
          couponCode: appliedCoupon,
          useWalletPoints: useWalletPoints);

      final paymentSessionId = (created['paymentSessionId'] ?? '').toString();
      if (paymentMethod == 'paytm' && paymentSessionId.isNotEmpty) {
        final payment = await PaymentService().initiatePaytm(paymentSessionId);
        if (!mounted) return;
        final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaytmCheckoutScreen(
          checkoutUrl: payment['checkoutUrl'].toString(), sessionId: paymentSessionId,
        )));
        if (paid != true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('भुगतान की पुष्टि बाकी है। इसलिए सामान की सूची अभी खाली नहीं की गई है।')));
          return;
        }
      }

      await cart.clearCart();
      if (mounted) {
        final orderIds = (created['orderIds'] is List)
            ? (created['orderIds'] as List).map((e) => e.toString()).toList()
            : <String>[(created['orderId'] ?? '').toString()].where((e) => e.isNotEmpty).toList();
        await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(
          orderIds: orderIds,
          paymentSuccessful: ((created['paymentMethod'] ?? paymentMethod).toString() == 'wallet') || (paymentMethod == 'paytm' && paymentSessionId.isNotEmpty),
          paymentMethod: (created['paymentMethod'] ?? paymentMethod).toString(),
        )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ऑर्डर पूरा नहीं हो सका। ${AppLabels.serverError(e)}')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    customerName.dispose(); customerPhone.dispose(); house.dispose(); street.dispose(); area.dispose(); landmark.dispose(); city.dispose(); district.dispose(); stateName.dispose(); pinCode.dispose(); couponController.dispose();
    super.dispose();
  }

  void _selectSavedAddress(String id, Map<String, dynamic> a) {
    customerName.text = (a['customerName'] ?? a['name'] ?? customerName.text).toString();
    customerPhone.text = (a['phone'] ?? customerPhone.text).toString();
    house.text = (a['house'] ?? '').toString();
    street.text = (a['street'] ?? '').toString();
    area.text = (a['area'] ?? '').toString();
    landmark.text = (a['landmark'] ?? '').toString();
    city.text = (a['city'] ?? '').toString();
    district.text = (a['district'] ?? '').toString();
    stateName.text = (a['state'] ?? 'Rajasthan').toString();
    pinCode.text = (a['pinCode'] ?? '').toString();
    final loc = a['location'];
    final lat = a['latitude'] ?? (loc is GeoPoint ? loc.latitude : null);
    final lon = a['longitude'] ?? (loc is GeoPoint ? loc.longitude : null);
    if (lat is num && lon is num) {
      checkoutPosition = Position(longitude: lon.toDouble(), latitude: lat.toDouble(), timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
      selectedAddressId = id;
    } else {
      checkoutPosition = null;
      selectedAddressId = id;
    }
    setState(() {});
  }

  Future<void> _addAddress() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAccountScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _checkAndSelectAddress(String id, Map<String, dynamic> address, {double? latitude, double? longitude}) async {
    setState(() => checkingAddress = true);
    try {
      final available = await ServiceAreaService().isLocationServiceable(pinCode: (address['pinCode'] ?? '').toString(), latitude: latitude, longitude: longitude);
      if (!mounted) return;
      setState(() => addressDeliveryStatus[id] = available);
      if (available) {
        _selectSavedAddress(id, address);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('इस पते पर अभी सांचौर बाज़ार की डिलीवरी उपलब्ध नहीं है।')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('डिलीवरी क्षेत्र की जाँच नहीं हो सकी। ${AppLabels.serverError(e)}')));
    } finally {
      if (mounted) setState(() => checkingAddress = false);
    }
  }

  Future<bool> _customerAndShopCodAllowed(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final user = auth.currentUser;
    if (user == null) return false;
    final profile = await db.collection('users').doc(user.uid).get();
    final customer = profile.data() ?? <String, dynamic>{};
    if (customer['codEnabled'] == false || customer['codDisabled'] == true) return false;
    final shopIds = docs.map((d) => (d.data()['shopId'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
    for (final shopId in shopIds) {
      final shop = await db.collection('shops').doc(shopId).get();
      final data = shop.data() ?? <String, dynamic>{};
      if (!shop.exists || data['codEnabled'] == false || data['codDisabled'] == true) return false;
    }
    return true;
  }

  Future<void> _continueStep(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (checkoutStep == 0) {
      setState(() => checkoutStep = 1);
      return;
    }
    if (checkoutStep == 1) {
      setState(() => checkoutStep = 2);
      return;
    }
    if (checkoutStep == 2) {
      if (fullAddress.trim().length < 10 || !RegExp(r'^\d{6}$').hasMatch(pinCode.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('डिलीवरी के लिए सेव किया हुआ पता चुनें या GPS से पूरा पता भरें।')));
        return;
      }
      setState(() => checkingAddress = true);
      try {
        final available = await ServiceAreaService().isLocationServiceable(pinCode: pinCode.text.trim(), latitude: checkoutPosition?.latitude, longitude: checkoutPosition?.longitude);
        if (!mounted) return;
        if (!available) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('इस पते पर अभी डिलीवरी उपलब्ध नहीं है। दूसरा पता चुनें।')));
          return;
        }
        setState(() => checkoutStep = 3);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('डिलीवरी क्षेत्र की जाँच नहीं हो सकी। ${AppLabels.serverError(e)}')));
      } finally {
        if (mounted) setState(() => checkingAddress = false);
      }
      return;
    }
    checkout(docs);
  }

  Widget _stepHeader() {
    const labels = ['कार्ट', 'कूपन', 'पता', 'भुगतान'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: List.generate(4, (i) {
        final active = i <= checkoutStep;
        return Expanded(child: Row(children: [
          CircleAvatar(radius: 14, backgroundColor: active ? const Color(0xFF087E58) : const Color(0xFFE6EAE8), child: Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 5),
          Flexible(child: Text(labels[i], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? const Color(0xFF087E58) : Colors.black54))),
          if (i != 3) Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 5), color: i < checkoutStep ? const Color(0xFF087E58) : const Color(0xFFE6EAE8))),
        ]));
      })),
    );
  }

  Widget _couponCard(String code, Map<String, dynamic> data, double total) {
    final type = (data['discountType'] ?? '').toString();
    final value = (data['discountValue'] as num?)?.toDouble() ?? 0;
    final minimum = (data['minimumOrder'] as num?)?.toDouble() ?? 0;
    final title = type == 'percentage' ? '${value.toStringAsFixed(0)}% की छूट' : '₹${value.toStringAsFixed(0)} की छूट';
    final eligible = total >= minimum;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(13), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFEAF6EF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_offer_outlined, color: Color(0xFF087E58))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(code, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF087E58))), Text(minimum > 0 && total < minimum ? '₹${(minimum - total).toStringAsFixed(0)} और जोड़ें, फिर यह ऑफर मिलेगा' : minimum > 0 ? 'कम से कम ₹${minimum.toStringAsFixed(0)} की खरीद पर' : 'सभी योग्य ऑर्डर पर', style: const TextStyle(fontSize: 12, color: Colors.black54))])),
      TextButton(onPressed: !eligible || couponBusy ? null : () { couponController.text = code; applyCoupon(total); }, child: Text(appliedCoupon == code ? 'लागू है' : 'लागू करें')),
    ])));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(checkoutStep == 0 ? 'आपका कार्ट' : checkoutStep == 1 ? 'कूपन और ऑफर' : checkoutStep == 2 ? 'डिलीवरी का पता' : 'भुगतान का तरीका'),
      leading: checkoutStep > 0 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => checkoutStep--)) : null,
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: cart.getCart(),
      builder: (context, s) {
        if (s.hasError) return const Center(child: Text('कार्ट लोड नहीं हुआ'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('आपका कार्ट खाली है'));
        final total = docs.fold<double>(0, (sum, d) {
          final item = d.data();
          return sum + ((item['price'] as num?)?.toDouble() ?? 0) * ((item['quantity'] as num?)?.toInt() ?? 0);
        });
        final payablePreview = (total - couponDiscount).clamp(0, total).toDouble();
        final maxWalletDiscount = (payablePreview < total * 0.25 ? payablePreview : total * 0.25);
        final maxWalletPoints = (maxWalletDiscount * 100).floor();
        final previewRedeemPoints = walletBalancePoints < maxWalletPoints ? walletBalancePoints : maxWalletPoints;
        final walletPreviewDiscount = useWalletPoints ? previewRedeemPoints / 100 : 0.0;
        final displayPayablePreview = (payablePreview - walletPreviewDiscount).clamp(0.0, payablePreview).toDouble();
        return Column(children: [
          _stepHeader(),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), children: [
            if (checkoutStep == 0) ...[
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('आपके चुने हुए सामान', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...docs.map((d) {
                  final x = d.data();
                  final quantity = (x['quantity'] as num?)?.toInt() ?? 1;
                  final price = (x['price'] as num?)?.toDouble() ?? 0;
                  final imageUrl = (x['imageUrl'] ?? '').toString();
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: x['imageVerified'] == true && imageUrl.startsWith('https://')
                            ? Image.network(
                                imageUrl,
                                cacheWidth: 124,
                                cacheHeight: 124,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: ProductVisual(
                                    value: x['productEmoji']?.toString(),
                                    name: x['name']?.toString(),
                                    size: 32,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: const Color(0xFFEAF6EF),
                                child: Center(
                                  child: ProductVisual(
                                    value: x['productEmoji']?.toString(),
                                    name: x['name']?.toString(),
                                    size: 36,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((x['name'] ?? 'सामान').toString(), style: const TextStyle(fontWeight: FontWeight.w800)), Text('₹${price.toStringAsFixed(2)} × $quantity', style: const TextStyle(color: Colors.black54, fontSize: 12)), Text('₹${(price * quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))])),
                    IconButton(onPressed: () => _changeCartQuantity(d.id, quantity - 1), icon: const Icon(Icons.remove_circle_outline)),
                    Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(onPressed: () => _changeCartQuantity(d.id, quantity + 1), icon: const Icon(Icons.add_circle_outline, color: Color(0xFF087E58))),
                    IconButton(onPressed: () => cart.removeItem(d.id), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                  ]));
                }),
                const Divider(),
                InkWell(onTap: () => Navigator.pop(context), child: const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Row(children: [Icon(Icons.add_circle_outline, color: Color(0xFF087E58)), SizedBox(width: 8), Text('और सामान जोड़ें', style: TextStyle(color: Color(0xFF087E58), fontWeight: FontWeight.w900))]))),
              ]))),
              Card(child: ListTile(leading: const Icon(Icons.lock_outline, color: Color(0xFF087E58)), title: const Text('सुरक्षित ऑर्डर'), subtitle: const Text('आगे बढ़ने पर ऑफर, पता और भुगतान चुनें।'))),
            ],
            if (checkoutStep == 1) ...[
              Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFEAF6EF), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('हर ऑर्डर पर बचत करें', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 4), Text('आपके सामान का कुल ₹${total.toStringAsFixed(2)} है। उपलब्ध कूपन लगाएँ।') ])),
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: couponController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(isDense: true, hintText: 'कूपन कोड डालें'))), const SizedBox(width: 8), FilledButton(onPressed: couponBusy ? null : () => applyCoupon(total), child: Text(couponBusy ? 'जाँच...' : 'लागू करें'))]))),
              if (appliedCoupon.isNotEmpty) Card(color: const Color(0xFFEAF6EF), child: ListTile(leading: const Icon(Icons.verified, color: Color(0xFF087E58)), title: Text('$appliedCoupon लागू हो गया'), subtitle: Text('आपकी बचत ₹${couponDiscount.toStringAsFixed(2)}'), trailing: IconButton(onPressed: () => setState(() { appliedCoupon = ''; couponDiscount = 0; couponController.clear(); }), icon: const Icon(Icons.close)))),
              const SizedBox(height: 8),
              const Text('आपके लिए उपलब्ध ऑफर', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('coupons').where('active', isEqualTo: true).snapshots(), builder: (context, coupons) {
                if (coupons.hasError) return const Padding(padding: EdgeInsets.all(12), child: Text('ऑफर अभी लोड नहीं हो पाए।'));
                if (!coupons.hasData) return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
                final eligibleCoupons = coupons.data!.docs.where((d) {
                  final end = d.data()['endAt'];
                  final start = d.data()['startAt'];
                  final now = DateTime.now();
                  final endDate = end is Timestamp ? end.toDate() : end is String ? DateTime.tryParse(end) : null;
                  final startDate = start is Timestamp ? start.toDate() : start is String ? DateTime.tryParse(start) : null;
                  return (endDate == null || !now.isAfter(endDate)) && (startDate == null || !now.isBefore(startDate));
                }).toList();
                if (eligibleCoupons.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई सक्रिय कूपन उपलब्ध नहीं है।')));
                return Column(children: eligibleCoupons.map((d) => _couponCard(d.id, d.data(), total)).toList());
              }),
            ],
            if (checkoutStep == 2) ...[
              Card(color: const Color(0xFFEAF6EF), child: const Padding(padding: EdgeInsets.all(13), child: Row(children: [Icon(Icons.location_on, color: Color(0xFF087E58)), SizedBox(width: 9), Expanded(child: Text('वह पता चुनें जहाँ सांचौर बाज़ार डिलीवरी कर सके।', style: TextStyle(fontWeight: FontWeight.w700)))]))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('सेव किए हुए पते', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add), label: const Text('नया पता'))]),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('users').doc(auth.currentUser!.uid).collection('addresses').orderBy('createdAt', descending: true).snapshots(), builder: (context, saved) {
                if (saved.hasError) return const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('सेव किए पते लोड नहीं हो पाए।')));
                if (!saved.hasData) return const Center(child: CircularProgressIndicator());
                if (saved.data!.docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('अभी कोई पता सेव नहीं है। नया पता जोड़ें।')));
                return Column(children: saved.data!.docs.map((doc) {
                  final a = doc.data();
                  final loc = a['location'];
                  final lat = a['latitude'] ?? (loc is GeoPoint ? loc.latitude : null);
                  final lon = a['longitude'] ?? (loc is GeoPoint ? loc.longitude : null);
                  final hasCoords = lat is num && lon is num;
                  final hasPin = RegExp(r'^\d{6}$').hasMatch((a['pinCode'] ?? '').toString());
                  final selected = selectedAddressId == doc.id;
                  final status = addressDeliveryStatus[doc.id];
                  final label = !hasPin ? '6 अंकों का PIN कोड जोड़ें' : status == null ? 'टैप करके डिलीवरी क्षेत्र जाँचें' : status ? 'डिलीवरी उपलब्ध' : 'इस पते पर डिलीवरी उपलब्ध नहीं';
                  final statusColor = status == true ? const Color(0xFF087E58) : status == false ? Colors.redAccent : Colors.black54;
                  return Card(child: InkWell(onTap: hasPin && !checkingAddress ? () => _checkAndSelectAddress(doc.id, a, latitude: hasCoords ? (lat as num).toDouble() : null, longitude: hasCoords ? (lon as num).toDouble() : null) : null, child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF087E58) : Colors.black45), const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((a['label'] ?? 'घर').toString(), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text((a['address'] ?? '').toString(), style: const TextStyle(fontSize: 13)), Text('फोन: ${(a['phone'] ?? customerPhone.text).toString()}', style: const TextStyle(fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), Text(checkingAddress ? 'डिलीवरी क्षेत्र जाँचा जा रहा है…' : label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor))])),
                    if (selected) const Icon(Icons.check_circle, color: Color(0xFF087E58)),
                  ]))));
                }).toList());
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: busy ? null : useCurrentLocation, icon: const Icon(Icons.my_location), label: const Text('वर्तमान लोकेशन से पता चुनें')),
              if (fullAddress.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(customerName.text), subtitle: Text('$fullAddress\n${customerPhone.text}'))),
            ],
            if (checkoutStep == 3) ...[
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('डिलीवरी यहाँ होगी', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(fullAddress), Text('${customerName.text} • ${customerPhone.text}', style: const TextStyle(color: Colors.black54))]))),
              const SizedBox(height: 10),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: db.collection('users').doc(auth.currentUser!.uid).snapshots(),
                builder: (context, walletSnapshot) {
                  final points = (walletSnapshot.data?.data()?['pointsBalance'] as num?)?.toInt() ?? 0;
                  if (walletBalancePoints != points) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && walletBalancePoints != points) setState(() => walletBalancePoints = points);
                    });
                  }
                  final maxWalletDiscount = payablePreview < total * 0.25 ? payablePreview : total * 0.25;
                  final possiblePoints = (maxWalletDiscount * 100).floor();
                  final redeemPoints = points < possiblePoints ? points : possiblePoints;
                  final saving = redeemPoints / 100;
                  return Card(color: const Color(0xFFF0F8F5), child: CheckboxListTile(
                    value: useWalletPoints && redeemPoints > 0,
                    onChanged: redeemPoints <= 0 ? null : (value) => setState(() => useWalletPoints = value == true),
                    secondary: const Icon(Icons.account_balance_wallet, color: Color(0xFF087E58)),
                    title: Text('वॉलेट पॉइंट इस्तेमाल करें ($points उपलब्ध)', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(redeemPoints > 0
                        ? '$redeemPoints पॉइंट से ₹${saving.toStringAsFixed(2)} तक की छूट मिलेगी। प्रति ऑर्डर सामान के मूल्य की अधिकतम 25% छूट मिलेगी।'
                        : 'अभी इस्तेमाल करने के लिए पॉइंट नहीं हैं।'),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ));
                },
              ),
              const SizedBox(height: 8),
              const Text('भुगतान का तरीका चुनें', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: db.collection('settings').doc('payment').snapshots(), builder: (context, paymentSnapshot) {
                final globalCodEnabled = paymentSnapshot.data?.data()?['codEnabled'] != false;
                return FutureBuilder<bool>(future: _customerAndShopCodAllowed(docs), builder: (context, eligibility) {
                  final codEnabled = globalCodEnabled && eligibility.data == true;
                  if (!codEnabled && paymentMethod == 'cod') paymentMethod = 'paytm';
                  return Column(children: [
                    if (eligibility.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
                    if (codEnabled) Card(child: RadioListTile<String>(value: 'cod', groupValue: paymentMethod, onChanged: (v) => setState(() => paymentMethod = v!), title: const Text('सामान मिलने पर नकद भुगतान'), subtitle: const Text('सामान मिलने पर नकद भुगतान'), secondary: const Icon(Icons.payments_outlined, color: Color(0xFF087E58)))),
                    if (!codEnabled && eligibility.connectionState != ConnectionState.waiting) const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('इस ऑर्डर पर COD उपलब्ध नहीं है'), subtitle: Text('एडमिन की सेटिंग के अनुसार ऑनलाइन भुगतान चुनें।'))),
                    Card(child: RadioListTile<String>(value: 'paytm', groupValue: paymentMethod, onChanged: (v) => setState(() => paymentMethod = v!), title: const Text('UPI या ऑनलाइन भुगतान'), subtitle: const Text('PhonePe, Google Pay, Paytm UPI और अन्य उपलब्ध भुगतान तरीके'), secondary: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF087E58)))),
                    if (paymentMethod == 'paytm') Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('सुरक्षित पेमेंट गेटवे', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: const [Chip(avatar: Icon(Icons.qr_code, size: 17), label: Text('UPI / QR')), Chip(avatar: Icon(Icons.credit_card, size: 17), label: Text('डेबिट / क्रेडिट कार्ड')), Chip(avatar: Icon(Icons.account_balance, size: 17), label: Text('नेट बैंकिंग'))]), const Text('अगली स्क्रीन पर आपके पेमेंट गेटवे में उपलब्ध विकल्प दिखेंगे। PhonePe या अन्य UPI ऐप की उपलब्धता गेटवे कॉन्फ़िगरेशन पर निर्भर है।', style: TextStyle(fontSize: 12, color: Colors.black54))]))),
                  ]);
                });
              }),
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('सामान का कुल'), Text('₹${total.toStringAsFixed(2)}')]),
                if (couponDiscount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('कूपन की बचत'), Text('- ₹${couponDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF087E58), fontWeight: FontWeight.w800))]),
                if (walletPreviewDiscount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('वॉलेट की छूट'), Text('- ₹${walletPreviewDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF087E58), fontWeight: FontWeight.w800))]),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('डिलीवरी / प्लेटफॉर्म शुल्क'), Text('अंतिम गणना अगले चरण में')]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('अभी का अनुमानित कुल', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text('₹${displayPayablePreview.toStringAsFixed(2)}+', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF087E58)))]),
                const Text('अंतिम रकम में लागू डिलीवरी/प्लेटफॉर्म शुल्क सर्वर की गणना के अनुसार जुड़ेंगे।', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ]))),
            ],
          ])),
          SafeArea(top: false, child: Container(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -3))]), child: Row(children: [
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${docs.fold<int>(0, (a, d) => a + ((d.data()['quantity'] as num?)?.toInt() ?? 0))} आइटम', style: const TextStyle(fontSize: 12, color: Colors.black54)), Text('₹${displayPayablePreview.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
            Expanded(flex: 2, child: FilledButton(onPressed: busy || checkingAddress ? null : () => _continueStep(docs), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087E58), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(busy || checkingAddress ? 'जाँच हो रही है…' : checkoutStep == 0 ? 'आगे बढ़ें' : checkoutStep == 3 ? (paymentMethod == 'paytm' ? 'भुगतान करें और ऑर्डर दें' : 'ऑर्डर दें') : 'आगे बढ़ें', style: const TextStyle(fontWeight: FontWeight.w900)))),
          ]))),
        ]);
      },
    ),
  );
}

class ShopkeeperPanel extends StatefulWidget {
  const ShopkeeperPanel({super.key});

  @override
  State<ShopkeeperPanel> createState() => _ShopkeeperPanelState();
}

class _ShopkeeperPanelState extends State<ShopkeeperPanel> {
  final service = ShopkeeperService();

  Future<void> _requestNewShop() async {
    final name = TextEditingController();
    final category = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final owner = TextEditingController();
    final photo = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final data = await showDialog<Map<String, String>>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('नई दुकान जोड़ने की रिक्वेस्ट'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'दुकान का नाम *'), validator: (v) => (v ?? '').trim().length < 2 ? 'दुकान का नाम भरें' : null),
        TextFormField(controller: category, decoration: const InputDecoration(labelText: 'दुकान की श्रेणी *'), validator: (v) => (v ?? '').trim().length < 2 ? 'श्रेणी भरें' : null),
        TextFormField(controller: address, decoration: const InputDecoration(labelText: 'पूरा पता / क्षेत्र *'), maxLines: 2, validator: (v) => (v ?? '').trim().length < 5 ? 'पूरा पता भरें' : null),
        TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'दुकान का मोबाइल नंबर *'), validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? 'सही मोबाइल नंबर भरें' : null),
        TextFormField(controller: owner, decoration: const InputDecoration(labelText: 'मालिक का नाम *'), validator: (v) => (v ?? '').trim().length < 2 ? 'मालिक का नाम भरें' : null),
        TextFormField(controller: photo, decoration: const InputDecoration(labelText: 'दुकान की फोटो URL (वैकल्पिक)')),
        const SizedBox(height: 8), const Text('दुकान Admin की मंजूरी के बाद ही जुड़ेगी।', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')), FilledButton(onPressed: () { if (formKey.currentState?.validate() == true) Navigator.pop(ctx, {'name': name.text, 'category': category.text, 'address': address.text, 'phone': phone.text, 'ownerName': owner.text, 'photoUrl': photo.text}); }, child: const Text('रिक्वेस्ट भेजें'))],
    ));
    name.dispose(); category.dispose(); address.dispose(); phone.dispose(); owner.dispose(); photo.dispose();
    if (data == null) return;
    try {
      await service.addShop(name: data['name']!, category: data['category']!, address: data['address']!, phone: data['phone']!, ownerName: data['ownerName']!, photoUrl: data['photoUrl']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('दुकान जोड़ने की रिक्वेस्ट Admin को भेज दी गई।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('दुकानदार पैनल'), actions: [
          IconButton(
              tooltip: 'दुकान प्रबंधन',
              icon: const Icon(Icons.inventory),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ShopkeeperToolsScreen()))),
          IconButton(
              tooltip: 'आपूर्तिकर्ता और खर्च',
              icon: const Icon(Icons.account_balance),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ShopkeeperAccountsScreen()))),
          IconButton(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }
              },
              icon: const Icon(Icons.logout))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF171C36), Color(0xFF5257D9)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x24101D32), blurRadius: 16, offset: Offset(0, 7))],
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.storefront_rounded, color: Color(0xFFB8F2DF), size: 28), Spacer(), Text('दुकानदार क्षेत्र', style: TextStyle(color: Color(0xFFB8F2DF), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2))]),
              SizedBox(height: 14),
              Text('आपकी दुकान, आपकी पहचान', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('प्रोडक्ट जोड़ें, स्टॉक संभालें और ऑर्डर बढ़ाएँ।', style: TextStyle(color: Color(0xFFD7E8F1), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 18),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.workspace_premium, color: Color(0xFFB87500)),
                  title: const Text('दुकानदार Pro सदस्यता'),
                  subtitle: const Text('मासिक या वार्षिक योजना लेकर दुकान को प्राथमिकता दें'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopkeeperProScreen())))),
          const SizedBox(height: 10),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.green),
                  title: const Text('भुगतान वाले विज्ञापन'),
                  subtitle: const Text('अपनी दुकान का विज्ञापन चलाएँ'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShopkeeperAdsScreen())))),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _requestNewShop, icon: const Icon(Icons.add_business), label: const Text('नई दुकान जोड़ने की रिक्वेस्ट भेजें'))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: service.myShopRequests(), builder: (context, reqSnap) {
            if (!reqSnap.hasData || reqSnap.data!.docs.isEmpty) return const SizedBox.shrink();
            final requests = reqSnap.data!.docs.toList()..sort((a,b) => ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('आपकी दुकान रिक्वेस्ट', style: TextStyle(fontWeight: FontWeight.w900)), ...requests.map((r) { final x=r.data(); final status=(x['status'] ?? 'pending').toString(); final label=status == 'approved' ? 'मंजूर' : status == 'rejected' ? 'रिजेक्ट' : 'जाँच में'; return Card(child: ListTile(leading: Icon(status == 'approved' ? Icons.check_circle : status == 'rejected' ? Icons.cancel : Icons.hourglass_top, color: status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange), title: Text((x['name'] ?? 'दुकान').toString()), subtitle: Text('$label • ${(x['category'] ?? '').toString()}${status == 'rejected' ? '\nकारण: ${(x['rejectionReason'] ?? 'कारण उपलब्ध नहीं').toString()}' : ''}'))); })]);
          }),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.myShops(),
              builder: (context, snap) {
                if (snap.hasError) return const Text('दुकान की जानकारी लोड नहीं हो सकी।');
                if (!snap.hasData) return const LinearProgressIndicator();
                if (snap.data!.docs.isEmpty) {
                  return const Text('अभी आपके खाते से कोई दुकान जुड़ी नहीं है।');
                }

                return Column(
                    children: snap.data!.docs
                        .map((d) =>
                            ShopManagementCard(shopId: d.id, shop: d.data()))
                        .toList());
              }),
          const SizedBox(height: 18),
          const Text(
              'ऑर्डर और सामान का प्रबंधन करने के लिए दुकान का स्वीकृत होना जरूरी है।'),
        ]),
      );
}

class ShopManagementCard extends StatefulWidget {
  final String shopId;
  final Map<String, dynamic> shop;

  const ShopManagementCard(
      {super.key, required this.shopId, required this.shop});

  @override
  State<ShopManagementCard> createState() => _ShopManagementCardState();
}

class _ShopManagementCardState extends State<ShopManagementCard> {
  final service = ShopkeeperService();

  Future<void> addProduct() async {
    final details = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddProductDialog(),
    );
    if (details == null) return;
    final productId = 'p_${DateTime.now().microsecondsSinceEpoch}';
    try {
      String? imageUrl = details['imageUrl'] as String?;
      final imageFile = details['imageFile'];
      if (imageFile != null) {
        imageUrl = await ImageService().uploadProductImage(file: imageFile, productId: productId);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageUrl = await ImageService().uploadProductImageFromUrl(imageUrl: imageUrl, productId: productId);
      }
      final enteredName = (details['name'] as String).trim();
      final existing = await service.myProducts(widget.shopId).first;
      QueryDocumentSnapshot<Map<String, dynamic>>? sameProduct;
      for (final doc in existing.docs) {
        final oldName = (doc.data()['name'] ?? '').toString().trim();
        if (oldName.toLowerCase() == enteredName.toLowerCase()) { sameProduct = doc; break; }
      }
      if (sameProduct != null) {
        final oldData = sameProduct.data();
        final oldStock = (oldData['stock'] as num?)?.toInt() ?? 0;
        await service.updateProduct(
          productId: sameProduct.id, shopId: widget.shopId,
          name: enteredName, category: details['category'] as String,
          price: details['price'] as double, stock: oldStock + (details['stock'] as int),
          unit: details['unit'] as String,
          imageUrl: imageUrl ?? oldData['imageUrl']?.toString(), productEmoji: details['productEmoji'] as String?, imageVerified: details['imageVerified'] == true || (imageUrl == null && oldData['imageVerified'] == true),
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('यह सामान पहले से था। उसी का स्टॉक ${oldStock} से बढ़ाकर ${oldStock + (details['stock'] as int)} कर दिया।')));
      } else {
        await service.addProduct(
          productId: productId, shopId: widget.shopId,
          name: enteredName, category: details['category'] as String,
          price: details['price'] as double, stock: details['stock'] as int,
          unit: details['unit'] as String, imageUrl: imageUrl, productEmoji: details['productEmoji'] as String?, imageVerified: details['imageVerified'] == true,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('नया प्रोडक्ट सेव हो गया')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सामान की फोटो अपलोड नहीं हो सकी। ${AppLabels.serverError(e)}')));
    }
  }

  Future<void> editProduct(String productId, Map<String, dynamic> product) async {
    final details = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddProductDialog(initialData: product),
    );
    if (details == null) return;
    try {
      String? imageUrl = details['imageUrl'] as String?;
      final imageFile = details['imageFile'];
      if (imageFile != null) {
        imageUrl = await ImageService().uploadProductImage(file: imageFile, productId: productId);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageUrl = await ImageService().uploadProductImageFromUrl(imageUrl: imageUrl, productId: productId);
      }
      await service.updateProduct(
        productId: productId, shopId: widget.shopId,
        name: details['name'] as String, category: details['category'] as String,
        price: details['price'] as double, stock: details['stock'] as int,
        unit: details['unit'] as String, imageUrl: imageUrl, productEmoji: details['productEmoji'] as String?, imageVerified: details['imageVerified'] == true,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('सामान की जानकारी अपडेट हो गई है।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सामान अपडेट नहीं हो सका। ${AppLabels.serverError(e)}')));
    }
  }

  Future<void> deleteProduct(String productId, String productName) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('सामान हटाएँ?'),
      content: Text('क्या "$productName" को दुकान की सूची से हटाना चाहते हैं? यह ग्राहक को दिखाई नहीं देगा।'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('हटाएँ'))],
    ));
    if (confirmed != true) return;
    try {
      await service.deleteProduct(productId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('प्रोडक्ट हटा दिया गया।')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('सामान नहीं हटाया जा सका। ${AppLabels.serverError(e)}')));
    }
  }

  Widget _productThumb(String? url, [String? emoji, String? productName, bool verified = false]) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(width: 54, height: 54,
      child: verified && url != null && url.startsWith('https://')
        ? Image.network(url, cacheWidth: 108, cacheHeight: 108, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: ProductVisual(value: emoji, name: productName, size: 30)))
        : ColoredBox(color: const Color(0xFFE8F4EE), child: Center(child: ProductVisual(value: emoji, name: productName, size: 32))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final approved =
        widget.shop['approved'] == true && widget.shop['active'] == true;

    return Card(
        child: Padding(
            padding: const EdgeInsets.all(10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(children: [Expanded(child: Text(widget.shop['name'] ?? 'दुकान')), if (widget.shop['proStatus'] == 'active' && _sanchoreDate(widget.shop['proUntil'])?.isAfter(DateTime.now()) == true) const Chip(label: Text('PRO', style: TextStyle(fontWeight: FontWeight.w900)), visualDensity: VisualDensity.compact)]),
                  subtitle: Text(approved
                      ? 'स्वीकृत – सक्रिय'
                      : 'एडमिन की मंज़ूरी बाकी है'),
                  trailing: approved
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.hourglass_top)),
              if (approved) ...[
                Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                        onPressed: addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('सामान जोड़ें'))),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.myProducts(widget.shopId),
                    builder: (context, s) {
                      if (!s.hasData) return const LinearProgressIndicator();
                      if (s.data!.docs.isEmpty) {
                        return const Text('अभी कोई सामान सूची में नहीं है।');
                      }

                      return Column(
                          children: s.data!.docs.map((d) {
                        final x = d.data();
                        return ListTile(
                            dense: true,
                            leading: _productThumb(x['imageUrl']?.toString(), x['productEmoji']?.toString(), x['name']?.toString(), x['imageVerified'] == true),
                            title: Text(x['name'] ?? 'सामान'),
                            subtitle: Text('₹${x['price']} / ${AppLabels.unitLabel(x['unit'])} | उपलब्ध स्टॉक: ${x['stock']}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: 'सामान बदलें', icon: const Icon(Icons.edit_outlined), onPressed: () => editProduct(d.id, x)),
                              IconButton(tooltip: 'सामान हटाएँ', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => deleteProduct(d.id, (x['name'] ?? 'सामान').toString())),
                              Icon(x['active'] == true ? Icons.inventory_2 : Icons.remove_shopping_cart),
                            ]));
                      }).toList());
                    }),
                const Divider(),
                const Text('ऑर्डर',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.myOrders(),
                    builder: (context, s) {
                      if (!s.hasData) return const LinearProgressIndicator();

                      final docs = s.data!.docs
                          .where((d) => d.data()['shopId'] == widget.shopId)
                          .toList();

                      if (docs.isEmpty) {
                        return const Text('अभी कोई ऑर्डर नहीं है।');
                      }

                      return Column(
                          children: docs.map((d) {
                        final x = d.data();
                        final status = (x['status'] ?? '').toString();
                        final deliveryLocation = x['customerLocation'];
                        final hasDeliveryGps = deliveryLocation is Map && deliveryLocation['latitude'] is num && deliveryLocation['longitude'] is num;
                        final next = status == 'placed'
                            ? 'accepted'
                            : status == 'accepted'
                                ? 'preparing'
                                : status == 'preparing'
                                    ? 'ready'
                                    : null;

                        Future<void> change(String value, {String? deliveryMode}) async {
                          try {
                            await service.updateOrderStatus(orderId: d.id, status: value, deliveryMode: deliveryMode);
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
                          }
                        }
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('ऑर्डर ${d.id.substring(0, d.id.length > 8 ? 8 : d.id.length)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('स्थिति: ${AppLabels.effectiveOrderStatus(status, deliveryBoyId: x['deliveryBoyId'])}  •  ₹${x['customerTotal'] ?? x['subtotal'] ?? 0}'),
                              if (status == 'placed') Wrap(spacing: 8, runSpacing: 8, children: [
                                if (hasDeliveryGps) FilledButton.icon(onPressed: () => change('accepted', deliveryMode: 'app'), icon: const Icon(Icons.delivery_dining), label: const Text('ऐप से डिलीवरी')),
                                if (!hasDeliveryGps) const Chip(avatar: Icon(Icons.location_off, size: 16), label: Text('GPS उपलब्ध नहीं: ऐप से डिलीवरी नहीं हो सकती।')),
                                FilledButton.tonalIcon(onPressed: () => change('accepted', deliveryMode: 'external'), icon: const Icon(Icons.storefront), label: const Text('बाहरी डिलीवरी')),
                                OutlinedButton.icon(onPressed: () => change('rejected'), icon: const Icon(Icons.close), label: const Text('अस्वीकार करें')),
                              ]) else if (status == 'ready' && x['deliveryMode'] == 'external')
                                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => change('delivered'), icon: const Icon(Icons.done_all), label: const Text('डिलीवरी पूरी हुई')))
                              else if (next != null) Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => change(next), child: Text(AppLabels.orderAction(next)))),
                            ]),
                          ),
                        );
                      }).toList());
                    }),
              ]
            ])));
  }
}

class DeliveryPanel extends StatelessWidget {
  const DeliveryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();

    return Scaffold(
      appBar: AppBar(title: const Text('डिलीवरी पैनल'), actions: [
        PopupMenuButton<String>(onSelected: (v) async { try { await service.setAvailability(v == 'on'); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v == 'on' ? 'आप डिलीवरी के लिए उपलब्ध हैं।' : 'आप अभी डिलीवरी के लिए उपलब्ध नहीं हैं।'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'on', child: Text('उपलब्ध हों')), PopupMenuItem(value: 'off', child: Text('अनुपलब्ध हों'))], icon: const Icon(Icons.wifi_tethering)),
        IconButton(
            tooltip: 'कमाई',
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DeliveryEarningsScreen()))),
        IconButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }
            },
            icon: const Icon(Icons.logout)),
      ]),
      body: Column(children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: service.myOffers(), builder: (context, offerSnapshot) {
          if (!offerSnapshot.hasData || offerSnapshot.data!.docs.isEmpty) return const SizedBox.shrink();
          return Column(children: offerSnapshot.data!.docs.map((offer) {
            final data = offer.data();
            return Card(color: const Color(0xFFFFF4D6), margin: const EdgeInsets.all(10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('नई डिलीवरी का अनुरोध', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('ऑर्डर: ${offer.id}'), Text('पता: ${data['address'] ?? '-'}'),
              const Text('60 सेकंड के भीतर अनुरोध स्वीकार करें या अस्वीकार करें।'),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: () async { try { await service.respondToOffer(orderId: offer.id, accept: true); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } }, child: const Text('स्वीकार करें')),
                OutlinedButton(onPressed: () async { try { await service.respondToOffer(orderId: offer.id, accept: false); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); } }, child: const Text('अस्वीकार करें')),
              ])
            ])));
          }).toList());
        }),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.myOrders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('ऑर्डर लोड नहीं हो सके।'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs
              .where((d) => !['delivered', 'cancelled', 'rejected']
                  .contains(d.data()['status']))
              .toList();

          if (docs.isEmpty) {
            return const Center(
                child: Text('अभी कोई ऑर्डर नहीं मिला है। डिलीवरी के लिए उपलब्ध रहें और फ़ोन का GPS चालू रखें। नया अनुरोध यहीं दिखाई देगा।'));
          }

          return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();
                final status = data['status'] ?? '';

                return Card(
                    margin: const EdgeInsets.all(10),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ऑर्डर: ${doc.id}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('ग्राहक: ${data['customerId'] ?? '-'}'),
                              Text('पता: ${data['address'] ?? '-'}'),
                              Text('स्थिति: ${AppLabels.effectiveOrderStatus(status, deliveryBoyId: data['deliveryBoyId'])}'),
                              if (['accepted','preparing'].contains(status)) const Text('दुकानदार सामान तैयार कर रहा है। तैयार होने पर उसे ले जाएँ।'),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, children: [
                                if (status == 'ready' || status == 'assigned')
                                  ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await service.updateStatus(
                                              orderId: doc.id,
                                              status: 'picked_up');
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(AppLabels.serverError(e))));
                                          }
                                        }
                                      },
                                      child: const Text('सामान ले लिया')),
                                if (status == 'picked_up')
                                  ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await service.updateStatus(
                                              orderId: doc.id,
                                              status: 'delivered');
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(AppLabels.serverError(e))));
                                          }
                                        }
                                      },
                                      child: const Text('डिलीवरी पूरी करें')),
                                if (status == 'ready' || status == 'assigned' ||
                                    status == 'picked_up')
                                  OutlinedButton(
                                      onPressed: () async {
                                        try {
                                          await service.startTracking(doc.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'लाइव GPS ट्रैकिंग शुरू हो गई है।')));
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(AppLabels.serverError(e))));
                                          }
                                        }
                                      },
                                      child: const Text('GPS शुरू करें')),
                              ]),
                            ])));
              });
        },
      )),
      ]),
    );
  }
}

class StaffRegistrationScreen extends StatefulWidget {
  final String role;

  const StaffRegistrationScreen({super.key, required this.role});

  @override
  State<StaffRegistrationScreen> createState() =>
      _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState extends State<StaffRegistrationScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool saving = false;
  String? nameError;
  String? phoneError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  Future<void> submit() async {
    setState(() {
      nameError = name.text.trim().length < 2 ? 'कम से कम 2 अक्षर का नाम डालें।' : null;
      phoneError = !RegExp(r'^\d{10}$').hasMatch(phone.text.trim()) ? 'सही 10 अंकों का मोबाइल नंबर डालें।' : null;
      emailError = !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim()) ? 'सही ईमेल एड्रेस डालें।' : null;
      passwordError = password.text.length < 6 ? 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए।' : null;
      confirmPasswordError = password.text != confirmPassword.text ? 'दोनों पासवर्ड मेल नहीं खाते।' : null;
    });
    if ([nameError, phoneError, emailError, passwordError, confirmPasswordError].any((e) => e != null)) return;

    setState(() => saving = true);

    try {
      final service = AuthService();

      if (widget.role == 'shopkeeper') {
        await service.registerShopkeeper(
            name: name.text,
            phone: phone.text,
            email: email.text,
            password: password.text);
      } else {
        await service.registerDelivery(
            name: name.text,
            phone: phone.text,
            email: email.text,
            password: password.text);
      }

      TextInput.finishAutofillContext(shouldSave: true);
      await auth.signOut();

      if (!mounted) return;

      _msg('ईमेल सत्यापित हो गया है। आवेदन जमा हो गया है; अब प्रशासनिक मंज़ूरी की प्रतीक्षा करें।');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        setState(() => emailError = 'इस ईमेल से अकाउंट पहले से बना हुआ है।');
      } else if (e.code == 'invalid-email') {
        setState(() => emailError = 'सही ईमेल एड्रेस डालें।');
      } else if (e.code == 'weak-password') {
        setState(() => passwordError = 'पासवर्ड कमज़ोर है। कम से कम 6 अक्षर डालें।');
      } else if (e.code == 'network-request-failed') {
        _msg('इंटरनेट कनेक्शन जाँचें।');
      } else {
        _msg(e.message ?? 'रजिस्ट्रेशन पूरा नहीं हुआ।');
      }
    } catch (e) {
      if (mounted) {
        _msg('पंजीकरण में समस्या: $e');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _msg(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.role == 'shopkeeper'
                ? 'दुकानदार पंजीकरण'
                : 'डिलीवरी पार्टनर पंजीकरण')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(widget.role == 'shopkeeper' ? Icons.storefront_rounded : Icons.delivery_dining_rounded,
                size: 32, color: const Color(0xFF087E58)),
          ),
          const SizedBox(height: 14),
          Text(widget.role == 'shopkeeper' ? 'दुकानदार के रूप में जुड़ें' : 'डिलीवरी पार्टनर के रूप में जुड़ें',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('अपनी जानकारी भरें। आवेदन की जाँच के बाद आपका खाता सक्रिय किया जाएगा।',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 22),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AutofillGroup(child: Column(children: [
          TextField(
              controller: name,
              onChanged: (_) { if (nameError != null) setState(() => nameError = null); },
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: 'पूरा नाम', errorText: nameError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: phone,
              onChanged: (_) { if (phoneError != null) setState(() => phoneError = null); },
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: 'मोबाइल नंबर', errorText: phoneError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: email,
              onChanged: (_) { if (emailError != null) setState(() => emailError = null); },
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: InputDecoration(
                  labelText: 'ईमेल पता', errorText: emailError, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: password,
              onChanged: (_) { if (passwordError != null) setState(() => passwordError = null); },
              obscureText: hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: 'पासवर्ड (कम से कम 6 अक्षर)',
                  errorText: passwordError,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: Icon(hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword)))),
          const SizedBox(height: 12),
          TextField(
              controller: confirmPassword,
              onChanged: (_) { if (confirmPasswordError != null) setState(() => confirmPasswordError = null); },
              obscureText: hideConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: 'पासवर्ड दोबारा भरें',
                  errorText: confirmPasswordError,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: Icon(hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => hideConfirmPassword = !hideConfirmPassword)))),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: saving ? null : submit,
                  child:
                      Text(saving ? 'आवेदन जमा हो रहा है…' : 'आवेदन जमा करें'))),
          const SizedBox(height: 8),
          const Text('खाता एडमिन की मंज़ूरी के बाद ही सक्रिय होगा।'),
          ])))),
        ]),
      );
}

class PendingShopList extends StatelessWidget {
  const PendingShopList({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AdminService().pendingShops(),
    builder: (context, s) {
      if (s.hasError) return const Text('दुकान रिक्वेस्ट की सूची लोड नहीं हो सकी।');
      if (!s.hasData) return const LinearProgressIndicator();
      final docs = s.data!.docs;
      if (docs.isEmpty) return const ListTile(title: Text('अभी कोई नई दुकान रिक्वेस्ट लंबित नहीं है।'));
      return Column(children: docs.map((d) {
        final x = d.data();
        return Card(child: ListTile(
          title: Text((x['name'] ?? 'दुकान').toString()),
          subtitle: Text('श्रेणी: ${(x['category'] ?? '-')}\nमालिक: ${(x['ownerName'] ?? '-')}\nपता: ${(x['address'] ?? '-')}\nमोबाइल: ${(x['phone'] ?? '-')}'),
          isThreeLine: true,
          trailing: Wrap(children: [
            IconButton(tooltip: 'मंजूर करें', icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () async {
              try { await AdminService().reviewShopRequest(d.id, true); }
              catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); }
            }),
            IconButton(tooltip: 'रिजेक्ट करें', icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () async {
              final controller = TextEditingController();
              final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('रिक्वेस्ट रिजेक्ट करें'),
                content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'रिजेक्शन का कारण *', border: OutlineInputBorder())),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')), FilledButton(onPressed: () { if (controller.text.trim().length >= 3) Navigator.pop(ctx, controller.text.trim()); }, child: const Text('रिजेक्ट करें'))],
              ));
              controller.dispose();
              if (reason == null) return;
              try { await AdminService().reviewShopRequest(d.id, false, reason: reason); }
              catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLabels.serverError(e)))); }
            }),
          ]),
        ));
      }).toList());
    },
  );
}

class PendingStaffList extends StatelessWidget {
  const PendingStaffList({super.key});

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdminService().pendingStaff(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Text('कर्मचारी सूची लोड नहीं हो सकी।');
          if (!snapshot.hasData) return const LinearProgressIndicator();

          final docs = snapshot.data!.docs
              .where((d) =>
                  ['shopkeeper', 'delivery'].contains(d.data()['role']) &&
                  (d.data()['applicationStatus'] ?? 'pending') == 'pending')
              .toList();

          if (docs.isEmpty) {
            return const ListTile(
                title: Text('अभी कोई कर्मचारी आवेदन लंबित नहीं है।'));
          }

          return Column(
              children: docs.map((doc) {
            final d = doc.data();

            return Card(
                child: ListTile(
              title: Text('${d['name'] ?? 'कर्मचारी'} – ${AppLabels.userRole(d['role'])}'),
              subtitle: Text('मोबाइल: ${d['phone'] ?? '-'}'),
              isThreeLine: true,
              trailing: Wrap(spacing: 4, children: [
                IconButton(
                    tooltip: 'मंज़ूर करें',
                    onPressed: () async {
                      try {
                        await AdminService().approveStaff(doc.id, true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.green)),
                IconButton(
                    tooltip: 'अस्वीकार करें',
                    onPressed: () async {
                      try {
                        await AdminService().approveStaff(doc.id, false);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(AppLabels.serverError(e))));
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel, color: Colors.red))
              ]),
            ));
          }).toList());
        },
      );
}

class ReadyOrdersAssignment extends StatelessWidget {
  const ReadyOrdersAssignment({super.key});

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('orders')
            .where('status', isEqualTo: 'ready')
            .snapshots(),
        builder: (context, orders) {
          if (orders.hasError) return const Text('तैयार ऑर्डर लोड नहीं हो सके।');
          if (!orders.hasData) return const LinearProgressIndicator();

          if (orders.data!.docs.isEmpty) {
            return const ListTile(title: Text('अभी कोई ऑर्डर तैयार नहीं है।'));
          }

          return Column(
              children: orders.data!.docs
                  .map((doc) =>
                      ReadyOrderAssignCard(orderId: doc.id, data: doc.data()))
                  .toList());
        },
      );
}

class ReadyOrderAssignCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const ReadyOrderAssignCard(
      {super.key, required this.orderId, required this.data});

  @override
  State<ReadyOrderAssignCard> createState() => _ReadyOrderAssignCardState();
}

class _ReadyOrderAssignCardState extends State<ReadyOrderAssignCard> {
  String? selected;
  bool saving = false;

  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ऑर्डर ${widget.orderId}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('दुकान संख्या: ${widget.data['shopId'] ?? '-'}'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('users')
                    .where('role', isEqualTo: 'delivery')
                    .where('approved', isEqualTo: true)
                    .snapshots(),
                builder: (context, staff) {
                  if (!staff.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final people = staff.data!.docs;

                  if (people.isEmpty) {
                    return const Text('अभी कोई स्वीकृत डिलीवरी पार्टनर उपलब्ध नहीं है।');
                  }

                  final ids = people.map((d) => d.id).toSet();

                  if (selected != null && !ids.contains(selected)) {
                    selected = null;
                  }

                  return DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration:
                          const InputDecoration(labelText: 'डिलीवरी पार्टनर'),
                      items: people
                          .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                  '${d.data()['name'] ?? d.id} (${d.data()['phone'] ?? ''})')))
                          .toList(),
                      onChanged:
                          saving ? null : (v) => setState(() => selected = v));
                }),
            const SizedBox(height: 8),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: saving || selected == null
                        ? null
                        : () async {
                            setState(() => saving = true);
                            try {
                              await AdminService().assignDelivery(
                                  orderId: widget.orderId,
                                  deliveryBoyId: selected!);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('डिलीवरी पार्टनर नियुक्त कर दिया गया है।')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLabels.serverError(e))));
                              }
                            } finally {
                              if (mounted) setState(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Assigning...' : 'ASSIGN DELIVERY'))),
          ])));
}

class SimplePanel extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const SimplePanel({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 75, color: Colors.green),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 10),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
