import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_error.dart';
import '../../listings/models.dart';
import '../../requests/models.dart' show isoDay;
import '../seller_listings_repository.dart';

/// Une photo de l'éditeur : déjà envoyée ([photo]) ou en attente ([file]).
class EditorPhoto {
  EditorPhoto.uploaded(Photo this.photo) : file = null;
  EditorPhoto.pending(XFile this.file);

  Photo? photo;
  final XFile? file;
  bool uploading = false;

  /// 0 → 1 pendant l'envoi.
  double progress = 0;
  ApiError? uploadError;

  bool get isUploaded => photo != null;
  bool get failed => uploadError != null;
}

/// Parcours de création / modification d'une annonce (spec §4.8).
///
/// Étapes : 0 Le bien → 1 Où (brouillon créé à la fin) → 2 Photos → 3 Offres
/// → 4 Publication (brouillons seulement). Chaque étape après la création
/// enregistre avec `update` ; une erreur d'API reste affichée sur place.
class EditorController extends ChangeNotifier {
  EditorController(this._repo, {this.listingId});

  final SellerListingsRepository _repo;

  /// Limite de l'API (`MAX_PHOTOS_PER_LISTING`).
  static const maxPhotos = 15;

  static const stepTitles = ['Le bien', 'Où', 'Photos', 'Offres', 'Publication'];

  String? listingId;
  SellerListing? listing;

  int step = 0;
  bool loading = false;
  ApiError? loadError;
  bool saving = false;
  ApiError? error;
  Map<String, String> fieldErrors = const {};

  /// Annonce publiée (ou modifications enregistrées) : l'écran peut se fermer.
  bool done = false;

  // 1. Le bien
  String? propertyType;
  String title = '';
  String rooms = '';
  String bedrooms = '';
  String bathrooms = '';
  String surface = '';
  Set<String> amenities = {};
  String description = '';

  // 2. Où
  String city = '';
  String district = '';
  String address = '';
  LatLng? location;

  // 3. Photos
  final photos = <EditorPhoto>[];
  String? photosNotice;
  Future<void> _queue = Future<void>.value();

  // 4. Offres
  bool monthlyEnabled = false;
  String monthlyRent = '';
  String monthlyTerms = '';
  bool nightlyEnabled = false;
  String nightlyPrice = '';
  String minNights = '';
  bool saleEnabled = false;
  String salePrice = '';

  // 5. Publication
  bool permanent = true;
  DateTime? until;

  bool _disposed = false;

  bool get isNew => listingId == null;

  /// Seul un brouillon passe par l'étape « Publication ».
  bool get hasPublishStep => listing == null || listing!.status == ListingStatus.draft;
  int get totalSteps => hasPublishStep ? 5 : 4;
  bool get isLastStep => step == totalSteps - 1;

  int get remainingPhotos => maxPhotos - photos.length;
  bool get uploadingPhotos => photos.any((p) => p.uploading || (!p.isUploaded && !p.failed));

