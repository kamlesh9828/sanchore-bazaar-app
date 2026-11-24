import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Cross-platform Cloudinary upload. The unsigned preset must be restricted
/// in Cloudinary (allowed formats, max file size, and upload folder policy).
class ImageService {
  static const String _cloudName = 'gpmylwxq';
  static const String _uploadPreset = 'sanchore_bazaar';

  Future<String> uploadProductImage({required XFile file, required String productId}) =>
      _upload(file: file, folder: 'products/$productId');

  Future<String> uploadShopImage({required XFile file, required String shopId}) =>
      _upload(file: file, folder: 'shops/$shopId');

  Future<String> uploadAdImage({required XFile file, required String adId}) =>
      _upload(file: file, folder: 'advertisements/$adId');

  Future<String> uploadAdReference({required XFile file, required String requestId}) =>
      _upload(file: file, folder: 'advertisement-requests/$requestId');

  Future<String> uploadAdImageBytes({required Uint8List bytes, required String adId, String filename = 'ai-ad.jpg'}) async {
    if (bytes.isEmpty) throw Exception('AI से बनी फोटो खाली है');
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'advertisements/$adId'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'];
      throw Exception(error is Map ? (error['message'] ?? 'AI फोटो अपलोड नहीं हुई') : 'AI फोटो अपलोड नहीं हुई');
    }
    final url = data['secure_url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Cloudinary ने फोटो URL नहीं दिया');
    return url;
  }

  Future<String> _upload({required XFile file, required String folder}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('चुनी गई फोटो खाली है।');
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> data;
    try { data = jsonDecode(response.body) as Map<String, dynamic>; }
    catch (_) { throw Exception('फोटो सर्वर से सही जवाब नहीं मिला।'); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'];
      throw Exception(error is Map ? (error['message'] ?? 'फोटो अपलोड नहीं हो सकी।') : 'फोटो अपलोड नहीं हो सकी। (त्रुटि ${response.statusCode})');
    }
    final url = data['secure_url'] as String?;
    if (url == null || url.isEmpty) throw Exception('फोटो का लिंक नहीं मिला।');
    return url;
  }


  Future<String> uploadProductImageFromUrl({required String imageUrl, required String productId}) async {
    final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('चुनी गई ऑनलाइन फोटो डाउनलोड नहीं हो सकी।');
    }
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'products/$productId'
      ..files.add(http.MultipartFile.fromBytes('file', response.bodyBytes, filename: 'product.jpg'));
    final streamed = await request.send().timeout(const Duration(seconds: 35));
    final result = await http.Response.fromStream(streamed);
    final data = jsonDecode(result.body) as Map<String, dynamic>;
    if (result.statusCode < 200 || result.statusCode >= 300) {
      final error = data['error'];
      throw Exception(error is Map ? (error['message'] ?? 'फोटो अपलोड नहीं हो सकी।') : 'फोटो अपलोड नहीं हो सकी।');
    }
    final url = data['secure_url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('अपलोड की गई फोटो का लिंक नहीं मिला।');
    return url;
  }

  Future<void> deleteImage(String downloadUrl) async {
    throw UnsupportedError('फोटो हटाने की सुविधा अभी उपलब्ध नहीं है।');
  }
}
