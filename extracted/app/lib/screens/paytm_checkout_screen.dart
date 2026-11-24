import '../utils/app_labels.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';

class PaytmCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String sessionId;
  const PaytmCheckoutScreen({super.key, required this.checkoutUrl, required this.sessionId});

  @override
  State<PaytmCheckoutScreen> createState() => _PaytmCheckoutScreenState();
}

class _PaytmCheckoutScreenState extends State<PaytmCheckoutScreen> {
  WebViewController? controller;
  bool loading = true;
  bool verifying = false;
  bool launching = false;

  @override
  void initState() {
    super.initState();
    // webview_flutter has no web implementation. On web, open the hosted
    // Paytm checkout page from a user gesture and verify after returning.
    if (!kIsWeb) {
      controller = WebViewController();
      _load();
    } else {
      loading = false;
    }
  }

  Future<void> _openWebPayment() async {
    if (launching) return;
    setState(() => launching = true);
    try {
      final opened = await launchUrl(
        Uri.parse(widget.checkoutUrl),
        mode: LaunchMode.platformDefault,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('भुगतान पेज नहीं खुला। दोबारा कोशिश करें।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('भुगतान पेज नहीं खुला। ${AppLabels.serverError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => launching = false);
    }
  }

  Future<void> _load() async {
    final webView = controller!;
    await webView.setJavaScriptMode(JavaScriptMode.unrestricted);
    await webView.addJavaScriptChannel('PaytmResult', onMessageReceived: (message) async {
      if (message.message == 'VERIFY') await _verify();
    });
    await webView.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) { if (mounted) setState(() => loading = false); },
      onWebResourceError: (_) { if (mounted) setState(() => loading = false); },
      onNavigationRequest: (request) {
        final raw = request.url;
        final lower = raw.toLowerCase();
        // UPI app intents must open in the installed payment app, not inside WebView.
        if (lower.startsWith('upi://') || lower.startsWith('intent://') ||
            lower.startsWith('phonepe://') || lower.startsWith('tez://') ||
            lower.startsWith('gpay://') || lower.startsWith('paytmmp://')) {
          var appUrl = raw;
          if (lower.startsWith('intent://')) {
            final scheme = RegExp(r';scheme=([^;]+)').firstMatch(raw)?.group(1);
            final path = raw.substring('intent://'.length).split('#Intent;').first;
            if (scheme != null && scheme.isNotEmpty) appUrl = '$scheme://$path';
          }
          launchUrl(Uri.parse(appUrl), mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ));
    await webView.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _verify() async {
    if (verifying) return;
    setState(() => verifying = true);
    try {
      final paid = await PaymentService().verifyPaytm(widget.sessionId);
      if (!mounted) return;
      if (paid) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('भुगतान अभी कन्फर्म नहीं हुआ। थोड़ी देर बाद दोबारा जाँचें।')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('भुगतान की पुष्टि नहीं हो सकी। ${AppLabels.serverError(e)}')));
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('भुगतान का तरीका चुनें'),
          actions: [
            IconButton(
              onPressed: verifying ? null : _verify,
              tooltip: 'भुगतान की स्थिति जाँचें',
              icon: const Icon(Icons.verified_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Paytm पर सुरक्षित भुगतान करें',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'भुगतान पेज नई टैब/विंडो में खुलेगा। भुगतान पूरा करने के बाद इस पेज पर लौटें और स्थिति जाँचें।',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: launching ? null : _openWebPayment,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(launching ? 'खोल रहे हैं…' : 'Paytm भुगतान खोलें'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: verifying ? null : _verify,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(verifying ? 'जाँच हो रही है…' : 'भुगतान पूरा हुआ — जाँचें'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('भुगतान का तरीका चुनें'),
        actions: [
          IconButton(
            onPressed: _verify,
            tooltip: 'भुगतान की स्थिति जाँचें',
            icon: const Icon(Icons.verified_outlined),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: controller!),
        if (loading || verifying)
          const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator()),
      ]),
    );
  }
}
