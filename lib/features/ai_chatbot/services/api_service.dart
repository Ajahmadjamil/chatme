import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class GooglleApiService {
  static String apiKey = ApiConstant.apiKey;
  static String baseUrl = ApiConstant.baseUrl;

  // How many recent messages to send (keeps cost and speed under control)
  static const int _maxHistory = 20;

  // Change 1: API ko call karne ka kaam ab alag function karega
  static Future<http.Response> _post(
      List<Map<String, dynamic>> contents, String systemPrompt) {
    return http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey, // key in header, not in the URL
      },
      body: jsonEncode({
        "system_instruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "contents": contents,
      }),
    );
  }

  static Future<String> getApiResponse(
      List<Map<String, dynamic>> messages, String systemPrompt) async {
    try {
      // Skip error messages, keep only the latest messages
      final cleaned = messages.where((m) => m['isError'] != true).toList();
      final recent = cleaned.length > _maxHistory
          ? cleaned.sublist(cleaned.length - _maxHistory)
          : cleaned;

      // Simple loop se contents banao (same kaam jo pehle map() karta tha)
      final List<Map<String, dynamic>> contents = [];
      for (int i = 0; i < recent.length; i++) {
        final m = recent[i];
        contents.add({
          "role": m['isUser'] == true ? "user" : "model",
          "parts": [
            {"text": m['text'].toString()}
          ]
        });
      }

      // Change 2: pehli baar call
      http.Response response = await _post(contents, systemPrompt);

      // 503 aaye to 2 baar khud dobara try karo
      int attempt = 0;
      while (response.statusCode == 503 && attempt < 2) {
        attempt = attempt + 1;
        await Future.delayed(Duration(seconds: 2 * attempt));
        response = await _post(contents, systemPrompt);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if response has "candidates" and "content"
        if (data.containsKey("candidates") && data["candidates"].isNotEmpty) {
          var firstCandidate = data["candidates"][0];

          if (firstCandidate.containsKey("content") &&
              firstCandidate["content"].containsKey("parts") &&
              firstCandidate["content"]["parts"].isNotEmpty) {
            return firstCandidate["content"]["parts"][0]["text"] ??
                "AI response was empty.";
          }
        }
        return "AI did not return any content.";
      } else if (response.statusCode == 429) {
        // Change 3: limit exceed ka message
        debugPrint("API error 429: ${response.body}");
        return "Error: Limit exceeded. Please try again later.";
      } else if (response.statusCode == 503) {
        // Change 3: server busy ka message
        debugPrint("API error 503: ${response.body}");
        return "Error: Server is busy right now. Tap Retry.";
      } else {
        // Do not show the raw server response to users
        debugPrint("API error ${response.statusCode}: ${response.body}");
        return "Error: Something went wrong (code ${response.statusCode}). Please try again.";
      }
    } catch (e) {
      debugPrint("Error=> $e");
      return "Error: Could not reach the AI. Check your internet and try again.";
    }
  }
}