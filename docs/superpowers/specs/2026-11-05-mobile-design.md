# WELLY — App mobile (refonte) : document de conception

Date : 2026-11-05 · Projet : `mobile_project/` (Flutter) · Back-end : l'API `api_project/` (branche `api-refonte`, spec `docs/superpowers/specs/2026-11-04-api-design.md`).

## 1. Intention

L'app est le produit WELLY : elle met en relation des personnes qui cherchent un logement en Côte d'Ivoire et celles qui en proposent. Le site vitrine pousse à la télécharger ; l'app doit tenir la même promesse de design — **fine, moderne, douce, jamais agressive** — mais sur **fond clair** (choix de l'utilisateur, à l'inverse du site sombre).

Ce qui compte pour l'utilisateur : on arrive, on voit tout de suite les logements autour de soi, sans compte ; on contacte le vendeur sur WhatsApp en un toucher ; une demande se fait en un seul panneau ; et n'importe qui peut devenir vendeur à tout moment.

Le code actuel de `lib/` (itération 1 : email/mot de passe, réservations, palette bleue) est **remplacé entièrement**. `docs/ux-spec.md` (palette bleue) est obsolète pour le visuel.

## 2. Parcours (décidés avec l'utilisateur, voir aussi la spec API §2)

1. **Acheteur sans compte** : ouverture → carte des logements proches → recherche + filtres → fiche → WhatsApp. Aucun compte.
2. **Demande** : sur la fiche, « Faire une demande » → un panneau (offre, dates, message) ; si non connecté, nom + numéro puis code SMS **dans le même panneau** → compte créé, demande envoyée. Pas de mot de passe.
3. **Vendeur** : depuis Profil, bascule Acheteur / Vendeur (compte requis, même parcours numéro + code) → espace vendeur : publier, gérer, traiter les demandes.
4. **Signalement** : depuis la fiche ; l'annonce disparaît seulement pour celui qui signale.

## 3. Identité visuelle (validée sur maquettes)

Maquettes de référence : `.superpowers/brainstorm/7718-1793874114/content/` — `accueil-c-variantes.html` (**C3** retenue), `ecrans-cles.html` (fiche, demande, espace vendeur), `fiche-boutons.html` (**3 · capsule** retenue).

