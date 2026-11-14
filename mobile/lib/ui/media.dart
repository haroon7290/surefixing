import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import 'brand.dart';
import 'icons.dart';
import 'sheets.dart';

/// An uploaded image with a calm placeholder while loading or if missing.
class NetImage extends StatelessWidget {
  final String file;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;
  final String? label;
  const NetImage(this.file, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.fallback, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final empty = fallback ?? Container(color: c.sunken, alignment: Alignment.center, child: Icon(AppIcons.image, color: c.muted));
    if (file.isEmpty) return SizedBox(width: width, height: height, child: empty);
    return Image.network(
      mediaUrl(file),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      semanticLabel: label,
      excludeFromSemantics: label == null,
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: height, child: empty),
      frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : Container(width: width, height: height, color: c.sunken),
    );
  }
}

/// Tinted artwork for a category: stands in when a tool or job has no photo.
class CategoryArt extends StatelessWidget {
  final CatalogItem category;
  final double iconSize;
  const CategoryArt(this.category, {super.key, this.iconSize = 44});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [category.color.withValues(alpha: 0.22), category.color.withValues(alpha: 0.08)],
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (iconSize >= 40) HexPattern(color: category.color.withValues(alpha: 0.16), cell: iconSize * 0.8),
          Center(child: Icon(category.icon, size: iconSize, color: category.color)),
        ]),
      );
}

/// Photo of a tool or job, falling back to its category artwork.
class CoverImage extends StatelessWidget {
  final String file;
  final CatalogItem category;
  final double iconSize;
  final String? label;
  const CoverImage(this.file, {super.key, required this.category, this.iconSize = 44, this.label});

  @override
  Widget build(BuildContext context) => NetImage(file, fallback: CategoryArt(category, iconSize: iconSize), label: label, width: double.infinity, height: double.infinity);
}

/// Horizontal strip of thumbnails; tap one to view it full screen.
class PhotoStrip extends StatelessWidget {
  final List<String> files;
  final double size;
  const PhotoStrip(this.files, {super.key, this.size = 84});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: size,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: files.length,
          separatorBuilder: (_, __) => Gap.w8,
          itemBuilder: (context, i) => Semantics(
            button: true,
            label: 'Photo ${i + 1} of ${files.length}',
            child: GestureDetector(
              onTap: () => openGallery(context, files, i),
              child: ClipRRect(borderRadius: BorderRadius.circular(R.md), child: NetImage(files[i], width: size, height: size)),
            ),
          ),
        ),
      );
}

/// Full-screen, zoomable photo viewer.
void openGallery(BuildContext context, List<String> files, [int index = 0]) {
  final controller = PageController(initialPage: index);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (context) => Stack(children: [
      PageView.builder(
        controller: controller,
        itemCount: files.length,
        itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: NetImage(files[i], fit: BoxFit.contain))),
      ),
      Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        right: 16,
        child: IconButton.filled(
          tooltip: 'Close',
          style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close, size: 18),
        ),
      ),
    ]),
  );
}

/// Picks one photo. On phones offers the camera or the gallery.
Future<XFile?> pickPhoto(BuildContext context, {bool preferCamera = false}) async {
  final picker = ImagePicker();
  var source = ImageSource.gallery;
  if (!kIsWeb) {
    final choice = await showAppSheet<ImageSource>(
      context,
      title: 'Add a photo',
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(AppIcons.camera),
          title: const Text('Take a photo'),
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(AppIcons.image),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
      ]),
    );
    if (choice == null) return null;
    source = choice;
  }
  try {
    return await picker.pickImage(source: source, imageQuality: 82, maxWidth: 1800);
  } catch (e) {
    toastError('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}');
    return null;
  }
}

/// Picks several photos from the gallery, up to [max].
Future<List<XFile>> pickPhotos({int max = 5}) async {
  try {
    final files = await ImagePicker().pickMultiImage(imageQuality: 82, maxWidth: 1800);
    if (files.length > max) toast('Only the first $max photos were added');
    return files.take(max).toList();
  } catch (e) {
    toastError('Could not open the gallery');
    return [];
  }
}

/// Shows a picked (not yet uploaded) photo.
class LocalImage extends StatelessWidget {
  final XFile file;
  final double? size;
  const LocalImage(this.file, {super.key, this.size});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snap) =>
            snap.hasData ? Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true) : Container(width: size, height: size, color: context.colors.sunken),
      );
}

/// Grid of chosen photos with an "Add" tile. [existing] are photos already
/// on the server (shown first, removable through [onRemoveExisting]).
class PhotoPicker extends StatelessWidget {
  final List<XFile> picked;
  final ValueChanged<List<XFile>> onChanged;
  final List<String> existing;
  final ValueChanged<String>? onRemoveExisting;
  final int max;
  final String addLabel;
  const PhotoPicker({super.key, required this.picked, required this.onChanged, this.existing = const [], this.onRemoveExisting, this.max = 5, this.addLabel = 'Add photos'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final room = max - existing.length - picked.length;
    const size = 88.0;

    Widget tile(Widget image, VoidCallback? onRemove) => Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(R.md), child: SizedBox.square(dimension: size, child: image)),
          if (onRemove != null)
            Positioned(
              right: -6,
              top: -6,
              child: Semantics(
                button: true,
                label: 'Remove photo',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                    child: Icon(AppIcons.close, size: 11, color: c.canvas),
                  ),
                ),
              ),
            ),
        ]);

    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final file in existing) tile(NetImage(file), onRemoveExisting == null ? null : () => onRemoveExisting!(file)),
      for (final file in picked) tile(LocalImage(file, size: size), () => onChanged([...picked]..remove(file))),
      if (room > 0)
        Semantics(
          button: true,
          label: addLabel,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(R.md),
            onTap: () async {
              final added = await pickPhotos(max: room);
              if (added.isNotEmpty) onChanged([...picked, ...added]);
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md), border: Border.all(color: c.line)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(AppIcons.camera, color: c.body),
                Gap.h4,
                Text('Add', style: context.text.labelMedium),
              ]),
            ),
          ),
        ),
    ]);
  }
}
