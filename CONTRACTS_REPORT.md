# Rapport de vérification des contrats (WELY itération 2)

## 1. Port backend
- Backend NestJS écoute sur `process.env.PORT ?? 3000`.
- Correction appliquée (front/config uniquement) :
  - `dev-project/config/api.ts` : `http://localhost:3001` → `http://localhost:3000`
  - `dev-project/nuxt.config.ts` runtimeConfig : `http://localhost:3001` → `http://localhost:3000`
- Flutter utilisait déjà `http://localhost:3000` (inchangé).

## 2. Contrats auth
Backend (RegisterDto) : email (string, email), password (string, min 6), role (enum UserRole: buyer|seller, optionnel, default buyer).
Backend (LoginDto) : email, password.

- Web (Nuxt) : pas d'appel API réel pour l'instant (login/register uniquement UI). Champs collectés : firstName, lastName, email, password, confirmPassword. Aucun champ `role` envoyé → à implémenter côté web lors de l'intégration.
- Mobile (AuthService) : login envoie email/password ✓ ; register envoie email/password/role ✓.
  - Incohérence corrigée : mobile envoyait `role: 'BUYER'` (majuscules) alors que le backend attend `buyer` (enum). Corrigé en `'buyer'`.

## 3. Contrats listings
Backend (CreateListingDto) : title (string, min 3), description (string), price (number, >=0), city (string), type (enum ListingType), rooms (int, >=1), photos (string[], optionnel), status (enum, optionnel).

- Mobile (ListingsService) : uniquement GET /listings, pas de création. Cohérent en lecture.
- Web : aucun appel listings. À implémenter.

## 4. Gestion d'erreurs
- Mobile : vérifie statusCode 2xx, sinon throw Exception avec code. Pas de gestion fine 401/403/400/404 côté front (juste code). À améliorer.
- Web : pas d'appels API.

## 5. Incohérences restantes (non corrigées, touchent backend ou hors scope)
- Rôle 'BUYER'/'SELLER' (majuscules) dans mobile → corrigé en 'buyer'. Vérifier qu'aucun autre code mobile n'utilise 'SELLER'/'BUYER' majuscules (aucun trouvé).
- Web n'envoie pas `role` au register (champ absent du formulaire) : à ajouter lors de l'intégration.
- Pas de gestion différenciée des erreurs HTTP côté front (mobile/web).
- Les champs firstName/lastName collectés côté web ne sont pas dans le DTO backend (pas de champ correspondant) → incohérence fonctionnelle à trancher avec le backend (hors scope, non corrigé).