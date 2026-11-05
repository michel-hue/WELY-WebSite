# WELLY mobile (refonte) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter app (`mobile_project/`) on a light WELLY identity, wired to the `v1` API, covering the four journeys of the spec; plus the two API additions the app needs.

**Architecture:** Feature-first Flutter app (`lib/core` for theme/API/session, `lib/features/<feature>` for data + screens). Riverpod for state and dependency injection (every repository is a provider, overridden with fakes in tests), go_router with a `StatefulShellRoute` for the 4 tabs, Dio with an interceptor that adds the bearer + `X-Installation-Id` and refreshes the session once on 401. API changes are done TDD in `api_project/` first.

**Tech Stack:** Flutter 3.47 / Dart 3.13, flutter_riverpod, go_router, dio, flutter_secure_storage, shared_preferences, flutter_map + latlong2 (CARTO Positron tiles), geolocator, cached_network_image, url_launcher, image_picker, share_plus, intl, uuid, firebase_messaging (optional at runtime), mocktail (tests). Versions: latest that `flutter pub add` resolves.

**Spec:** `docs/superpowers/specs/2026-11-05-mobile-design.md` (API contract: `docs/superpowers/specs/2026-11-04-api-design.md`). Validated mockups: `.superpowers/brainstorm/7718-1793874114/content/accueil-c-variantes.html` (C3), `ecrans-cles.html`, `fiche-boutons.html` (capsule 3).

## Global Constraints

- Light background only. Tokens (exact): ivoire `#F6F3EE`, surface `#FFFFFF`, line `#E6E0D6`, line soft `#EEE8DE`, ink `#13161B`, muted `#6B6F76`, laiton `#C2A25F`, laiton text `#9C7F3C`, laiton soft `#F3EBDA`, online `#1F7A45`/`#E3F1E7`, expired `#9A5A1C`/`#F6E7D8`, closed `#6B6F76`/`#ECEAE6`, WhatsApp `#1F9D55`.
- Fonts bundled in `assets/fonts/`: Inter (300/400/500) and Instrument Serif Italic (OFL). Radii: cards 18–20, sheets 24 (top), pills stadium.
- All UI copy in French; prices `650 000 F` (narrow no-break space thousands separator, ` F` suffix); dates French (`1 déc.`, `1er décembre`).
- Never require an account to browse, filter, open a listing, WhatsApp, report, or keep local favorites.
- A first request is sent from a single bottom sheet (form + OTP inside it). No password anywhere.
- API base URL from `--dart-define=API_URL=...`; default `http://10.0.2.2:3000/v1` on Android emulator, `http://localhost:3000/v1` elsewhere.
- Every request carries `X-Installation-Id` (UUID v4 generated once, stored in shared_preferences).
- API errors are `{ error: { code, message, details? } }`; the UI shows `message` (already French), field `details` under the field.
- `flutter analyze` clean and `flutter test` green at the end of every task; API tasks keep `npm test` + targeted e2e green.
- Replace old `lib/` (iteration 1) entirely; keep platform folders, rename app label to « WELLY », Android `applicationId` unchanged.

## Review Focus

- No location permission / location off / GPS slow → Explorer must still show listings around Abidjan (Plateau 5.3197, -4.0267) within one load, never a blank screen.
- Expired access token mid-session with several requests in flight → exactly one refresh call, the others wait and replay; refresh failure → session cleared, user stays in the app as anonymous (not a crash, not a loop).
- Offline / timeout on any screen → soft error with « Réessayer », no unhandled exception.
- OTP sheet: wrong code (`OTP_INVALID`), too many tries (`OTP_TOO_MANY_ATTEMPTS`), resend too soon (`OTP_RESEND_TOO_SOON`), new user without name (`VALIDATION_ERROR` on `name`) → message in the sheet, sheet stays open, entered data kept.
- WhatsApp not installed → fall back to `tel:`; seller with no phone → capsule WhatsApp side disabled, demand still possible.

---

