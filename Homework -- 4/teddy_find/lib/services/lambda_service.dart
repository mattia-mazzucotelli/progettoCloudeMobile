import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tedx_talk.dart';

class LambdaService {
  static const String _baseUrl =
      'https://nvuuz4bkz1.execute-api.us-east-1.amazonaws.com/default/chromadb-query';
  // static const String _baseUrl =
  //     'http://172.16.136.4:8000/default/chromadb-query';

  static const String _watchNextUrl =
      'https://xirhks7e06.execute-api.us-east-1.amazonaws.com/default/watchNext';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  /// Cerca talk TEDx tramite parola chiave o frase
  static Future<List<TedxTalk>> searchTalks(
    String query, {
    int n_results = 5,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: _headers,
            body: json.encode({
              'query': query,
              'n_results': n_results,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> results = body['results'] ?? [];
        return results.map((e) => TedxTalk.fromJson(e)).toList();
      } else {
        throw LambdaException(
          'Errore API: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on LambdaException {
      rethrow;
    } catch (e) {
      throw LambdaException('Errore di connessione: $e', 0);
    }
  }

  /// Recupera i dettagli di un singolo talk per ID
  static Future<TedxTalk> getTalkById(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/talks/$id');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        return TedxTalk.fromJson(body);
      } else {
        throw LambdaException('Talk non trovato', response.statusCode);
      }
    } on LambdaException {
      rethrow;
    } catch (e) {
      throw LambdaException('Errore di connessione: $e', 0);
    }
  }

  /// Recupera i talk consigliati dopo aver visto un video (watchNext)
  static Future<List<TedxTalk>> getWatchNext(
    String videoId, {
    int n = 5,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_watchNextUrl),
            headers: {'Content-Type': 'application/json'},
            // La Lambda vuole video_id come stringa
            body: json.encode({'video_id': videoId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> watchNext = body['watch_next'] ?? [];
        return watchNext.map((e) => TedxTalk.fromJson(e)).toList();
      } else {
        throw LambdaException(
          'Errore watchNext: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on LambdaException {
      rethrow;
    } catch (e) {
      throw LambdaException('Errore di connessione watchNext: $e', 0);
    }
  }

  /// Recupera i talk più popolari / featured
  static Future<List<TedxTalk>> getFeaturedTalks() async {
    try {
      final uri = Uri.parse('$_baseUrl/featured');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> results = body['results'] ?? [];
        return results.map((e) => TedxTalk.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }
}

class LambdaException implements Exception {
  final String message;
  final int statusCode;
  LambdaException(this.message, this.statusCode);

  @override
  String toString() => message;
}
