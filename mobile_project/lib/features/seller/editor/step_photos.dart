import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/serif_title.dart';
import '../../../core/widgets/soft_banner.dart';
import 'editor_controller.dart';
import 'editor_widgets.dart';

/// Sélection d'images (remplaçable dans les tests).
class PhotoPicker {
  final _picker = ImagePicker();

  /// Images réduites côté appareil : l'API refuse plus de 8 Mo par photo.
  static const _maxSide = 2400.0;
  static const _quality = 85;

  Future<List<XFile>> pick({required bool camera, required int limit}) async {
    if (limit <= 0) return const [];
    if (camera || limit == 1) {
      final one = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      return one == null ? const [] : [one];
    }
    final many = await _picker.pickMultiImage(
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      limit: limit,
    );
    return many.length > limit ? many.sublist(0, limit) : many;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => PhotoPicker());

/// Étape 3 : jusqu'à 15 photos, envoyées une à une ; glisser pour réordonner,
/// la première sert de couverture.
class StepPhotos extends ConsumerWidget {
  const StepPhotos({super.key, required this.c});
  final EditorController c;

  Future<void> _pick(BuildContext context, WidgetRef ref, {required bool camera}) async {
    List<XFile> files;
    try {
      files = await ref.read(photoPickerProvider).pick(camera: camera, limit: c.remainingPhotos);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Accès aux photos impossible. Vérifiez les autorisations de l’app.'),
        ));
      }
      return;
    }
    if (files.isEmpty) return;
    await c.addPhotos(files);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploaded = c.photos.where((p) => p.isUploaded).toList();
    final pending = c.photos.where((p) => !p.isUploaded).toList();
    final full = c.remainingPhotos <= 0;

    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SerifTitle('Vos ', 'photos', size: 26),
      const SizedBox(height: 4),
      EditorHint('Jusqu’à ${EditorController.maxPhotos} photos. La première sert de couverture : '
          'maintenez une photo puis faites-la glisser pour changer l’ordre.'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('pick-gallery'),
            onPressed: full ? null : () => _pick(context, ref, camera: false),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Galerie'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: full ? null : () => _pick(context, ref, camera: true),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Appareil photo'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text('${c.photos.length} / ${EditorController.maxPhotos}',
          textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: WellyColors.muted)),
      if (c.photosNotice != null) ...[const SizedBox(height: 8), SoftBanner(c.photosNotice!)],
      if (c.fieldErrors['photos'] != null) FieldErrorText(c.fieldErrors['photos']!),
      const SizedBox(height: 8),
    ]);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      buildDefaultDragHandles: false,
      header: header,
      footer: Column(children: [
        for (final p in pending) _PendingTile(key: ObjectKey(p), p: p, c: c),
      ]),
      itemCount: uploaded.length,
      onReorderItem: c.reorderPhotos,
      itemBuilder: (context, i) {
        final p = uploaded[i];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(p.photo!.id),
          index: i,
          child: _PhotoTile(
            leading: CachedNetworkImage(
              imageUrl: p.photo!.thumbUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: WellyColors.closedBg),
              errorWidget: (_, _, _) => const ColoredBox(color: WellyColors.closedBg),
            ),
            title: i == 0
                ? const _CoverBadge()
                : Text('Photo ${i + 1}', style: const TextStyle(fontSize: 13.5, color: WellyColors.ink)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Retirer',
                onPressed: () => c.removePhoto(p),
                icon: const Icon(Icons.close, size: 20, color: WellyColors.muted),
              ),
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, color: WellyColors.muted),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: WellyColors.laitonSoft, borderRadius: BorderRadius.circular(999)),
          child: const Text('Couverture',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: WellyColors.laitonText)),
        ),
      );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.leading, required this.title, required this.trailing});
  final Widget leading;
  final Widget title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: WellyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WellyRadii.card),
            side: const BorderSide(color: WellyColors.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 72, height: 54, child: leading),
              ),
              const SizedBox(width: 12),
              Expanded(child: title),
              trailing,
            ]),
          ),
        ),
      );
}

/// Photo en cours d'envoi (barre de progression) ou en échec (« Réessayer »).
class _PendingTile extends StatefulWidget {
  const _PendingTile({super.key, required this.p, required this.c});
  final EditorPhoto p;
  final EditorController c;

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  late final Future<Uint8List?> _bytes = widget.p.file!.readAsBytes().then<Uint8List?>((b) => b, onError: (_) => null);

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return _PhotoTile(
      leading: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (_, snap) => snap.data == null
            ? const ColoredBox(color: WellyColors.closedBg)
            : Image.memory(snap.data!,
                fit: BoxFit.cover,
                cacheWidth: 216,
                errorBuilder: (_, _, _) => const ColoredBox(color: WellyColors.closedBg)),
      ),
      title: p.failed
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Échec de l’envoi', style: TextStyle(fontSize: 13.5, color: WellyColors.expired)),
              Text(p.uploadError!.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: WellyColors.muted)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.uploading ? 'Envoi… ${(p.progress * 100).round()} %' : 'En attente',
                  style: const TextStyle(fontSize: 13, color: WellyColors.muted)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: p.uploading ? p.progress : 0,
                  minHeight: 4,
                  color: WellyColors.laiton,
                  backgroundColor: WellyColors.laitonSoft,
                ),
              ),
            ]),
      trailing: p.failed
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => widget.c.retryPhoto(p), child: const Text('Réessayer')),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () => widget.c.removePhoto(p),
                icon: const Icon(Icons.close, size: 20, color: WellyColors.muted),
              ),
            ])
          : const SizedBox(width: 8),
    );
  }
}