  /// Notifie l'écran après une modification d'un champ (puces, interrupteurs…).
  void edit(void Function() change) {
    change();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Charge une annonce existante et préremplit le parcours.
  Future<void> load() async {
    final id = listingId;
    if (id == null) return;
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      _prefill(await _repo.one(id));
    } catch (e) {
      loadError = ApiError.of(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _prefill(SellerListing l) {
    listing = l;
    propertyType = l.propertyType;
    title = l.title;
    rooms = l.rooms == 0 ? '' : '${l.rooms}';
    bedrooms = l.bedrooms?.toString() ?? '';
    bathrooms = l.bathrooms?.toString() ?? '';
    surface = l.surfaceM2?.toString() ?? '';
    amenities = {...l.amenities};
    description = l.description;
    city = l.city;
    district = l.district;
    address = l.address ?? '';
    location = l.location;
    photos
      ..clear()
      ..addAll([for (final p in l.photos) EditorPhoto.uploaded(p)]);
    final o = l.offers;
    monthlyEnabled = o.monthly != null;
    monthlyRent = o.monthly?.rent.toString() ?? '';
    monthlyTerms = o.monthly?.terms ?? '';
    nightlyEnabled = o.nightly != null;
    nightlyPrice = o.nightly?.price.toString() ?? '';
    minNights = o.nightly?.minNights?.toString() ?? '';
    saleEnabled = o.sale != null;
    salePrice = o.sale?.price.toString() ?? '';
    permanent = l.publishedUntil == null;
    until = l.publishedUntil;
  }

  void back() {
    if (step == 0 || saving) return;
    step--;
    error = null;
    fieldErrors = const {};
    notifyListeners();
  }

  /// Valide et enregistre l'étape courante, puis passe à la suivante.
  /// Renvoie `false` si la validation ou l'API échoue (erreur sur place).
  Future<bool> next() async {
    if (saving) return false;
    error = null;
    fieldErrors = validate(step);
    if (fieldErrors.isNotEmpty) {
      notifyListeners();
      return false;
    }
    saving = true;
    notifyListeners();
    try {
      switch (step) {
        case 0:
          if (!isNew) listing = await _repo.update(listingId!, _propertyBody());
        case 1:
          if (isNew) {
            listing = await _repo.create({..._propertyBody(), ..._placeBody(creating: true)});
            listingId = listing!.id;
          } else {
            listing = await _repo.update(listingId!, _placeBody(creating: false));
          }
        case 2:
          break; // les photos sont enregistrées une à une
        case 3:
          listing = await _repo.update(listingId!, {'offers': _offersBody()});
          if (!hasPublishStep) done = true;
        case 4:
          listing = await _repo.publish(listingId!, until: permanent ? null : isoDay(until!));
          done = true;
      }
      if (!done) step++;
      return true;
    } catch (e) {
      final err = ApiError.of(e);
      error = err;
      fieldErrors = {for (final d in err.details) d.field: d.message};
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  // ---------- Validation ----------

  static int? parseInt(String s) => int.tryParse(s.replaceAll(RegExp(r'[\s  ]'), ''));

  Map<String, String> validate(int s) {
    final e = <String, String>{};
    void positive(String key, String value, {bool required = false, int min = 0}) {
      if (value.trim().isEmpty) {
        if (required) e[key] = 'Indiquez un montant.';
        return;
      }
      final n = parseInt(value);
      if (n == null || n < min) e[key] = min > 0 ? 'Nombre supérieur à 0 attendu.' : 'Nombre attendu.';
    }

    switch (s) {
      case 0:
        if (propertyType == null) e['propertyType'] = 'Choisissez le type de bien.';
        final t = title.trim().length;
        if (t < 3 || t > 120) e['title'] = 'Entre 3 et 120 caractères.';
        positive('rooms', rooms);
        positive('bedrooms', bedrooms);
        positive('bathrooms', bathrooms);
        positive('surfaceM2', surface, min: 1);
      case 1:
        final c = city.trim().length;
        if (c < 2 || c > 80) e['city'] = 'Indiquez la ville.';
        final d = district.trim().length;
        if (d < 2 || d > 120) e['district'] = 'Indiquez le quartier.';
        if (address.trim().length > 200) e['address'] = '200 caractères au maximum.';
        if (location == null) e['location'] = 'Placez l’épingle sur la carte.';
      case 2:
        if (uploadingPhotos) {
          e['photos'] = 'Patientez pendant l’envoi des photos.';
        } else if (!photos.any((p) => p.isUploaded)) {
          e['photos'] = 'Ajoutez au moins une photo.';
        }
      case 3:
        if (!monthlyEnabled && !nightlyEnabled && !saleEnabled) {
          e['offers'] = 'Choisissez au moins une offre : au mois, à la nuit ou à la vente.';
        }
        if (monthlyEnabled) positive('offers.monthly.rent', monthlyRent, required: true, min: 1);
        if (monthlyEnabled && monthlyTerms.trim().length > 300) e['offers.monthly.terms'] = '300 caractères au maximum.';
        if (nightlyEnabled) {
          positive('offers.nightly.price', nightlyPrice, required: true, min: 1);
          positive('offers.nightly.minNights', minNights, min: 1);
        }
        if (saleEnabled) positive('offers.sale.price', salePrice, required: true, min: 1);
      case 4:
        if (!permanent && until == null) e['until'] = 'Choisissez une date de fin.';
    }
    return e;
  }

  // ---------- Corps des requêtes ----------

  Map<String, dynamic> _propertyBody() => {
        'propertyType': propertyType,
        'title': title.trim(),
        'rooms': parseInt(rooms) ?? 0,
        'bedrooms': parseInt(bedrooms),
        'bathrooms': parseInt(bathrooms),
        'surfaceM2': parseInt(surface),
        'amenities': amenities.toList(),
        'description': description.trim(),
      }..removeWhere((k, v) => v == null && isNew);

  Map<String, dynamic> _placeBody({required bool creating}) {
    final a = address.trim();
    return {
      'city': city.trim(),
      'district': district.trim(),
      if (a.isNotEmpty) 'address': a else if (!creating) 'address': null,
      'location': {'lat': location!.latitude, 'lng': location!.longitude},
    };
  }

  Map<String, dynamic> _offersBody() {
    final terms = monthlyTerms.trim();
    return {
      'monthly': monthlyEnabled ? {'rent': parseInt(monthlyRent), if (terms.isNotEmpty) 'terms': terms} : null,
      'nightly': nightlyEnabled
          ? {'price': parseInt(nightlyPrice), if (parseInt(minNights) != null) 'minNights': parseInt(minNights)}
          : null,
      'sale': saleEnabled ? {'price': parseInt(salePrice)} : null,
    };
  }

  // ---------- Photos ----------

  /// Ajoute des photos (au plus [remainingPhotos]) et les envoie une à une.
  Future<void> addPhotos(List<XFile> files) {
    final room = remainingPhotos;
    photosNotice = files.length > room ? 'Une annonce peut contenir $maxPhotos photos au maximum.' : null;
    photos.addAll([for (final f in files.take(room < 0 ? 0 : room)) EditorPhoto.pending(f)]);
    if (fieldErrors.containsKey('photos')) fieldErrors = const {};
    notifyListeners();
    return _schedule();
  }

  Future<void> retryPhoto(EditorPhoto p) {
    p.uploadError = null;
    notifyListeners();
    return _schedule();
  }

  /// Les envois s'enchaînent : un seul à la fois, dans l'ordre d'ajout.
  Future<void> _schedule() => _queue = _queue.then((_) => _drain());

  Future<void> _drain() async {
    while (!_disposed) {
      EditorPhoto? next;
      for (final p in photos) {
        if (!p.isUploaded && !p.failed && !p.uploading) {
          next = p;
          break;
        }
      }
      if (next == null) return;
      await _upload(next);
    }
  }

  Future<void> _upload(EditorPhoto p) async {
    p
      ..uploading = true
      ..progress = 0;
    notifyListeners();
    try {
      final created = await _repo.uploadPhotos(listingId!, [p.file!], onProgress: (sent, total) {
        if (total <= 0) return;
        p.progress = sent / total;
        notifyListeners();
      });
      if (created.isEmpty) throw const ApiError(code: 'ERROR', message: 'Une erreur est survenue.');
      p.photo = created.first;
      // Comme dans l'API : la photo envoyée prend place après les précédentes.
      photos.remove(p);
      var at = 0;
      while (at < photos.length && photos[at].isUploaded) {
        at++;
      }
      photos.insert(at, p);
    } catch (e) {
      p.uploadError = ApiError.of(e);
    } finally {
      p.uploading = false;
      notifyListeners();
    }
  }

  /// Déplace la photo envoyée [from] à la place [to] (0 = couverture).
  Future<void> reorderPhotos(int from, int to) async {
    final uploaded = photos.where((p) => p.isUploaded).toList();
    if (from == to || from < 0 || to < 0 || from >= uploaded.length || to >= uploaded.length) return;
    final before = [...photos];
    final moved = uploaded.removeAt(from);
    uploaded.insert(to, moved);
    photos
      ..clear()
      ..addAll([...uploaded, ...before.where((p) => !p.isUploaded)]);
    error = null;
    notifyListeners();
    try {
      await _repo.reorderPhotos(listingId!, [for (final p in uploaded) p.photo!.id]);
    } catch (e) {
      photos
        ..clear()
        ..addAll(before);
      error = ApiError.of(e);
      notifyListeners();
    }
  }

  Future<void> removePhoto(EditorPhoto p) async {
    if (p.uploading) return;
    if (p.isUploaded) {
      try {
        await _repo.deletePhoto(listingId!, p.photo!.id);
      } catch (e) {
        error = ApiError.of(e);
        notifyListeners();
        return;
      }
    }
    photos.remove(p);
    photosNotice = null;
    notifyListeners();
  }
}
