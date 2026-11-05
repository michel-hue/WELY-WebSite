import '../features/listings/models.dart' show OfferType;

const propertyTypeLabels = {
  'house': 'Maison',
  'villa': 'Villa',
  'apartment': 'Appartement',
  'studio': 'Studio',
  'room': 'Chambre',
  'land': 'Terrain',
  'other': 'Autre',
};

const amenityLabels = {
  'furnished': 'Meublé',
  'air_conditioning': 'Climatisation',
  'parking': 'Parking',
  'pool': 'Piscine',
  'generator': 'Groupe électrogène',
  'security': 'Sécurité',
  'wifi': 'Wi-Fi',
  'water_tank': 'Citerne d’eau',
  'garden': 'Jardin',
  'balcony': 'Balcon',
};

const listingStatusLabels = {
  'draft': 'Brouillon',
  'online': 'En ligne',
  'expired': 'Expirée',
  'deactivated': 'Désactivée',
  'closed': 'Clôturée',
};

const closedReasonLabels = {'rented': 'Louée', 'sold': 'Vendue'};

const requestStatusLabels = {
  'pending': 'En attente',
  'accepted': 'Acceptée',
  'refused': 'Refusée',
  'cancelled': 'Annulée',
};

const refusalReasonLabels = {
  'seller': 'Le vendeur a décliné',
  'dates_unavailable': 'Dates indisponibles',
  'listing_unavailable': 'Annonce indisponible',
};

const reportReasonLabels = {
  'scam': 'Arnaque',
  'misleading_price': 'Prix trompeur',
  'misleading_photos': 'Photos trompeuses',
  'unavailable': 'Bien indisponible',
  'other': 'Autre',
};

String labelOf(Map<String, String> labels, String key) => labels[key] ?? key;

String offerTypeLabel(OfferType t) => switch (t) {
      OfferType.monthly => 'Au mois',
      OfferType.nightly => 'À la nuit',
      OfferType.sale => 'À vendre',
    };
