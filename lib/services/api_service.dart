import 'package:dio/dio.dart';
import '../models/creatives.dart';

class ApiService {
  static const String baseUrl = 'https://mybeta.dibs.design';
  static const int itemsPerPage = 20;
  final Dio dio;

  ApiService() : dio = Dio() {
    dio.options.baseUrl = baseUrl;
    dio.options.headers['Authorization'] =
    'Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJzb21lc2hzd2FtaTlAZ21haWwuY29tIiwicm9sZSI6IlJPTEVfQ1JFQVRJVkUiLCJmbiI6IkJhbWF5eWEgU3dhbWkiLCJzZCI6Im15YmV0YS5kaWJzLmRlc2lnbiIsInNpZCI6IlVTTVlCRTI2MTIyNFNFOVFHRkhSNFJMVDJSQksiLCJzcCI6Ikdvb2dsZSIsImV4cCI6MTczNTIzNTkwNywiaXNzIjoiand0LnVzZ3cifQ.J5abTVClR-GlKyFBvspPa5DCHtoWr7f46jHhRsllC2yg75oN1OLOP3BxaVm54stFnULgeMZP_P5MngIqeAlIuw';}
    Future<List<Creative>> fetchCreatives({required int page}) async {
    try {
      print('[LOG] Making API request for page $page');
      
      final formData = FormData.fromMap({
        'pageno': page,
      });

      print('Sending request to: $baseUrl/api/creative/v4/fetch/community'); 
      final response = await dio.post(
        '/api/creative/v4/fetch/community',
        data: formData,
      );

      print('[LOG] Response status: ${response.statusCode}');
      print('Response data: ${response.data}'); 

      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['data'] ?? [];
        print('Parsed ${items.length} items from response'); 
        
        final creatives = items.map((json) => Creative.fromJson(json)).toList();
        print('Converted to ${creatives.length} Creative objects'); 
        
        return creatives;
      } else {
        throw Exception('Failed to load creatives: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('DioException: ${e.message}'); 
      if (CancelToken.isCancel(e)) {
        print('Request was cancelled'); 
        throw Exception('Request cancelled');
      }
      throw Exception('Error fetching creatives: ${e.message}');
    } catch (e) {
      print('General error: $e'); 
      throw Exception('Error fetching creatives: $e');
    }
  }
}
