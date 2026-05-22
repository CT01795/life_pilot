import 'dart:convert';
import 'package:http/http.dart' as http;

class ServiceApi {
  final String baseUrl;

  ServiceApi(this.baseUrl);

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body);
  }
}