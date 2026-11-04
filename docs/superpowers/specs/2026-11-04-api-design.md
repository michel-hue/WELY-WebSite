# WELLY — API (refonte) : document de conception

Date : 2026-11-04 · Projet : `api_project/` (NestJS) · Consommateur principal : l'app mobile Flutter (`mobile_project/`, refaite ensuite).

## 1. Intention

WELLY **met en relation** des personnes qui cherchent un logement (acheteurs) et des personnes qui en proposent (vendeurs), en Côte d'Ivoire. L'app ne vend rien et n'encaisse rien : elle aide à trouver un bien, à contacter le vendeur (WhatsApp en priorité) et à formaliser une **demande**. L'API doit rendre ce parcours le plus léger possible côté utilisateur — **on ne force jamais un compte tant que ce n'est pas nécessaire**.

L'utilisateur a demandé de « tout reprendre » : l'API existante (itération 1) sert de point de départ technique, mais son modèle (email/mot de passe, rôle fixé à l'inscription, réservations sans dates, photos sur disque) est remplacé.

## 2. Parcours de référence (décidés avec l'utilisateur)

1. **Acheteur sans compte** : ouvre l'app → voit les biens **proches de sa position** → recherche + filtres → fiche du bien (infos du bien + infos du vendeur) → bouton **WhatsApp** (ouvre la conversation avec le vendeur). Aucun compte requis pour tout cela.
2. **Demande** : sur la fiche, « Faire une demande » → si pas connecté, **petit formulaire** (nom + numéro de téléphone) → **code reçu par SMS ou WhatsApp** → compte créé et connecté → la demande part. **Pas de mot de passe**, jamais.
3. **Vendeur** : à tout moment, un utilisateur peut « passer en mode vendeur ». Il doit alors avoir un compte (même parcours numéro + code). Il arrive dans l'espace vendeur : publier, gérer ses annonces, traiter les demandes.
4. **Signalement** : un acheteur peut signaler une annonce qu'il juge frauduleuse. L'annonce **n'est pas retirée** ; elle est seulement **masquée pour celui qui l'a signalée**.

## 3. Objectifs

- Consultation anonyme rapide : biens proches, recherche texte, filtres, pagination.
- Authentification sans mot de passe par code (OTP) envoyé par SMS ou WhatsApp, session longue durée.
- Un seul compte, deux modes (acheteur / vendeur), bascule à tout moment.
- Annonces combinant **jusqu'à trois offres** : location au mois, location à la nuit, vente — chacune avec son prix.
- Durée de publication : **date de fin** ou **permanente** ; expiration automatique + notification au vendeur ; réactivation possible.
- Demandes (pas de paiement) avec suivi d'état et notifications.
- Mesure de l'intérêt : clics WhatsApp et demandes comptés par annonce.
- Signalements enregistrés.
- **API soignée** (l'utilisateur met l'accent sur le design) : routes cohérentes, réponses et erreurs uniformes, documentation interactive.

## 4. Non-objectifs (pour cette refonte)

- **Aucun paiement**, aucune réservation « ferme » : on met en relation. (Mobile money — Orange Money, MTN MoMo, Wave — pourra venir plus tard.)
- **Pas d'espace d'administration**, pas de modération avant publication : tout est publié directement.
- Pas de messagerie interne : la conversation se fait sur WhatsApp / téléphone.
- Pas de calendrier de disponibilités complet (seules les nuits des demandes de séjour **acceptées** sont bloquées, cf. §7.4).
- Le site vitrine Nuxt n'appelle pas l'API pour l'instant.

## 5. Anti-objectifs (ce qui serait un échec même si ça « marche »)

- Obliger à créer un compte pour **consulter** ou pour **contacter sur WhatsApp**.
- Un mot de passe, ou plus d'un écran de saisie pour envoyer une première demande.
- **Fermer automatiquement** une annonce quand quelqu'un fait une demande : seul le vendeur décide qu'un bien est clos (on ne sait pas si l'affaire s'est conclue).
- Qu'un signalement retire une annonce pour tout le monde.
- Exposer des données personnelles inutiles (le numéro du vendeur est public **par choix** car c'est le cœur de la mise en relation ; rien d'autre).

## 6. Contraintes

- **Stack conservée** : NestJS 12 (ESM, `type: module`), TypeORM, PostgreSQL hébergé sur **Neon**, Vitest, oxlint, Prettier — déjà en place dans `api_project/`.
- **Authentification gérée par l'API** (pas par Neon Auth) — le README racine dit l'inverse et doit être corrigé.
- Langue : messages d'erreur destinés à l'utilisateur en **français**.
- Monnaie : **FCFA (XOF)**, montants entiers.
- Numéros de téléphone : format international E.164 (`+225…`), Côte d'Ivoire par défaut.
- L'app mobile ne sera refaite qu'après l'API : aucun client existant à préserver (le contrat actuel peut casser).
- **La base Neon est vide** (aucune table, aucune donnée) : on part d'une migration initiale propre + données de démonstration. Aucune reprise de données.
- Hébergement de l'API non choisi : rester portable (Dockerfile existant, configuration par variables d'environnement).

