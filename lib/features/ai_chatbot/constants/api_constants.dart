import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstant{
  static String get apiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }
  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent";
}