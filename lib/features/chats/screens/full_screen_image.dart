import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  // Optional: same tag on the thumbnail = image "flies" into fullscreen
  final String? heroTag;

  const FullscreenImageScreen({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // InteractiveViewer allows pinch-to-zoom, like WhatsApp
    final viewer = InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Image.network(
        imageUrl,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const CircularProgressIndicator(color: Colors.white);
        },
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: heroTag != null ? Hero(tag: heroTag!, child: viewer) : viewer,
      ),
    );
  }
}