### Task 1: API — approximate position on cards, seller contact on buyer requests

**Files:**
- Modify: `api_project/src/search/public-listing.dto.ts` (card gets `approxLocation`)
- Create: `api_project/src/search/approx-location.ts`
- Modify: `api_project/src/requests/requests.service.ts:316-345` (`toDtos` adds `seller` when not `withBuyer`)
- Modify: `api_project/src/requests/dto/request.dto.ts` or the `RequestDto` interface in `requests.service.ts:20-35`
- Test: `api_project/src/search/approx-location.spec.ts`, `api_project/test/mobile-additions.e2e-spec.ts`

**Interfaces:**
- Produces: `ListingCardDto.approxLocation: { lat: number; lng: number } | null`; `RequestDto.seller?: { id: string; name: string; phone: string | null; whatsappPhone: string | null }` present on buyer-side responses (`POST /requests`, `GET /me/requests`, `POST /requests/:id/cancel`), absent on seller-side.

- [ ] **Step 1: Unit test `approxLocation(id, point)`** in `approx-location.spec.ts`: same id → same output (stable); output differs from input; haversine distance between 150 m and 600 m; coordinates rounded to 4 decimals; `null` point → `null`.
- [ ] **Step 2: Run** `npm test -- approx-location` → FAIL (module missing).
- [ ] **Step 3: Implement** `export function approxLocation(id: string, p: {lat:number;lng:number}|null)` : derive angle and distance (150–500 m) from `sha256(id)` bytes, offset the point, round to 4 decimals.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: e2e test** `mobile-additions.e2e-spec.ts`: (a) `GET /v1/listings?lat&lng` cards have `approxLocation` within 600 m of the created listing's real point and not equal to it, and no `location` key; (b) buyer creates a request, seller closes the listing, buyer's `GET /v1/me/requests` item has `seller.phone` equal to the seller's phone and `seller.whatsappPhone`; seller's `GET /v1/me/received-requests` item has no `seller` key.
- [ ] **Step 6: Run** `TEST_DATABASE_SCHEMA=welly_test npx vitest run -c vitest.config.e2e.ts test/mobile-additions.e2e-spec.ts` → FAIL on both.
- [ ] **Step 7: Implement**: `toCardDto` sets `approxLocation: approxLocation(l.id, locationOf(l))`; `toDtos` loads listing owners and adds `seller` when `!withBuyer`.
- [ ] **Step 8: Run** the e2e file + `test/search.e2e-spec.ts test/requests.e2e-spec.ts` + `npm test` + `npm run typecheck && npm run lint` → all green.
- [ ] **Step 9: Commit** `feat(api): position approximative des annonces et contact vendeur dans les demandes`.

### Task 2: Flutter foundation — clean slate, theme, logo, shell

**Files:**
- Delete: everything under `mobile_project/lib/` and `mobile_project/test/`
- Modify: `mobile_project/pubspec.yaml` (name stays `mobile_project`; deps; fonts; assets)
- Create: `lib/main.dart`, `lib/app.dart`, `lib/core/theme/tokens.dart`, `lib/core/theme/app_theme.dart`, `lib/core/widgets/welly_logo.dart`, `lib/core/widgets/serif_title.dart` (title with one italic serif word), `lib/core/router.dart`, `lib/core/shell/home_shell.dart`, placeholder screens per tab, `assets/fonts/*`
- Modify: Android `android:label`, iOS `CFBundleDisplayName` → `WELLY`
- Test: `test/core/theme_test.dart`, `test/core/shell_test.dart`

**Interfaces:**
- Produces: `WellyColors` (static consts named as Global Constraints: `ivoire, surface, line, lineSoft, ink, muted, laiton, laitonText, laitonSoft, online, onlineBg, expired, expiredBg, closed, closedBg, whatsapp`); `buildAppTheme() → ThemeData`; `WellyLogo({double size = 28, bool wordmark = false})` (CustomPainter, paths from `dev-project/components/WellyLogo.vue`, house ink / W ivoire); `SerifTitle(String before, String serif, {String after = '', double size = 22})`; `appRouterProvider` with routes `/explore`, `/favorites`, `/requests`, `/profile` (StatefulShellRoute) and `/listing/:id` (full screen above the shell).

