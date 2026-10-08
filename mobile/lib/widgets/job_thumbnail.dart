import 'package:flutter/material.dart';
import '../services/api_config.dart';

/// Small square thumbnail showing a job's first photo, used in job list
/// rows (client's "My jobs" list, technician's "Open jobs"/"My work" list).
/// Falls back to a generic icon tile when the job has no images, so it's
/// safe to use unconditionally.
class JobThumbnail extends StatelessWidget {
  final List<String> images;
  final double size;
  const JobThumbnail({super.key, required this.images, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final hasImage = images.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: hasImage
            ? Image.network(
                ApiConfig.mediaUrl(images.first),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.handyman, color: Colors.grey.shade400),
              )
            : Icon(Icons.handyman, color: Colors.grey.shade400),
      ),
    );
  }
}