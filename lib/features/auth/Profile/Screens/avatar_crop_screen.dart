import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Dark WhatsApp-style cropper with a locked 1:1 circular frame.
class AvatarCropScreen extends StatefulWidget {
  final File imageFile;

  const AvatarCropScreen({super.key, required this.imageFile});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();
  Uint8List? _imageBytes;
  bool _ready = false;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _ready = true;
    });
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        final dir = await getTemporaryDirectory();
        final out = File(
          '${dir.path}/avatar_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await out.writeAsBytes(croppedImage, flush: true);
        if (!mounted) return;
        Navigator.pop(context, out);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: $cause')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Move and scale',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: (!_ready || _cropping)
                ? null
                : () {
                    setState(() => _cropping = true);
                    // Circle UI for framing only — output is square 1:1
                    _controller.crop();
                  },
            child: _cropping
                ? const Text(
                    '…',
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: !_ready || _imageBytes == null
          ? const Center(
              child: Text(
                'Preparing photo…',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Crop(
                    image: _imageBytes!,
                    controller: _controller,
                    aspectRatio: 1,
                    withCircleUi: false,
                    interactive: true,
                    fixCropRect: true,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.72),
                    radius: 0,
                    progressIndicator: const Center(
                      child: Text(
                        'Loading…',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    onCropped: _onCropped,
                    cornerDotBuilder: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      'Drag to reposition. Pinch to zoom. Frame is locked to a square 1:1.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
