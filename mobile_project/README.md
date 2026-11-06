# WELLY — application mobile

Application Flutter pour trouver un logement en Côte d'Ivoire : explorer la carte et la liste, consulter une fiche, contacter le vendeur (WhatsApp ou demande avec code SMS), suivre ses demandes et favoris, publier et gérer ses annonces. Thème clair uniquement (ivoire, encre, laiton), interface en français.

## Structure

- `lib/core/` : thème (`theme/`), API et session (`api/`, `session/`), routeur, widgets partagés (`widgets/`, dont `WellyLogo`), notifications push (`push/`), configuration (`config.dart`).
- `lib/features/*` : un dossier par fonctionnalité — `auth`, `explore`, `listing`, `listings`, `favorites`, `requests`, `profile`, `seller`, `notifications`.
- `test/` : tests unitaires et de widgets (`test/helpers/` contient les faux repositories et l'adaptateur HTTP).
- `tool/` : scripts de génération (icône).

## Lancer l'application

```bash
flutter pub get
flutter run --dart-define=API_URL=http://192.168.1.20:3000/v1
```

Sans `API_URL`, l'URL par défaut est `http://10.0.2.2:3000/v1` sur l'émulateur Android et `http://localhost:3000/v1` ailleurs. L'API se lance depuis `api_project/` (`npm run start:dev`).

La version affichée dans « À propos » vient de `lib/core/config.dart` ; elle doit rester égale à `version:` dans `pubspec.yaml` (un test le vérifie).

## Tests et qualité

```bash
flutter analyze
flutter test
```

## Notifications push (optionnel)

Le code utilise `firebase_messaging`. Sans fichier de configuration Firebase, l'initialisation échoue silencieusement et l'application utilise un service push inactif : rien ne plante.

Pour activer les push :

1. Créer un projet Firebase et y déclarer les applications Android (`com.example.mobile_project`) et iOS.
2. Placer `google-services.json` dans `android/app/` et `GoogleService-Info.plist` dans `ios/Runner/` (ces fichiers ne sont pas versionnés).
3. Android : ajouter le plugin Gradle `com.google.gms.google-services` (classpath dans `android/settings.gradle.kts`, puis `id("com.google.gms.google-services")` dans `android/app/build.gradle.kts`). Il n'est volontairement pas appliqué par défaut, car le build échouerait sans le fichier JSON.
4. iOS : activer les capacités Push Notifications et Background Modes, et téléverser la clé APNs dans Firebase.

À la connexion, le jeton est enregistré par `PUT /me/devices/:token` (`{"platform": "android" | "ios"}`) ; à la déconnexion il est retiré par `DELETE /me/devices/:token`. Les échecs sont ignorés.

## Icône et écran de lancement

Les PNG sources sont dans `assets/branding/` (logo sur ivoire). Pour les régénérer depuis `WellyLogo` puis recréer les icônes de plateforme :

```bash
flutter test tool/render_branding_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