- [ ] **Step 1: Tests**: `theme_test` asserts `buildAppTheme().scaffoldBackgroundColor == WellyColors.ivoire` and body font family `Inter`; `shell_test` pumps the app and finds the 4 tab labels `Explorer`, `Favoris`, `Demandes`, `Profil`, taps `Profil` and finds its placeholder.
- [ ] **Step 2: Run** `flutter test` → FAIL.
- [ ] **Step 3: Implement**: `flutter pub add` the stack deps (+ `dev:mocktail`); download Inter (static 300/400/500 TTF) and Instrument Serif Italic TTF from the Google Fonts GitHub repos into `assets/fonts/` with their `OFL.txt`; theme (ivoire scaffold, white cards, stadium buttons: ink filled / laiton filled, Inter 300 body); bottom bar per mockup (white 97 %, top line, active icon laiton, thin outline icons).
- [ ] **Step 4: Run** `flutter analyze && flutter test` → clean / PASS.
- [ ] **Step 5: Commit** `feat(mobile): socle — thème clair WELLY, logo, navigation`.

### Task 3: API client, session, installation id

**Files:**
- Create: `lib/core/api/api_client.dart`, `lib/core/api/api_error.dart`, `lib/core/api/auth_interceptor.dart`, `lib/core/session/session_store.dart`, `lib/core/session/session_controller.dart`, `lib/core/installation_id.dart`, `lib/core/config.dart`
- Test: `test/core/api_client_test.dart`, `test/core/session_controller_test.dart` (fake `HttpClientAdapter`)

**Interfaces:**
- Produces: `ApiError implements Exception { int? status; String code; String message; List<FieldError> details; bool get isNetwork; }` (`code == 'NETWORK'`, message « Connexion impossible. Vérifiez votre réseau. » for timeouts/no connection); `dioProvider`; `Me` model (`id, name, phone, whatsappPhone, avatarUrl, isSeller, createdAt`); `SessionController` (Riverpod `AsyncNotifier<Me?>`) with `requestOtp(phone, {channel}) → Future<({int expiresInSeconds, bool isNewUser})>`, `verifyOtp(phone, code, {String? name})`, `logout()`, `refreshMe()`, `setSellerMode(bool)`, `updateProfile({name, whatsappPhone})`, `deleteAccount()`; `SessionStore` (secure storage keys `access`, `refresh`); `installationIdProvider`.

- [ ] **Step 1: Tests**: error body → `ApiError` with code/message/details; socket timeout → `isNetwork`; every request has `X-Installation-Id`; with tokens stored, a 401 triggers exactly one `POST /auth/refresh` even for 3 concurrent calls, all 3 replay with the new bearer; refresh 401 → tokens cleared and `SessionController` state becomes `null`; `verifyOtp` stores both tokens and exposes `Me`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** (refresh guarded by a single in-flight `Completer`; refresh uses a bare Dio without the interceptor; `logout` calls `/auth/logout` best-effort then clears).
- [ ] **Step 4: Run** `flutter analyze && flutter test` → PASS.
- [ ] **Step 5: Commit** `feat(mobile): client API, session sans mot de passe`.

### Task 4: Listings data + formatting

**Files:**
- Create: `lib/features/listings/models.dart`, `lib/features/listings/listings_repository.dart`, `lib/core/format.dart`, `lib/core/labels.dart`
- Test: `test/features/listings_models_test.dart`, `test/core/format_test.dart`

