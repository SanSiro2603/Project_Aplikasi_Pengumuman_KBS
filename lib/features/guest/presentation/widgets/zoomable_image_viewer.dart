import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ZoomableImageViewer extends StatelessWidget {
  final String imageUrl;

  const ZoomableImageViewer({super.key, required this.imageUrl});

  static Future<void> open(BuildContext context, String imageUrl) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ZoomableImageViewer(imageUrl: imageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview Gambar'),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        panEnabled: true,
        clipBehavior: Clip.none,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(
              color: Colors.white,
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
