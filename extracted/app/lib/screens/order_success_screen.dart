import 'package:flutter/material.dart';

/// Shown only after order creation and, for Paytm, server-side payment verification.
class OrderSuccessScreen extends StatefulWidget {
  final List<String> orderIds;
  final bool paymentSuccessful;
  final String paymentMethod;

  const OrderSuccessScreen({
    super.key,
    required this.orderIds,
    required this.paymentSuccessful,
    required this.paymentMethod,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF087E58);

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF7),
      appBar: AppBar(
        title: const Text('ऑर्डर की पुष्टि'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: green.withOpacity(.10),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: green.withOpacity(.25),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 76,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      const Text(
                        'ऑर्डर सफलतापूर्वक हो गया!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'आपका ऑर्डर दुकान तक भेज दिया गया है।',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      _statusTile(
                        Icons.receipt_long_rounded,
                        'ऑर्डर सफल',
                        'आपका ऑर्डर दर्ज हो गया है।',
                        green,
                      ),
                      const SizedBox(height: 10),
                      _statusTile(
                        widget.paymentSuccessful
                            ? Icons.verified_rounded
                            : Icons.payments_outlined,
                        widget.paymentSuccessful
                            ? 'Payment Successful'
                            : (widget.paymentMethod == 'cod'
                                ? 'Cash on Delivery'
                                : 'भुगतान की पुष्टि बाकी'),
                        widget.paymentSuccessful
                            ? 'Paytm से भुगतान सफलतापूर्वक सत्यापित हुआ।'
                            : (widget.paymentMethod == 'cod'
                                ? 'सामान मिलने पर नकद भुगतान करें।'
                                : 'भुगतान की स्थिति ऑर्डर में जाँचें।'),
                        widget.paymentSuccessful ? green : Colors.blueGrey,
                      ),
                      if (widget.orderIds.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ऑर्डर नंबर',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              ...widget.orderIds.map(
                                (id) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: SelectableText(
                                    id,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('खरीदारी जारी रखें'),
                          style: FilledButton.styleFrom(
                            backgroundColor: green,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