**Interfaces:**
- Produces: `OfferType { monthly, nightly, sale }`; `Offers { MonthlyOffer? monthly; NightlyOffer? nightly; SaleOffer? sale; }`; `ListingCard` (fields of `ListingCardDto` incl. `approxLocation` as `LatLng?`); `ListingDetail extends ListingCard` (+ description, bedrooms, bathrooms, surfaceM2, amenities, address, `LatLng? location`, photos, `PublicSeller seller`); `Page<T> { List<T> data; String? nextCursor; }`; `SearchFilters` (immutable, `copyWith`, `toQuery()`, `activeCount`); `ListingsRepository` with `search(SearchFilters, {LatLng? near, double? radiusKm, String? cursor}) → Future<Page<ListingCard>>`, `detail(id) → Future<ListingDetail>`, `recordContactClick(id)`, `report(id, reason, {comment})`, `locations()`; `formatPrice(int) → '650 000 F'`, `priceSuffix(OfferType) → '/ mois' | '/ nuit' | ''`, `formatDistance(int m) → '800 m' | '1,2 km'`, `formatDate`; French labels for property types, amenities, statuses, refusal reasons, report reasons.

- [ ] **Step 1: Tests**: parse a real `GET /v1/listings` sample (copy from an e2e response shape incl. `approxLocation`) and a detail sample; `formatPrice(650000) == '650 000 F'`; `formatDistance(1234) == '1,2 km'`; `SearchFilters(offerType: nightly, priceMax: 30000).toQuery()` has `offerType=nightly&priceMax=30000`; `activeCount` counts set filters.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): modèles et dépôt des annonces`.

### Task 5: Explorer (C3)

**Files:**
- Create: `lib/features/explore/explore_screen.dart`, `explore_controller.dart`, `cluster.dart`, `map_view.dart`, `listings_sheet.dart`, `listing_photo_card.dart` (shared big card), `filters_sheet.dart`, `location_service.dart`, `location_explainer.dart`
- Test: `test/features/cluster_test.dart`, `test/features/explore_screen_test.dart`

**Interfaces:**
- Consumes: `ListingsRepository.search`, `SearchFilters`, `ListingCard.approxLocation`.
- Produces: `clusterPoints(List<ListingCard>, {required double zoom}) → List<MapCluster>` (pure grid clustering: cell = 60 logical px at that zoom; `MapCluster { LatLng center; List<ListingCard> items; }`); `ListingPhotoCard(ListingCard card, {VoidCallback? onTap})` reused by Favoris; `LocationService.current() → Future<LatLng?>` (null when denied/off/timeout 6 s); `abidjan = LatLng(5.3197, -4.0267)`.

Behaviour (from spec §4.1–4.2): full-screen map (CARTO Positron light tiles with attribution), laiton dots / laiton clusters with count, blue user dot, recenter button; floating search pill + filter button with active count; draggable sheet (snap 0.18 / 0.5 / 0.92) titled `SerifTitle('', 'Autour de vous')`, big photo cards, Carte/Liste segmented toggle (Liste = sheet at full height); tap dot → its card first; tap cluster → zoom in; map moved → « Rechercher dans cette zone » chip (search around map center, radius from visible bounds, max 50 km); first launch shows `location_explainer` before the system prompt (flag in shared_preferences); empty and error states per spec.

- [ ] **Step 1: Tests**: `clusterPoints` merges two points 50 m apart at zoom 12, keeps them separate at zoom 18, ignores cards without `approxLocation`; widget test with fake repo + fake `LocationService` returning null: shows cards from the fake around Abidjan, typing in search + submit calls `search` with `q`, filter sheet « À la nuit » sets `offerType=nightly`, empty result shows « Aucun logement ici pour l'instant », repo throwing network `ApiError` shows « Réessayer » (map tiles disabled in tests via a `tileProviderOverride`).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test` → PASS.
- [ ] **Step 5: Commit** `feat(mobile): accueil carte (C3), recherche et filtres`.

### Task 6: Listing detail + capsule + report

**Files:**
- Create: `lib/features/listing/listing_screen.dart`, `photo_gallery.dart`, `contact_capsule.dart`, `report_sheet.dart`, `lib/core/contact.dart`
- Test: `test/features/listing_screen_test.dart`, `test/core/contact_test.dart`

