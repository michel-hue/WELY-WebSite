// Contenus éditoriaux du site vitrine, regroupés ici pour être modifiés facilement.
import type { Role } from '~/composables/useRole'

export const roleCopy: Record<Role, { label: string; pitch: string }> = {
  buyer: {
    label: 'Je cherche',
    pitch: 'Parcourez les annonces, filtrez selon vos envies et réservez en quelques gestes.'
  },
  seller: {
    label: 'Je propose',
    pitch: 'Passez en mode vendeur depuis votre compte et publiez votre bien en quelques minutes.'
  }
}

export type StepIcon = 'search' | 'house' | 'calendar' | 'switch' | 'camera' | 'inbox'

export const steps: Record<Role, { icon: StepIcon; title: string; text: string }[]> = {
  buyer: [
    { icon: 'search', title: 'Recherchez', text: 'Ville, quartier, prix, nombre de pièces : affinez en un instant.' },
    { icon: 'house', title: 'Découvrez', text: 'Photos, description et localisation de chaque bien, au même endroit.' },
    { icon: 'calendar', title: 'Réservez', text: 'Envoyez votre demande et suivez-la directement depuis l’app.' }
  ],
  seller: [
    { icon: 'switch', title: 'Activez le mode vendeur', text: 'Depuis votre compte, sans créer de second profil.' },
    { icon: 'camera', title: 'Publiez votre bien', text: 'Ajoutez photos, description et prix en quelques minutes.' },
    { icon: 'inbox', title: 'Gérez les demandes', text: 'Acceptez les réservations et suivez vos annonces.' }
  ]
}

// Annonces d'EXEMPLE (photos d'illustration Unsplash, prix indicatifs).
export const examples = [
  { img: '/images/villa-contemporaine.webp', title: 'Villa contemporaine', place: 'Cocody, Angré', meta: '5 pièces · jardin', price: '650 000', unit: 'FCFA / mois' },
  { img: '/images/appartement-lumineux.webp', title: 'Appartement lumineux', place: 'Riviera Palmeraie', meta: '3 pièces · balcon', price: '350 000', unit: 'FCFA / mois' },
  { img: '/images/chambre.webp', title: 'Studio meublé', place: 'Marcory, Zone 4', meta: '1 pièce · meublé', price: '25 000', unit: 'FCFA / nuit' },
  { img: '/images/maison-jardin.webp', title: 'Maison familiale', place: 'Bingerville', meta: '4 pièces · terrasse', price: '400 000', unit: 'FCFA / mois' },
  { img: '/images/villa-piscine.webp', title: 'Maison de vacances', place: 'Assinie', meta: '3 pièces · piscine', price: '90 000', unit: 'FCFA / nuit' }
]

export const promises = [
  { big: '1', small: 'seul compte, acheteur et vendeur' },
  { big: '3', small: 'gestes pour réserver' },
  { big: 'iOS', small: '& Android, une seule app' },
  { big: 'FCFA', small: 'des prix affichés en monnaie locale' }
]

export const faq = [
  {
    q: 'Faut-il deux comptes pour chercher et pour proposer un bien ?',
    a: 'Non. Tout le monde commence en mode acheteur. Vous pouvez passer en mode vendeur à tout moment depuis votre compte, avec le même identifiant.'
  },
  {
    q: 'Comment se passe une réservation ?',
    a: 'Depuis la fiche d’un bien, vous envoyez une demande de réservation. Le propriétaire l’accepte ou la refuse, et vous suivez son état dans l’onglet « Mes réservations ».'
  },
  {
    q: 'Comment publier mon bien ?',
    a: 'Activez le mode vendeur, puis créez une annonce : photos, description, localisation et prix. Vous pouvez la modifier ou la retirer quand vous le souhaitez.'
  },
  {
    q: 'Sur quels téléphones l’application fonctionne-t-elle ?',
    a: 'WELLY est disponible sur iPhone (iOS) et sur Android, avec la même application et les mêmes fonctionnalités.'
  },
  {
    q: 'Puis-je réserver depuis le site web ?',
    a: 'Non, le site présente le projet. La recherche, la réservation et la publication se font dans l’application mobile.'
  }
]

// Liens des stores : à renseigner quand l'app sera publiée.
export const storeLinks = {
  appStore: '#',
  googlePlay: '#'
}