## 7. Modèle fonctionnel

### 7.1 Utilisateur
- Identifié par son **numéro de téléphone** (unique, vérifié par code).
- Champs : nom affiché, téléphone, photo de profil (optionnelle), `isSeller` (mode vendeur activé ou non), date d'inscription.
- Un numéro **WhatsApp** distinct est possible pour le vendeur (par défaut = son téléphone).
- « Passer en mode vendeur » active `isSeller` ; on peut revenir en mode acheteur sans perdre ses annonces (elles restent en ligne).
- Infos vendeur visibles sur une fiche : nom, photo, « membre depuis », nombre d'annonces en ligne, liens d'appel/WhatsApp.

### 7.2 Authentification (sans mot de passe)
- `demander un code` (numéro + nom si nouveau compte) → code à 6 chiffres envoyé par **SMS ou WhatsApp** (canal choisi par l'app ; SMS par défaut).
- `vérifier le code` → crée le compte s'il n'existe pas, renvoie une **session longue durée** : jeton d'accès court + jeton de rafraîchissement long (plusieurs mois, révocable, renouvelé à chaque usage). L'utilisateur ne doit pas avoir à redemander de code tant qu'il utilise l'app régulièrement.
- Protection : expiration du code (quelques minutes), nombre d'essais limité, limitation du nombre d'envois par numéro et par IP.
- **Envoi des codes derrière une interface** (« fournisseur de code ») : en développement, le code est simplement affiché dans les logs ; le fournisseur réel (Twilio Verify, fournisseur SMS local, WhatsApp Business) sera branché au lancement par configuration.
- Déconnexion = révocation du jeton de rafraîchissement.

### 7.3 Annonce
- Champs principaux : titre, description, type de bien (maison, villa, appartement, studio, chambre, terrain/autre — liste extensible), nombre de pièces, chambres, salles de bain, surface (optionnelle), équipements (liste : meublé, climatisation, parking, piscine, groupe électrogène, gardien, wifi…), photos ordonnées (une photo de couverture).
- **Localisation** : ville, commune/quartier, adresse libre facultative, **coordonnées GPS** (point choisi par le vendeur). Pour la vie privée, la position exacte n'est donnée qu'à l'échelle du quartier dans les listes ; la fiche donne le point.
- **Offres** (au moins une, au plus une de chaque) :
  - `location au mois` — loyer mensuel (+ caution / avance éventuelles en texte ou montant),
  - `location à la nuit` — prix par nuit (+ nombre de nuits minimum optionnel),
  - `vente` — prix de vente.
- **Publication** : soit **date de fin**, soit **permanente**.
- **États** :
  - `brouillon` — en cours de création, invisible ;
  - `en ligne` — visible ;
  - `expirée` — date de fin dépassée, invisible ; réactivable avec une nouvelle date ou en permanente ;
  - `désactivée` — mise hors ligne volontaire par le vendeur, réactivable ;
  - `close` — marquée « louée » ou « vendue » par le vendeur, invisible, réactivable si le bien se libère.
- **Compteurs** : vues de la fiche, clics WhatsApp/appel, nombre de demandes — visibles par le vendeur.
- Suppression par le vendeur possible (suppression logique : l'historique des demandes reste cohérent).

### 7.4 Demande
- Créée par un utilisateur connecté sur une annonce **en ligne**, pour **une** offre de l'annonce.
- Contenu : offre visée ; pour la nuit : date d'arrivée et de départ (obligatoires, cohérentes, ≥ minimum de nuits, pas sur des nuits déjà bloquées) ; pour le mois : date d'emménagement souhaitée (optionnelle) ; pour tous : message libre, souhait de visite (oui/non).
- États : `en attente` → `acceptée` | `refusée` (par le vendeur) ; `annulée` (par l'acheteur, tant qu'elle n'est pas refusée).
- Quand une demande **à la nuit** est acceptée, ses nuits sont **bloquées** sur l'annonce (une autre demande sur ces nuits est refusée). Les nuits sont libérées si cette demande acceptée est ensuite annulée.
- Quand une demande **au mois ou à la vente** est acceptée, l'API ne change pas l'état de l'annonce ; c'est l'app qui propose au vendeur « Marquer comme loué / vendu ? ».
- Un acheteur ne peut pas faire de demande sur sa propre annonce, ni avoir deux demandes `en attente` sur la même annonce.
- **Coordonnées de l'acheteur** : le vendeur voit le **nom et le numéro** de l'acheteur **dès réception** de la demande (pour l'appeler / lui écrire sur WhatsApp). L'app l'indique sur le formulaire de demande (« Votre nom et votre numéro seront transmis au vendeur »).
- **Chevauchement** : à l'acceptation d'une demande à la nuit, les autres demandes `en attente` de la même annonce dont les nuits chevauchent sont **refusées automatiquement** (motif « dates plus disponibles ») et leurs acheteurs notifiés. L'acceptation doit être sûre en cas d'accès concurrents (deux acceptations simultanées ne peuvent pas bloquer les mêmes nuits).
- **Annonce qui quitte l'état `en ligne`** (expirée, désactivée, close, supprimée) ou **offre retirée** : les demandes `en attente` concernées sont refusées automatiquement (motif « annonce plus disponible ») et les acheteurs notifiés. Les demandes déjà `acceptées` ne changent pas et leurs nuits restent bloquées.
- Une demande refusée porte un **motif** : refus du vendeur (message optionnel), dates plus disponibles, annonce plus disponible.

### 7.5 Contact WhatsApp / appel
- Le lien WhatsApp est construit côté app (`wa.me/<numéro>?text=…`) avec un message pré-rempli (« Bonjour, je suis intéressé par *<titre>* vu sur WELLY »).
- L'app **signale chaque clic** à l'API (sans compte requis) pour alimenter les compteurs.

### 7.6 Favoris
- Sans compte : stockés **sur le téléphone** (pas d'API).
- Avec compte : synchronisés via l'API (ajout, retrait, liste) ; à la connexion, l'app envoie ses favoris locaux pour les fusionner.

### 7.7 Signalement
- Motifs : arnaque / bien inexistant, prix trompeur, photos trompeuses, déjà loué/vendu, autre (+ commentaire).
- **Sans compte** autorisé : rattaché à un **identifiant d'installation** de l'app (généré par l'app, envoyé dans un en-tête). Avec compte : rattaché à l'utilisateur (et à l'installation).
- Effet : l'annonce est **exclue des résultats et de la fiche** pour cet utilisateur / cette installation. Aucun effet pour les autres.
- Tous les signalements sont conservés (pour une future administration).

### 7.8 Notifications
- **Push** (Firebase Cloud Messaging) sur les appareils enregistrés de l'utilisateur + **liste consultable** dans l'app (lue / non lue).
- Événements :
  - vendeur : nouvelle demande ; demande annulée par l'acheteur ; annonce expirée ; annonce qui expire dans 3 jours (rappel) ;
  - acheteur : demande acceptée ; demande refusée (y compris refus automatiques, avec leur motif).
- L'envoi push est derrière une interface (en dev : log) ; l'absence de configuration FCM ne doit pas casser l'API.

### 7.9 Tâche planifiée
- Une fois par jour (et au démarrage) : passer en `expirée` les annonces dont la date de fin est dépassée, notifier les vendeurs ; envoyer les rappels « expire dans 3 jours ».
- L'hébergement n'est pas encore choisi : la tâche doit être **sûre avec plusieurs instances** (verrou en base, ex. advisory lock PostgreSQL) et **idempotente** (un rappel ou une expiration n'est jamais notifié deux fois).

### 7.10 Compte
- Modifier son profil (nom, photo, numéro WhatsApp).
- **Supprimer son compte** depuis l'app (exigé par l'App Store et Google Play) : les annonces du vendeur sont retirées (supprimées logiquement, demandes en attente refusées), les données personnelles sont **anonymisées** (nom, téléphone, photo), les sessions et appareils sont révoqués. L'historique (demandes, signalements) reste cohérent mais anonyme. Le numéro redevient libre pour un nouveau compte.
- Changement de numéro de téléphone : hors périmètre pour l'instant.

## 8. Recherche

- **Autour de moi** : latitude/longitude + rayon (défaut 10 km), tri par distance ; la distance est renvoyée.
- **Texte** : sur titre, quartier, ville, description (insensible aux accents et à la casse).
- **Filtres** : type d'offre (mois / nuit / vente), type de bien, ville, commune/quartier, fourchette de prix (s'applique au prix de l'offre filtrée), pièces/chambres minimum, équipements, et pour la nuit : dates (exclut les annonces dont des nuits sont bloquées).
- **Tri** : pertinence/distance, plus récentes, prix croissant, prix décroissant.
- **Pagination** par curseur, taille de page bornée.
- Exclut toujours : annonces non `en ligne`, annonces supprimées, annonces signalées par l'utilisateur/installation courante.
- Liste de **villes/communes** disponibles (pour les filtres) dérivée des annonces en ligne.

## 9. Photos

- Upload par le vendeur (jpeg/png/webp, taille max ~8 Mo, ~15 photos max par annonce), réordonnables, suppression possible.
- Stockage **hors du serveur** (le disque local actuel n'est pas viable en hébergement) via une interface de stockage : implémentation **locale en dev**, service objet en prod (S3 compatible : Cloudflare R2, S3, ou Cloudinary — choix du builder, configurable).
- Génération de tailles adaptées (vignette pour les listes, grande pour la fiche) au format webp.

## 10. Qualité de l'API (« design » de l'API)

- Préfixe de version : `/v1`.
- Ressources nommées en anglais, au pluriel, en kebab-case ; corps JSON en camelCase. Valeurs d'énumérations en anglais minuscules (`monthly`, `nightly`, `sale`, `pending`…). Les libellés français sont l'affaire de l'app.
- **Format d'erreur unique** pour toute l'API : `{ "error": { "code": "LISTING_NOT_FOUND", "message": "<message français lisible>", "details"?: [...] } }` avec codes HTTP corrects (400 validation, 401, 403, 404, 409 conflit, 422 règle métier, 429 trop de requêtes).
- Listes paginées : `{ "data": [...], "nextCursor": "..." | null }`.
- Dates en ISO 8601 UTC ; dates de séjour en `YYYY-MM-DD`.
- **Documentation interactive OpenAPI/Swagger** générée depuis le code, exposée en dev (`/docs`).
- Validation stricte des entrées (champs inconnus rejetés).
- Sécurité : en-têtes de sécurité, CORS configurable, limitation de débit (surtout sur l'OTP), aucun secret par défaut en production.
- **Schéma de base géré par migrations** (fin du `synchronize: true`), avec un jeu de **données de démonstration** (seed) reprenant les annonces d'exemple du site (Cocody, Riviera, Marcory, Bingerville, Assinie).
- Endpoint de santé (`/health`) qui vérifie la base.

## 11. Ce qui est laissé au builder

- Découpage en modules, nommage exact des routes et des DTO (dans le respect du §10).
- Bibliothèques : PostGIS ou calcul de distance en SQL pur ; bibliothèque de validation des numéros ; planificateur de tâches ; Swagger ; limitation de débit.
- Durées exactes (validité du code, du jeton d'accès, du rafraîchissement), tailles d'images, limites de pagination.
- Choix du stockage objet en production et du fournisseur SMS/WhatsApp (tant que c'est une configuration, pas un changement de code).
- Stratégie de tests (unitaires + e2e sur une base de test), en gardant Vitest.
- Mise à jour des READMEs (`api_project/README.md`, section API du README racine) et de `AGENTS.md`.

## 12. Choix faits par Claude (à vérifier par l'utilisateur)

- Favoris sans compte gardés sur le téléphone, synchronisés une fois connecté.
- Signalement possible sans compte via un identifiant d'installation.
- Pour la nuit : blocage des nuits seulement à l'acceptation d'une demande (pas de calendrier géré par le vendeur).
- Position exacte du bien visible seulement sur la fiche, quartier dans les listes.
- Rappel au vendeur 3 jours avant l'expiration.
- Numéro du vendeur public (nécessaire à la mise en relation).
- Nom et numéro de l'acheteur transmis au vendeur dès la demande (recommandation de Claude, acceptée par défaut — l'utilisateur n'a pas tranché explicitement).
- Refus automatiques (chevauchement de nuits, annonce plus disponible) avec notification.
- Tâche d'expiration protégée par verrou en base (hébergement multi-instances possible).
- Suppression de compte par anonymisation.
