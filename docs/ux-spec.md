# Spécification UX/UI — WELY

> Plateforme immobilière : consultation et réservation de maisons et d'appartements.
> App mobile Flutter unifiée (acheteur par défaut → vendeur depuis le compte) + site vitrine Nuxt.
> Ce document est la référence design pour l'implémentation. Aucun code applicatif n'est modifié par ce document.

## 1. Identité visuelle

### 1.1 Ton & voix
- **Ton** : professionnel, rassurant, simple, humain. Pas de jargon immobilier inutile.
- **Langue** : français (interface et contenus).
- **Style visuel** : épuré, lumineux, photo-centré (les biens sont au cœur). Beaucoup d'espace blanc, coins arrondis modérés, ombres légères.
- **Principe** : une action principale par écran.

### 1.2 Palette

Couleurs proposées (validation requise — voir §6).

| Rôle | Nom | Hex | Usage |
|---|---|---|---|
| Primaire | Bleu WELY | `#2563EB` | CTA principaux, liens, états actifs |
| Primaire foncé | Bleu 700 | `#1D4ED8` | Hover/pressed |
| Secondaire | Ambre | `#F59E0B` | Mise en avant (favori, réservation en cours), badges |
| Succès | Vert | `#16A34A` | Confirmation, réservation validée |
| Erreur | Rouge | `#DC2626` | Erreurs, suppression |
| Info | Bleu clair | `#0EA5E9` | Info neutre |
| Neutre 900 | `#111827` | Texte principal |
| Neutre 700 | `#374151` | Texte secondaire |
| Neutre 500 | `#6B7280` | Texte tertiaire / placeholders |
| Neutre 200 | `#E5E7EB` | Bordures, séparateurs |
| Neutre 100 | `#F3F4F6` | Fonds de sections |
| Fond | Blanc | `#FFFFFF` | Fond principal |
| Fond sombre (option) | `#0F172A` | Mode sombre — à valider |

### 1.3 Typographie
- **Famille** : Inter (mobile via Google Fonts ; web via Nuxt). Fallback : system-ui, sans-serif.
- **Échelle** (mobile, sp) : H1 28 / H2 22 / H3 18 / Body 16 / Small 14 / Caption 12.
- **Poids** : Regular 400, Medium 500, SemiBold 600, Bold 700.
- **Line-height** : 1.4 pour les titres, 1.5 pour le corps.

### 1.4 Iconographie
- Mobile : Material Symbols (Flutter) — cohérence Material 3.
- Web : FontAwesome (déjà importé dans `app.vue`).
- Style : outline par défaut, filled pour les états actifs (favori).

### 1.5 Espacement & rayons
- Grille 8px. Rayons : boutons/champs 8px, cartes 12px, modales 16px. Ombre légère `0 2px 8px rgba(0,0,0,0.08)`.

---

## 2. Navigation mobile (Flutter)

### 2.1 Structure globale
- **Bottom navigation bar** à 4 onglets (Material 3 NavigationBar) :
  1. **Accueil / Recherche** (icône search)
  2. **Favoris** (icône favorite)
  3. **Réservations** (icône calendar_today)
  4. **Compte** (icône person)
