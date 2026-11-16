# mombongo

Application de caisse et de gestion Mombongo (Flutter).

## Environnement API (au build)

L'URL de l'API est choisie au moment du build avec `--dart-define`, plus rien à modifier dans le code.

| `ENV`  | Serveur                              |
|--------|--------------------------------------|
| `test` | https://test-mombongo.asdc-rdc.org   |
| `dev`  | https://dev-mombongo.asdc-rdc.org    |
| `prod` | https://prod-mombongo.asdc-rdc.org   |

```bash
# Développement
flutter run --dart-define=ENV=dev

# Production
flutter build apk --release --dart-define=ENV=prod
flutter build appbundle --release --dart-define=ENV=prod

# Autre serveur (local, recette…)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000
```

Règles :
- en debug, sans `ENV`, l'application utilise le serveur de **test** ;
- un build **release** sans `ENV` (ni `API_BASE_URL`) refuse de démarrer ;
- une valeur inconnue (ex. `ENV=prd`) refuse de démarrer avec un message explicite.

En debug, le bandeau rouge affiche l'environnement actif (ex. « En mode développement · DEV »).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
