import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../constants/personas.dart';
import '../services/api_service.dart';

class MessageController extends GetxController {
  final Persona persona;
  var errorTick = 0.obs;
  MessageController(this.persona);

  late final String _storageKey = 'chat_${persona.id}';
  var responseText = "".obs;
  var messages = <Map<String, dynamic>>[].obs;
  var isTypeing = false.obs;
  final GetStorage _box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _loadMessages();
  }

  void _loadMessages() {
    final saved = _box.read<List>(_storageKey);
    if (saved != null) {
      messages.assignAll(
        saved.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }
  }

  void _saveMessages() {
    // error replies are shown on screen but not stored
    final toSave = messages.where((m) => m['isError'] != true).toList();
    _box.write(_storageKey, toSave);
  }

  void clearChat() {
    messages.clear();
    _box.remove(_storageKey);
  }

  Future<void> sendMessage(String message) async {
    messages.add(
      {
        'text': message,
        'isUser': true,
        'time': DateFormat('hh:mm a').format(DateTime.now())
      },
    );
    _saveMessages();

    await _getReply();
  }

  Future<void> retryLast() async {
    if (isTypeing.value) {
      return;
    }

    if (messages.isNotEmpty && messages.last['isError'] == true) {
      messages.removeLast();
    }

    await _getReply();
  }

  Future<void> _getReply() async {
    responseText.value = "Thinking..";
    isTypeing.value = true;
    update();

    // send the earlier conversation too, so the AI remembers it
    String reply = await GooglleApiService.getApiResponse(
        messages, persona.systemPrompt);

    responseText.value = reply;

    final bool isError = reply.startsWith("Error");

    messages.add(
      {
        'text': reply,
        'isUser': false,
        'isError': isError,
        'time': DateFormat('hh:mm a').format(DateTime.now())
      },
    );
    _saveMessages();

    isTypeing.value = false;
    update();
  }
}