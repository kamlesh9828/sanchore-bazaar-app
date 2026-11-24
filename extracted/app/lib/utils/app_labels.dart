/// Centralized Hindi labels for app states and server errors.
/// Database values remain stable English keys; only customer-facing text is translated.
class AppLabels {
  static String orderStatus(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'pending':
      case 'placed':
      case 'new':
      case 'confirmed':
        return 'ऑर्डर प्राप्त हुआ';
      case 'accepted':
        return 'दुकानदार ने ऑर्डर स्वीकार किया';
      case 'preparing':
        return 'सामान तैयार हो रहा है';
      case 'ready':
        return 'ऑर्डर तैयार है';
      case 'assigned':
      case 'offered':
        return 'डिलीवरी पार्टनर को भेजा गया';
      case 'picked_up':
        return 'सामान डिलीवरी के लिए निकल चुका है';
      case 'delivered':
        return 'ऑर्डर सफलतापूर्वक पहुँच गया';
      case 'cancelled':
      case 'canceled':
        return 'ऑर्डर रद्द कर दिया गया';
      case 'rejected':
        return 'ऑर्डर अस्वीकार कर दिया गया';
      case 'payment_failed':
      case 'failed':
        return 'भुगतान असफल रहा';
      case 'pending_payment':
        return 'भुगतान की प्रतीक्षा है';
      default:
        return 'स्थिति अपडेट हो रही है';
    }
  }

  static String effectiveOrderStatus(Object? status, {Object? deliveryBoyId}) {
    final key = (status ?? '').toString().toLowerCase();
    if (key == 'ready' && (deliveryBoyId ?? '').toString().trim().isNotEmpty) {
      return 'डिलीवरी पार्टनर नियुक्त';
    }
    return orderStatus(status);
  }

  static String orderAction(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'accepted': return 'ऑर्डर स्वीकार करें';
      case 'preparing': return 'तैयारी शुरू करें';
      case 'ready': return 'सामान तैयार है';
      case 'picked_up': return 'सामान ले लिया';
      case 'delivered': return 'डिलीवरी पूरी करें';
      default: return 'आगे बढ़ें';
    }
  }

  static String paymentStatus(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'paid':
      case 'verified':
        return 'भुगतान पूरा हुआ';
      case 'pending':
        return 'भुगतान बाकी है';
      case 'failed':
      case 'payment_failed':
        return 'भुगतान असफल';
      case 'refunded':
        return 'राशि वापस कर दी गई';
      case 'not_requested':
        return 'भुगतान अनुरोध नहीं भेजा गया';
      default:
        return 'भुगतान की स्थिति उपलब्ध नहीं';
    }
  }

  static String adStatus(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'draft':
        return 'मसौदा';
      case 'pending':
      case 'pending_admin_review':
        return 'जाँच की प्रतीक्षा';
      case 'awaiting_payment':
        return 'भुगतान की प्रतीक्षा';
      case 'active':
        return 'चालू';
      case 'paused':
        return 'रोक दिया गया';
      case 'rejected':
        return 'अस्वीकृत';
      case 'converted':
        return 'विज्ञापन तैयार';
      case 'expired':
        return 'अवधि समाप्त';
      default:
        return 'स्थिति उपलब्ध नहीं';
    }
  }

  static String unitLabel(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'piece': case 'pcs': case 'unit': return 'नग';
      case 'kg': case 'kilogram': return 'किलो';
      case 'gram': case 'g': return 'ग्राम';
      case 'litre': case 'liter': case 'l': return 'लीटर';
      case 'ml': return 'मिलीलीटर';
      case 'pack': case 'packet': return 'पैकेट';
      default: return (value ?? 'नग').toString();
    }
  }

  static String discountType(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'percentage': return 'प्रतिशत छूट';
      case 'fixed': return 'तय राशि की छूट';
      default: return 'छूट';
    }
  }

  static String userRole(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'customer': return 'ग्राहक';
      case 'shopkeeper': return 'दुकानदार';
      case 'delivery': return 'डिलीवरी पार्टनर';
      case 'admin': return 'एडमिन';
      default: return 'कर्मचारी';
    }
  }

  static String requestStatus(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'open': return 'खुला';
      case 'pending': return 'लंबित';
      case 'resolved': return 'समाधान हो गया';
      case 'closed': return 'बंद';
      case 'approved': return 'स्वीकृत';
      case 'rejected': return 'अस्वीकृत';
      default: return 'स्थिति उपलब्ध नहीं';
    }
  }

  static String paymentMethod(Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'cod':
        return 'सामान मिलने पर नकद';
      case 'paytm':
        return 'ऑनलाइन भुगतान';
      case 'wallet':
        return 'वॉलेट पॉइंट';
      default:
        return 'उपलब्ध नहीं';
    }
  }

  /// Converts common backend/legacy messages into clean Hindi.
  /// Unknown technical errors are hidden behind a consistent user-safe message.
  static String serverError(Object? error) {
    var message = (error ?? '').toString().replaceFirst('Exception: ', '').trim();
    final lower = message.toLowerCase();
    if (message.isEmpty) return 'कार्य पूरा नहीं हो सका। कृपया दोबारा प्रयास करें।';
    if (lower.contains('permission') || lower.contains('unauthorized') || lower.contains('forbidden')) return 'आपको यह कार्य करने की अनुमति नहीं है।';
    if (lower.contains('network') || lower.contains('internet') || lower.contains('fetch failed') || lower.contains('timeout')) return 'इंटरनेट कनेक्शन जाँचकर दोबारा प्रयास करें।';
    if (lower.contains('not found') || lower.contains('does not exist')) return 'माँगी गई जानकारी नहीं मिली।';
    if (lower.contains('insufficient') || lower.contains('not enough stock')) return 'उपलब्ध स्टॉक या शेष राशि पर्याप्त नहीं है।';
    if (lower.contains('payment') && (lower.contains('failed') || lower.contains('failure'))) return 'भुगतान पूरा नहीं हुआ। भुगतान की स्थिति जाँचकर दोबारा प्रयास करें।';
    if (lower.contains('already') && (lower.contains('exists') || lower.contains('pending'))) return 'यह अनुरोध पहले से दर्ज है।';
    if (lower.contains('invalid') || lower.contains('required') || lower.contains('must be')) return 'भरी गई जानकारी सही नहीं है। कृपया जाँचकर दोबारा भरें।';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(message) && !RegExp(r'\b(hai|nahi|karein|karo|gaya|gayi|hua|hui|bhej|liye|sahi|abhi|koi|pehle|dobara|bharein|ho gaya|ho gayi)\b', caseSensitive: false).hasMatch(message)) return message;
    return 'कार्य पूरा नहीं हो सका। कृपया दोबारा प्रयास करें।';
  }
}
