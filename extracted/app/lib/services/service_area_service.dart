import 'worker_api.dart';

class ServiceAreaService {
  Future<bool> isLocationServiceable({
    required String pinCode,
    double? latitude,
    double? longitude,
  }) async {
    final result = await WorkerApi.post('/api/checkServiceArea', {
      'pinCode': pinCode.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return result['serviceable'] == true;
  }
}