**Interfaces:**
- Consumes: `ListingsRepository.detail/recordContactClick/report`, favorites toggle from Task 8 via `favoritesProvider` (Task 6 ships a stub provider with the same signature if Task 8 not done: `isFavorite(id)`, `toggle(ListingCard)`).
- Produces: `whatsappUri(String phone, String title) → Uri` (`https://wa.me/<digits>?text=Bonjour, je suis intéressé par « <title> » vu sur WELLY`); `openWhatsAppOrCall(phone, title)`; route `/listing/:id`; `showRequestSheet(context, ListingDetail, OfferType)` hook called by the capsule (implemented in Task 7).

Behaviour: gallery 270 px with round white buttons (back, share via share_plus, ♡), counter `1 / N`, tap → full-screen viewer; ivoire panel overlapping 20 px with radius 24; offer chips (selected = laiton soft) switching the price line; title with serif last word; district · distance; facts row; amenities; description; small map with exact point; seller card (initial avatar, « Membre depuis … », « N annonces »); « Signaler » link → report sheet (5 reasons + comment) → on success pop to Explorer and remove the listing from current results. Floating dark capsule (ink 92 %, blur): left WhatsApp (icon + label, disabled if no phone), right laiton « Faire une demande ». Own listing (seller.id == me.id) → capsule replaced by « Gérer l'annonce » (route to Task 10's manage screen). `LISTING_NOT_FOUND` / 404 → « Cette annonce n'est plus disponible » + back.

- [ ] **Step 1: Tests**: `whatsappUri('+2250700000001','Villa')` → `https://wa.me/2250700000001?text=...` encoded; widget: renders title/price/facts from fake detail; tapping « À la nuit » chip changes price suffix to `/ nuit`; tapping WhatsApp calls `recordContactClick` and the injected launcher with the wa.me URI; report flow calls `report(id, 'scam', ...)` and pops; own listing shows « Gérer l'annonce ».
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): fiche logement, capsule WhatsApp / demande, signalement`.

### Task 7: Auth sheet + request sheet

**Files:**
- Create: `lib/features/auth/otp_panel.dart` (reusable: phone [+ name] → code), `lib/features/auth/login_sheet.dart`, `lib/features/requests/request_sheet.dart`, `lib/features/requests/requests_repository.dart`, `lib/features/requests/models.dart`
- Test: `test/features/request_sheet_test.dart`, `test/features/otp_panel_test.dart`

**Interfaces:**
- Consumes: `SessionController.requestOtp/verifyOtp`, `ApiError.details`.
- Produces: `OtpPanel({required void Function() onSignedIn, bool askName})`; `showLoginSheet(context) → Future<bool>`; `ListingRequest` model (`RequestDto` incl. `seller` and `buyer`, statuses `pending|accepted|refused|cancelled`, refusal reasons); `RequestsRepository` with `create({listingId, offerType, checkIn, checkOut, moveInDate, message, wantsVisit})`, `mine({status, cursor})`, `received({status, cursor})`, `accept(id)`, `refuse(id, {message})`, `cancel(id)`.

Behaviour (spec §4.4): one sheet over the dimmed listing, `SerifTitle('Votre', 'demande')`; offer chips; nightly → date range picker (respect `minNights`), monthly → optional move-in date; message; « Je souhaite visiter » switch; anonymous → name + phone (+225 prefilled) + mention « Votre nom et votre numéro seront transmis au vendeur », then 6 code boxes in the same sheet (auto-advance, paste support, « Renvoyer le code » enabled after 60 s); « Envoyer ma demande » → after `verifyOtp` (with name) → favorites merge (Task 8 hook) → `create`. Errors: field details under fields, `STAY_DATES_UNAVAILABLE` under the dates, others in a soft banner; sheet stays open with data kept. Success → gentle confirmation, close, Demandes tab shows it.

- [ ] **Step 1: Tests** (fake session + repo): anonymous flow fills name/phone → `requestOtp` called with E.164 `+2250712345678`; entering 6 digits calls `verifyOtp(…, name: 'Awa Traoré')` then `create` with `offerType: nightly, checkIn, checkOut`; `OTP_INVALID` shows its message and keeps the sheet; `VALIDATION_ERROR` detail on `name` shows under the name field; signed-in user sees no phone/code fields.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): demande en un panneau avec code SMS`.

