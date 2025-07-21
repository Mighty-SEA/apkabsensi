import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class SAFHelper {
  static const MethodChannel _channel = MethodChannel('saf_channel');
  static const String _documentTreeUriKey = 'document_tree_uri';

  static Future<String?> getSavedDocumentTreeUri() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_documentTreeUriKey);
    developer.log('Retrieved saved URI: $uri');
    return uri;
  }

  static Future<bool> saveDocumentTreeUri(String uri) async {
    developer.log('Saving URI: $uri');
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_documentTreeUriKey, uri);
  }

  static Future<bool> clearSavedUri() async {
    developer.log('Clearing saved URI');
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_documentTreeUriKey);
  }

  static Future<String?> openDocumentTree() async {
    try {
      developer.log('Opening document tree picker...');
      final uri = await _channel.invokeMethod<String>('openDocumentTree');
      developer.log('Document tree picker returned URI: $uri');
      
      if (uri != null) {
        await saveDocumentTreeUri(uri);
      }
      return uri;
    } catch (e) {
      developer.log('Error opening document tree: $e', error: e);
      return null;
    }
  }

  static Future<bool> writeFileToUri({
    required String uri,
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  }) async {
    try {
      developer.log('Writing file to URI: $uri, fileName: $fileName');
      final result = await _channel.invokeMethod<bool>('writeFileToUri', {
        'uri': uri,
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': mimeType,
      });
      developer.log('Write file result: $result');
      return result ?? false;
    } catch (e) {
      developer.log('Error writing file: $e', error: e);
      return false;
    }
  }
} 