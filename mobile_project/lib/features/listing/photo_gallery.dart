import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;

const galleryHeight = 270.0;

/// Galerie en tête de fiche : balayage, compteur « 1 / N », plein écran au toucher.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.photos, this.bottomInset = 20});

  final List<Photo> photos;

  /// Hauteur recouverte par le panneau ivoire (le compteur reste au-dessus).
  final double bottomInset;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _index = 0;

  void _openViewer() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewer(photos: widget.photos, initialIndex: _index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const _PhotoPlaceholder();
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => GestureDetector(
          onTap: _openViewer,
          child: _NetworkPhoto(url: photos[i].largeUrl),
        ),
      ),
      if (photos.length > 1)
        Positioned(
          right: 14,
          bottom: widget.bottomInset + 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: WellyColors.ink.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('${_index + 1} / ${photos.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: WellyColors.ivoire)),
            ),
          ),
        ),
    ]);
  }
}

/// Visionneuse plein écran (zoom au pincement).
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0});
  final List<Photo> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _index = widget.initialIndex;
  late final _controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WellyColors.ivoire,
        appBar: AppBar(
          backgroundColor: WellyColors.ivoire,
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('${_index + 1} / ${widget.photos.length}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
          centerTitle: true,
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(child: _NetworkPhoto(url: widget.photos[i].largeUrl, fit: BoxFit.contain)),
          ),
        ),
      );
}

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => const ColoredBox(color: WellyColors.closedBg),
        errorWidget: (_, _, _) => const _PhotoPlaceholder(),
      );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: WellyColors.closedBg,
        child: Center(child: Icon(Icons.home_outlined, size: 40, color: WellyColors.muted)),
      );
}