### Task 8: Favorites + Demandes tab

**Files:**
- Create: `lib/features/favorites/favorites_controller.dart`, `favorites_repository.dart`, `favorites_screen.dart`; `lib/features/requests/requests_screen.dart`, `request_tile.dart`
- Test: `test/features/favorites_controller_test.dart`, `test/features/requests_screen_test.dart`

**Interfaces:**
- Produces: `favoritesProvider` (`AsyncNotifier<List<ListingCard>>`, `isFavorite(id)`, `toggle(ListingCard)`, `mergeLocalIntoAccount()` called after any sign-in); local store = shared_preferences JSON list of cards; signed-in = `GET/PUT/DELETE /me/favorites`, `POST /me/favorites/merge`.

Behaviour: Favoris grid of `ListingPhotoCard` (2 columns), local unavailable ones greyed « plus disponible » (detail 404 on open); empty state « Touchez ♡ sur un logement pour le retrouver ici ». Demandes: anonymous → soft invitation + « Se connecter » (login sheet); buyer list with status pill (colors from tokens), refusal reason label, « Annuler » on pending, WhatsApp/call to `seller` contact; seller mode → segmented « Reçues / Envoyées »; received tile shows buyer name + phone, offer/dates, call / WhatsApp / Accepter / Refuser (optional message); after accepting a monthly or sale request → dialog « Marquer comme loué / vendu ? » → `close(listingId, reason)` (Task 10 repository; ship the call here via `SellerListingsRepository.close` stub if needed).

- [ ] **Step 1: Tests**: anonymous toggle stores locally and survives a new controller; after sign-in `mergeLocalIntoAccount` posts the local ids and clears local; requests screen shows « En attente » pill and « Annuler » calls `cancel`; seller « Accepter » on a monthly request calls `accept` then shows the « Marquer comme loué » dialog.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): favoris et suivi des demandes`.

### Task 9: Profile, seller space, notifications, account

**Files:**
- Create: `lib/features/profile/profile_screen.dart`, `edit_profile_sheet.dart`, `seller_space.dart`; `lib/features/notifications/notifications_repository.dart`, `notifications_screen.dart`; `lib/features/seller/seller_listings_repository.dart`, `lib/features/seller/models.dart`
- Test: `test/features/profile_screen_test.dart`, `test/features/notifications_test.dart`

**Interfaces:**
- Produces: `SellerListing` model (`SellerListingDto`, status enum `draft|online|expired|deactivated|closed`); `SellerListingsRepository` with `mine({status, cursor})`, `one(id)`, `create(body)`, `update(id, patch)`, `publish(id, {String? until})`, `extend`, `reactivate`, `deactivate`, `close(id, reason)`, `remove`, `uploadPhotos(id, List<XFile>)`, `reorderPhotos(id, ids)`, `deletePhoto`; `unreadCountProvider`.

Behaviour (spec §4.7, §4.9): anonymous → logo, `SerifTitle('Bienvenue sur', 'WELLY')`, « Se connecter », « Proposer un logement » (login then seller mode). Signed in → initial avatar, name, phone; segmented Acheteur / Vendeur (`PUT /me/seller-mode`); buyer view = profile actions (modifier, notifications with unread badge, à propos, se déconnecter, supprimer mon compte with typed confirmation « SUPPRIMER »); seller view = seller space per mockup: `SerifTitle('Mes', 'annonces')`, two stat cards (pending received requests count from `received(status: pending)` first page length + `nextCursor != null ? '+'`, total views = sum of `stats.views`), listing rows with status pill, « Réactiver › » shortcut on expired, laiton « + » → editor. Notifications list (read/unread, tap → mark read + deep link to `/listing/:id` or Demandes), « Tout marquer comme lu ». Profile tab icon shows unread dot.

- [ ] **Step 1: Tests**: anonymous profile shows « Se connecter »; toggling Vendeur calls `setSellerMode(true)` and shows « Mes annonces » with rows from fake repo and correct pill labels (« En ligne », « Expirée », « Close »); delete account requires typing SUPPRIMER before `deleteAccount` is called; tapping an unread notification calls `markRead`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): profil, espace vendeur, notifications`.

