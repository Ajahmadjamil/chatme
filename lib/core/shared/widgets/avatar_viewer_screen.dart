import 'package:flutter/material.dart';

// Full-screen view of any profile/avatar picture, with pinch-to-zoom.
// Used from: Edit Profile screen, Home screen chat list, Conversation header.
class AvatarViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title; // name shown at the top

  const AvatarViewerScreen({
    super.key,
    required this.imageUrl,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}