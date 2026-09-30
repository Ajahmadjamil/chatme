import 'package:flutter/material.dart';

import '../../../core/shared/widgets/app_skeletons.dart';

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return AppSkeletons.imagePlaceholder(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).width,
              );
            },
          ),
        ),
      ),
    );
  }
}
