import 'package:flutter/material.dart';
import '../services/api_config.dart';

/// Horizontal strip of a job's photos for the job-detail screens (both
/// client and technician side). Tapping a photo opens a full-screen,
/// swipeable, pinch-to-zoom viewer. Renders nothing when the job has no
/// images, so callers can drop it into their layout unconditionally.
class JobImageGallery extends StatelessWidget {
  final List<String> images;
  const JobImageGallery({super.key, required this.images});

  void _openFullScreen(BuildContext context, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: PageView.builder(
            controller: PageController(initialPage: startIndex),
            itemCount: images.length,
            itemBuilder: (_, i) => Center(
              child: InteractiveViewer(
                child: Image.network(ApiConfig.mediaUrl(images[i])),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFullScreen(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              ApiConfig.mediaUrl(images[i]),
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 110,
                height: 110,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }
}