### Task 10: Listing editor + management

**Files:**
- Create: `lib/features/seller/editor/editor_screen.dart`, `editor_controller.dart`, `step_property.dart`, `step_location.dart`, `step_photos.dart`, `step_offers.dart`, `step_publish.dart`; `lib/features/seller/manage_listing_screen.dart`
- Test: `test/features/editor_controller_test.dart`, `test/features/manage_listing_test.dart`

**Interfaces:**
- Consumes: `SellerListingsRepository`.
- Produces: routes `/seller/new`, `/seller/listing/:id/edit`, `/seller/listing/:id`.

Behaviour (spec §4.8): steps with progress bar: 1 Le bien → 2 Où (city/district from `locations()` suggestions + free text, address, pin dragged on map, default map center = current position or Abidjan) — `create` at end of step 2, later steps `update` → 3 Photos (image_picker multi, up to 15, upload sequentially with per-photo progress, reorder by drag → `reorderPhotos`, first = cover) → 4 Offres (toggle each of 3, price fields, `terms`, `minNights`; at least one) → 5 Publication (date picker « jusqu'au » or « permanente ») → `publish`. Leaving mid-way keeps the draft (listed as « Brouillon »). Manage screen: stats (vues, clics WhatsApp, demandes), actions by status: online → modifier, prolonger, désactiver, marquer louée/vendue; expired/deactivated/closed → réactiver (date or permanente); all → supprimer (confirm). API errors shown in place (`INVALID_PUBLICATION_DATE`, `INVALID_LISTING_TRANSITION`, `SELLER_MODE_REQUIRED`).

- [ ] **Step 1: Tests**: controller — finishing step 2 calls `create` once with title/propertyType/city/district/location, step 4 calls `update` with offers, step 5 `publish(until: null)` for permanente; validation blocks step 4 with no offer; manage — online listing shows « Prolonger » and calls `extend`, expired shows « Réactiver ».
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(mobile): création et gestion des annonces`.

### Task 11: Polish, push, icon, docs, CI

**Files:**
- Create: `lib/core/push/push_service.dart` (interface + `FirebasePushService` + `NoopPushService`), launcher icon + splash from the logo (`flutter_launcher_icons`, `flutter_native_splash` dev deps, ivoire background), `mobile_project/README.md` (rewrite)
- Modify: `AGENTS.md` (mobile section), `.github/workflows/ci.yml` (mobile job: `flutter pub get`, `flutter analyze`, `flutter test`), `.gitignore` additions if needed
- Test: `test/core/push_service_test.dart`

**Interfaces:**
- Produces: `pushServiceProvider` — `NoopPushService` unless Firebase initializes successfully (missing `google-services.json` / `GoogleService-Info.plist` must not crash); on sign-in registers token via `PUT /me/devices/:token`, on logout `DELETE`.

- [ ] **Step 1: Test**: with Firebase init throwing, provider yields `NoopPushService` and sign-in still succeeds.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** + icons/splash + docs + CI. Android: `INTERNET` permission, location permission strings (FR), `queries` for `https`/`tel` intents (url_launcher on Android 11+); iOS: `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, `LSApplicationQueriesSchemes` (`whatsapp`, `tel`) in French.
- [ ] **Step 4: Run** `flutter analyze && flutter test && flutter build apk --debug` → PASS / build OK.
- [ ] **Step 5: Commit** `chore(mobile): notifications push, icône, documentation et CI`.
