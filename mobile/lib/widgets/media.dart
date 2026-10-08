import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/catalog.dart';
import '../core/theme.dart';
import '../services/api_config.dart';
import 'states.dart';

/// Network image from the backend's /uploads with a skeleton while loading
/// and a category-coloured placeholder when missing or broken.
class NetImage extends StatelessWidget {
  final String file;
  final BoxFit fit;
  final CategoryInfo? placeholder;
  final double? width;
  final double? height;

  const NetImage(this.file, {super.key, this.fit = BoxFit.cover, this.placeholder, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final ph = _Placeholder(info: placeholder);
    if (file.isEmpty) return SizedBox(width: width, height: height, child: ph);
    return Image.network(
      ApiConfig.mediaUrl(file),
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : SizedBox(width: width, height: height, child: const Skeleton(radius: 0)),
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: height, child: ph),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final CategoryInfo? info;
  const _Placeholder({this.info});

  @override
  Widget build(BuildContext context) {
    final c = info?.color ?? context.colors.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: context.isDark ? 0.3 : 0.18), c.withValues(alpha: context.isDark ? 0.12 : 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (_, box) => Center(
          child: Icon(info?.icon ?? Icons.image_outlined, color: c, size: (box.maxHeight.isFinite ? box.maxHeight : 80) * 0.36),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
class PhotoViewer extends StatefulWidget {
  final List<String> images;
  final int initial;
  const PhotoViewer({super.key, required this.images, this.initial = 0});

  static void open(BuildContext context, List<String> images, [int initial = 0]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoViewer(images: images, initial: initial)));
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _index = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}', style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initial),
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              ApiConfig.mediaUrl(widget.images[i]),
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of thumbnails that open the viewer.
class PhotoStrip extends StatelessWidget {
  final List<String> images;
  final double size;
  const PhotoStrip({super.key, required this.images, this.size = 96});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => PhotoViewer.open(context, images, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: NetImage(images[i], width: size, height: size),
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick a photo from camera (mobile) or gallery.
Future<XFile?> pickImage(BuildContext context, {double maxWidth = 1600}) async {
  final source = kIsWeb
      ? ImageSource.gallery
      : await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
  if (source == null) return null;
  return ImagePicker().pickImage(source: source, imageQuality: 82, maxWidth: maxWidth);
}

/// Preview of a picked (not yet uploaded) image.
class LocalImage extends StatelessWidget {
  final XFile file;
  final double size;
  const LocalImage(this.file, {super.key, this.size = 96});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover)
            : Skeleton(width: size, height: size, radius: 0),
      );
}

/// Grid of existing (uploaded) + newly picked photos with add/remove.
class PhotoPickerGrid extends StatelessWidget {
  final List<String> existing;
  final List<XFile> picked;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<String>? onRemoveExisting;
  final ValueChanged<int> onRemovePicked;

  const PhotoPickerGrid({
    super.key,
    this.existing = const [],
    required this.picked,
    required this.max,
    required this.onAdd,
    required this.onRemovePicked,
    this.onRemoveExisting,
  });

  Widget _tile(BuildContext context, Widget child, VoidCallback onRemove) => Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 96, height: 96, child: child)),
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final count = existing.length + picked.length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in existing) _tile(context, NetImage(e), () => onRemoveExisting?.call(e)),
        for (var i = 0; i < picked.length; i++) _tile(context, LocalImage(picked[i]), () => onRemovePicked(i)),
        if (count < max)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.4), width: 1.4),
                color: context.colors.primary.withValues(alpha: 0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: context.colors.primary),
                  const SizedBox(height: 4),
                  Text('$count/$max', style: TextStyle(fontSize: 12, color: context.palette.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
