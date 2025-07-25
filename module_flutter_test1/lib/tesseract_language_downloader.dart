import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TesseractLanguageDownloader {
  static const String baseUrl =
      'https://github.com/tesseract-ocr/tessdata/raw/main/';

  static Future<bool> downloadThaiLanguageModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tessDataDir = Directory('${appDir.path}/tessdata');

      if (!await tessDataDir.exists()) {
        await tessDataDir.create(recursive: true);
      }

      final thaiModelPath = '${tessDataDir.path}/tha.traineddata';
      final engModelPath = '${tessDataDir.path}/eng.traineddata';

      // Download Thai model if not exists
      if (!await File(thaiModelPath).exists()) {
        if (kDebugMode) {
          print('Downloading Thai language model...');
        }

        final response = await http.get(Uri.parse('${baseUrl}tha.traineddata'));
        if (response.statusCode == 200) {
          await File(thaiModelPath).writeAsBytes(response.bodyBytes);
          if (kDebugMode) {
            print('Thai model downloaded successfully');
          }
        } else {
          throw Exception('Failed to download Thai model');
        }
      }

      // Download English model if not exists
      if (!await File(engModelPath).exists()) {
        if (kDebugMode) {
          print('Downloading English language model...');
        }

        final response = await http.get(Uri.parse('${baseUrl}eng.traineddata'));
        if (response.statusCode == 200) {
          await File(engModelPath).writeAsBytes(response.bodyBytes);
          if (kDebugMode) {
            print('English model downloaded successfully');
          }
        } else {
          throw Exception('Failed to download English model');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading language models: $e');
      }
      return false;
    }
  }
}