- **Logo** : pastille maison « C » (maison pleine, W évidé) en SVG — même tracé que `dev-project/components/WellyLogo.vue` ; sur fond clair : maison `#13161B`, W `#F6F3EE`. Icône d'app et écran de démarrage dérivés de ce logo.
- **Couleurs** :
  - fond ivoire `#F6F3EE` ; surfaces (cartes, champs) `#FFFFFF` ; traits `#E6E0D6` / `#EEE8DE` ;
  - encre `#13161B` (texte, boutons principaux sombres) ; texte secondaire `#6B6F76` ;
  - laiton `#C2A25F` (accent, bouton de demande, onglet actif, pastilles de carte) ; laiton texte `#9C7F3C` ; laiton doux `#F3EBDA` (puce d'offre active) ;
  - états : en ligne `#1F7A45` sur `#E3F1E7` ; expirée `#9A5A1C` sur `#F6E7D8` ; close/désactivée `#6B6F76` sur `#ECEAE6` ; WhatsApp `#1F9D55`.
- **Typographie** : Inter 300 (texte), 400/500 (titres courts, prix, boutons) ; **Instrument Serif italique** pour un mot d'accent dans les titres (« Villa avec *piscine* », « Mes *annonces* », « Votre *demande* »). Polices embarquées dans l'app (pas de téléchargement au lancement).
- **Formes** : cartes arrondies 18–20 px, panneaux 24 px en haut, pilules 999 px ; ombres très douces ; beaucoup d'air.
- **Mouvement** : transitions courtes et douces (fondu/glissement), panneaux qui suivent le doigt. Rien de clignotant.
- Fond clair uniquement (pas de mode sombre pour l'instant).

## 4. Écrans

Navigation : barre d'onglets en bas — **Explorer · Favoris · Demandes · Profil** (onglet actif : icône laiton).

### 4.1 Démarrage
Écran de lancement : logo sur ivoire, fondu doux vers Explorer. Au premier lancement, un écran calme explique pourquoi on demande la position (« pour vous montrer les logements autour de vous ») avant la demande système. Refus ou position indisponible : carte centrée sur Abidjan, avec un petit lien « Activer la position ».

### 4.2 Explorer (C3)
- Carte plein écran, style clair et calme ; les annonces sont des **pastilles laiton** placées à une **position approximative** (quartier, jamais le point exact — voir §8), **regroupées** (cercle laiton avec le nombre) quand elles sont proches ; point bleu pour l'utilisateur ; bouton « recentrer ».
- En haut, flottante : barre de recherche (texte libre : quartier, ville, type) + bouton filtres.
- En bas : panneau « *Autour de vous* » à hauteur ajustable (replié / mi-hauteur / plein écran) avec de **grandes cartes photo** (photo, puce d'offre, favori ♡, titre, quartier + distance, prix). Un bouton **Carte / Liste** bascule en liste plein écran.
- Toucher une pastille met son annonce en tête du panneau ; toucher un groupe zoome.
- Déplacer la carte propose « Rechercher dans cette zone » (recherche par rayon autour du centre de la carte ; on affiche les 50 plus proches, suffisant au lancement).
- Filtres (panneau) : type d'offre (au mois / à la nuit / à vendre), type de bien, prix min–max (selon l'offre), pièces / chambres minimum, équipements, dates pour la nuit ; tri (distance, récentes, prix ↑, prix ↓). Nombre de filtres actifs affiché sur le bouton.
- États vides / erreurs : messages courts et doux (« Aucun logement ici pour l'instant — élargissez la zone »), bouton réessayer hors connexion.

### 4.3 Fiche du logement
- Galerie photo en haut (balayage, compteur « 1 / 8 », plein écran au toucher) ; boutons ronds blancs : retour, partager, favori.
- Contenu sur panneau ivoire arrondi : puces des offres disponibles (l'offre choisie en laiton doux, change le prix affiché), titre avec mot en serif, quartier + distance, prix, chiffres clés (pièces, chambres, salles de bain, m²), équipements, description, petite carte du point exact, carte vendeur (nom, photo/initiale, « membre depuis », nombre d'annonces), lien discret « Signaler ».
- **Actions : capsule sombre flottante** en bas (pas de barre blanche) : à gauche « WhatsApp » (icône + texte clair), à droite « Faire une demande » sur fond laiton. Toujours visible.
- WhatsApp : ouvre `wa.me/<numéro>` avec le message pré-rempli de la spec API §7.5 et signale le clic à l'API. Si WhatsApp n'est pas installé : proposer l'appel.
- Sa propre annonce : la capsule devient « Gérer l'annonce ».
- Signaler : panneau avec les motifs (spec API §7.7) ; après envoi, retour à Explorer et l'annonce n'apparaît plus.

### 4.4 Panneau de demande
Un seul panneau qui monte du bas, au-dessus de la fiche assombrie (titre « Votre *demande* ») :
- offre visée (puces) ; pour la nuit : arrivée et départ (calendrier, nuits bloquées grisées si l'API les fournit, minimum de nuits respecté) ; pour le mois : date d'emménagement (facultative) ; message (facultatif) ; « Je souhaite visiter » (oui/non) ;
- si non connecté : nom + téléphone (+225 par défaut), mention « Votre nom et votre numéro seront transmis au vendeur », puis les 6 cases du code SMS **dans le même panneau** (lecture automatique du SMS si possible, renvoi après 60 s) ;
- bouton « Envoyer ma demande ». Confirmation douce, puis la demande apparaît dans l'onglet Demandes.
- Erreurs de l'API (dates indisponibles, demande déjà en attente…) affichées en clair sous le champ concerné.

### 4.5 Favoris
Grille de cartes photo. Sans compte : gardés sur le téléphone ; à la connexion, fusionnés avec le compte (spec API §7.6). Sans compte, une annonce devenue indisponible apparaît grisée « plus disponible » ; avec compte, l'API ne renvoie que les favoris encore disponibles, elle disparaît simplement.

### 4.6 Demandes
- Acheteur : mes demandes avec état (en attente, acceptée, refusée + motif, annulée), annuler une demande en attente, lien vers la fiche, WhatsApp vers le vendeur.
- En mode vendeur : deux segments **Reçues / Envoyées**. Reçues : nom et numéro de l'acheteur, offre et dates, boutons appeler / WhatsApp / accepter / refuser (message facultatif). Après acceptation d'une demande au mois ou à la vente : proposer « Marquer comme loué / vendu ? ».
- Sans compte : invitation douce à se connecter.

### 4.7 Profil
- Sans compte : « Se connecter » (numéro + code, nom si nouveau), et l'entrée « Proposer un logement » qui mène au même parcours.
- Connecté : nom et numéro WhatsApp (modifiables), avatar à l'initiale (pas de photo de profil pour l'instant : l'API n'a pas d'envoi de photo de profil) ; bascule **Acheteur / Vendeur** ; notifications ; à propos ; se déconnecter ; supprimer mon compte (confirmation explicite).
- En mode vendeur, le Profil affiche l'**espace vendeur** (maquette `ecrans-cles.html` n° 3) : titre « Mes *annonces* », deux chiffres clés (demandes en attente, vues totales de ses annonces — l'API ne compte pas par semaine), liste des annonces avec leur état (en ligne, brouillon, expirée, désactivée, close), raccourci « Réactiver » sur une expirée, bouton laiton « + » pour publier.

### 4.8 Créer / modifier une annonce
Parcours en étapes courtes avec progression visible, brouillon enregistré à chaque étape :
1. Le bien (type, titre, pièces, chambres, salles de bain, surface, équipements, description) ;
2. Où (ville, quartier, adresse facultative, **épingle à placer sur la carte**) — le brouillon est créé dans l'API à la fin de cette étape ;
3. Photos (galerie ou appareil, jusqu'à 15, réordonner, choisir la couverture) — l'API exige une annonce existante pour recevoir des photos ;
4. Offres (au mois / à la nuit / vente — au moins une — avec prix et compléments) ;
5. Publication (jusqu'à une date, ou permanente) → « Publier ».
Gestion d'une annonce : modifier, prolonger (en ligne), désactiver, marquer louée/vendue, réactiver (nouvelle date ou permanente), supprimer ; compteurs (vues, clics WhatsApp, demandes).

### 4.9 Notifications
Liste (lue / non lue, pastille sur l'onglet Profil) ; notifications push qui ouvrent l'écran concerné.

## 5. Objectifs
- Les 4 parcours du §2 de bout en bout contre l'API réelle.
- Fidélité aux maquettes validées et à l'identité du §3.
- Fluide sur Android d'entrée de gamme (cible principale en Côte d'Ivoire) et sur iOS.
- Sobre en données : vignettes dans les listes, grandes images seulement sur la fiche, cache des images.

## 6. Non-objectifs
- Paiement, messagerie interne, administration (comme l'API).
- Mode sombre, anglais, tablette optimisée, mode hors ligne complet.
- Publication sur les stores (préparée mais pas faite dans cette refonte).

## 7. Anti-objectifs
- Exiger un compte pour consulter, filtrer ou ouvrir WhatsApp.
- Plus d'un panneau pour envoyer une première demande ; un mot de passe.
- Une interface chargée, criarde ou « agressive » : couleurs vives hors laiton/WhatsApp, bannières, pop-ups au lancement.
- Revenir au fond sombre ou à l'ancienne palette bleue.

## 8. Contraintes
- Flutter stable installé (3.47), Android + iOS. Textes en français, montants en FCFA (`650 000 F`), dates à la française.
- Contrat : l'API `v1` (routes, erreurs `{ error: { code, message, details } }`, pagination `{ data, nextCursor }`, en-tête `X-Installation-Id`, jeton d'accès 15 min + jeton de rafraîchissement renouvelé). L'API ne doit pas être modifiée sauf manque bloquant. Deux manques bloquants sont identifiés et font partie de cette refonte :
  - **position approximative sur les cartes d'annonce** (`GET /v1/listings`) pour placer les pastilles : coordonnées arrondies/décalées à l'échelle du quartier (~500 m), jamais le point exact ;
  - **coordonnées du vendeur dans les demandes de l'acheteur** (nom, téléphone, WhatsApp) pour le recontacter même après la clôture de l'annonce.
- Calendrier des nuits bloquées : l'API ne les expose pas ; l'app gère l'erreur « dates indisponibles » au moment de l'envoi.
- URL de l'API configurable à la compilation (dev : API locale ; l'émulateur Android joint l'hôte via `10.0.2.2`).
- `mobile_project/` n'est pas encore suivi par git (décision de l'utilisateur, voir §10).

## 9. Laissé au builder
- Architecture interne, gestion d'état, navigation, client HTTP, bibliothèques (carte, regroupement des pastilles, stockage sécurisé, sélection d'images, liens WhatsApp).
- Fournisseur des tuiles de carte, tant que le rendu est clair et calme comme les maquettes.
- Stratégie de tests (au minimum : `flutter analyze` propre, tests unitaires du client API/sessions, tests de widgets des écrans principaux).
- Icônes (fines, cohérentes avec Inter light).

## 10. Choix faits par Claude (à vérifier)
- Les 4 onglets Explorer / Favoris / Demandes / Profil, l'espace vendeur logé dans Profil (comme la maquette).
- Écran d'explication avant la demande de position ; repli sur Abidjan.
- Brouillon d'annonce enregistré à chaque étape.
- Notifications push via Firebase : branchées mais inactives tant que le projet Firebase n'est pas créé par l'utilisateur ; la liste dans l'app fonctionne sans.
- Pas de mode sombre.
- Pastilles de carte à position approximative (~500 m), cohérent avec « quartier dans les listes » de la spec API.
- Ordre du parcours de publication : le bien → où → photos → offres → publication.
- Pas de photo de profil ni de « vues de la semaine » (absents de l'API) : avatar à l'initiale, vues totales.
- `mobile_project/` sera ajouté à git sur une branche dédiée (`mobile-refonte`) — à confirmer.
