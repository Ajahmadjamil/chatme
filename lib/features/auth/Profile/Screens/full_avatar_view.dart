import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp-style full-screen profile photo preview.
class FullAvatarView extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? heroTag;

  const FullAvatarView({
    super.key,
    required this.imageUrl,
    required this.title,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final image = Image.network(
      imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white38,
        size: 72,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: heroTag == null
                    ? AspectRatio(aspectRatio: 1, child: image)
                    : Hero(
                        tag: heroTag!,
                        child: AspectRatio(aspectRatio: 1, child: image),
                      ),
              ),
            ),
            // Top bar: back + name
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, top + 4, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