- L'onglet actif est mis en évidence (filled icon + label).
- Le rôle vendeur n'ajoute **pas** d'onglet dédié : il se greffe sur "Compte" et sur une entrée "Mes annonces" accessible depuis le compte (et depuis l'accueil via un raccourci "Publier un bien").

### 2.2 Écrans acheteur
| Écran | Description |
|---|---|
| **Recherche** | Barre de recherche (ville), filtres (prix min/max, type bien, pièces, surface), liste de cartes de biens + vue carte (toggle). Pagination infinie. |
| **Fiche bien** | Galerie photos, titre, prix, localisation, caractéristiques, description, carte, CTA "Réserver" + "Ajouter aux favoris". |
| **Favoris** | Grille/liste des biens favoris, suppression par swipe. |
| **Réservations** | Liste des réservations de l'utilisateur (statut : en attente / confirmée / refusée / annulée). Détail + annulation. |
| **Compte** | Profil, bascule "Devenir vendeur", paramètres, déconnexion. |

### 2.3 Écrans vendeur (activés depuis le compte)
| Écran | Description |
|---|---|
| **Mes annonces** | Liste des biens publiés par le vendeur avec statut (actif / en attente / loué/vendu). Actions : modifier, supprimer, voir demandes. |
| **Créer / modifier un bien** | Formulaire multi-étapes : infos générales → caractéristiques → photos → localisation → récapitulatif. |
| **Demandes de réservation** | Liste des demandes reçues par bien, avec accepter / refuser + message. |

### 2.4 Navigation & transitions
- Push pour les détails, modal bottom sheet pour les filtres et la confirmation de réservation.
- Retour via AppBar back button + geste swipe-back (iOS).
- Deep links : `/biens/{id}` ouvre la fiche bien (à valider avec le backend).

---

## 3. Navigation site vitrine (Nuxt)

### 3.1 Header
- Logo WELY à gauche.
- Menu desktop : Accueil, Fonctionnement, Télécharger, Contact/FAQ.
- CTA "Télécharger l'app" à droite (bouton primaire).
- Menu mobile : hamburger → drawer.
- Header sticky avec ombre légère au scroll.

### 3.2 Pages
| Page | Contenu |
|---|---|
| **Accueil** | Hero (titre + sous-titre + CTA téléchargement), présentation acheteur/vendeur, fonctionnalités clés, témoignages (option), CTA final. |
| **Fonctionnement** | Étapes acheteur (recherche → fiche → réservation) et vendeur (devenir vendeur → publier → gérer demandes). |
| **Téléchargement** | Badges App Store / Google Play, QR code, captures d'écran. |
| **Contact / FAQ** | Formulaire de contact, liste de questions fréquentes (accordéon). |

### 3.3 Footer
- Logo + description courte.
- Liens : Accueil, Fonctionnement, Télécharger, Contact, Mentions légales, Politique de confidentialité.
- Réseaux sociaux (icônes), copyright.

---

## 4. Composants clés & états

### 4.1 Carte de bien (PropertyCard)
- Image principale (ratio 4:3), badge type (vente/location), prix en surbrillance, titre, ville, caractéristiques (surface, pièces), icône favori (toggle).
- États : chargement (skeleton), erreur image (placeholder), favori animé.

### 4.2 Liste de biens (PropertyList)
- États :
  - **Loading** : 6 skeletons.
  - **Empty** : illustration + texte "Aucun bien trouvé" + bouton "Réinitialiser les filtres".
  - **Error** : icône + message + bouton "Réessayer".
  - **Success** : liste + pagination / infinite scroll.

### 4.3 Formulaires (recherche, création bien, contact, auth)
- Champs avec label flottant, aide sous le champ, erreur en rouge sous le champ.
- Validation : à la perte de focus + à la soumission.
- Bouton de soumission désactivé tant que le formulaire est invalide ; spinner pendant l'envoi.
- États : idle / submitting (loading) / success (toast) / error (message global + champ).

### 4.4 Galerie photos
- Carrousel avec indicateurs (points), zoom (pinch), fallback placeholder.

### 4.5 Modales / bottom sheets
- Confirmation de réservation (récap + bouton confirmer).
- Filtres de recherche.
- Fermeture par swipe-down ou bouton ✕.

### 4.6 Toasts / snackbars
- Succès (vert), erreur (rouge), info (bleu). Durée 3s, action "Annuler" si applicable.

---

## 5. Accessibilité (base)

- Contraste texte/fond ≥ 4.5:1 (WCAG AA) pour le texte normal.
- Cibles tactiles ≥ 48×48 dp (mobile).
- Labels sémantiques sur tous les contrôles interactifs (aria-label / Semantics).
- Navigation clavier complète sur le web (focus visible, ordre logique).
- Textes alternatifs sur les images de biens.
- Ne pas transmettre l'information uniquement par la couleur (icône + texte pour les statuts).
- Support du mode sombre : à valider (palette sombre proposée §1.2).
- Respect de `prefers-reduced-motion` pour les animations.

---

## 6. Décisions nécessitant validation

1. **Palette de couleurs** : bleu `#2563EB` + ambre `#F59E0B` proposés — à valider par le client.
2. **Mode sombre** : palette sombre proposée mais non validée ; activer ou non.
3. **Typographie Inter** : licence/usage web OK (Google Fonts), à confirmer côté Flutter (package `google_fonts`).
4. **Deep links** `/biens/{id}` : dépend du backend/routing NestJS.
5. **Témoignages** sur l'accueil : contenu à fournir.
6. **Mentions légales / politique de confidentialité** : textes à rédiger (hors scope UX).
7. **Onglet "Carte" dans la recherche** : vue carte proposée en toggle ; à valider (coût Google Maps).
8. **Bascule de rôle vendeur** : confirmation modale lors du passage acheteur→vendeur ? (proposé : oui, avec explication).
9. **Pagination vs infinite scroll** sur les listes : proposé infinite scroll mobile, pagination web.
10. **Icônes** : Material Symbols (mobile) vs FontAwesome (web) — acceptable ou uniformiser ?

---

## 7. Hors scope
- Implémentation code, backend, authentification (Neon), stockage images.
- Tests, CI/CD, déploiement.
- Localisation (i18n) : français uniquement à ce stade.
