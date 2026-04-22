# Règles et Instructions pour l'Assistant IA - Projet Mombongo

## 🎯 Objectif
Ce document contient les règles et instructions spécifiques pour que l'assistant IA puisse intervenir efficacement sur le projet Mombongo en respectant les standards établis.

---

## 🤖 Règles pour l'Assistant IA

### Communication
- **Toujours répondre en français** sauf demande explicite contraire
- **Être concis et direct** dans les réponses
- **Utiliser le markdown** pour structurer les réponses
- **Citer les fichiers et fonctions** avec des backticks ``
- **Ne jamais faire d'assumptions** sans vérifier le code existant

### Interventions sur le Code
- **Lire d'abord** les fichiers existants avant de modifier
- **Privilégier les modifications minimales** et ciblées
- **Suivre les conventions existantes** du projet
- **Ajouter des imports** en haut du fichier uniquement
- **Utiliser `const`** pour les widgets immuables
- **Ne jamais créer de fichiers inutiles** qui encombrent le workspace

### Analyse et Débogage
- **Identifier la cause racine** avant de proposer des solutions
- **Vérifier l'environnement** (Java, Flutter, dependencies)
- **Utiliser les outils appropriés** (grep, find, read)
- **Proposer des solutions testées** et validées

---

## 📁 Structure du Projet (À connaître)

### Organisation Clé
```
lib/
├── ui/
│   ├── screens/          # Écrans principaux
│   │   ├── admin/       # Administration (ex: AdminDashboardScreen)
│   │   ├── user/        # Écrans utilisateurs
│   │   └── common/      # Écrans partagés
│   ├── widgets/         # Composants réutilisables
│   └── themes/          # Thèmes et styles
├── services/            # Logique métier et API
├── models/              # Modèles de données (ex: Site)
├── utils/               # Fonctions utilitaires
└── constants/           # Constantes de l'application
```

### Service Locator
Le projet utilise un pattern Service Locator :
```dart
import '../../../services/service_locator.dart';

// Accès aux services
final authService = getIt<AuthService>();
final siteService = getIt<SiteService>();
```

---

## 🧱 Architecture et Patterns

### Clean Architecture
- **Presentation Layer** : UI (Screens, Widgets)
- **Domain Layer** : Business Logic (Use Cases, Models)
- **Data Layer** : Data Sources (Repositories, Services)

### Conventions de Code
- **Classes** : `PascalCase` (ex: `AdminDashboardScreen`)
- **Variables** : `camelCase` (ex: `userName`, `isLoading`)
- **Fichiers** : `snake_case` (ex: `admin_dashboard_screen.dart`)
- **Imports ordonnés** : Flutter → Packages → Projet

---

## 🔧 Bonnes Pratiques à Appliquer

### Flutter/Dart
- **Toujours utiliser `const`** quand possible
- **Gérer les états** (loading, error, success)
- **Utiliser `Theme.of(context)`** pour les styles
- **Privilégier `StatelessWidget`** si pas d'état local

### Performance
- **Éviter les reconstructions inutiles**
- **Utiliser `ListView.builder`** pour les listes
- **Widgets profonds** : limiter la profondeur < 10

### Sécurité
- **Jamais de clés API** en dur dans le code
- **Valider les entrées** utilisateur
- **Utiliser HTTPS** pour les appels API

---

## 🚨 Problèmes Connus et Solutions

### Gradle/Android
- **Erreur `zip END header not found`** : 
  1. Supprimer `gradle-wrapper.jar` corrompu
  2. Télécharger un nouveau jar depuis GitHub
  3. Vérifier que Java est dans le PATH
  4. Relancer `flutter run`

### Java non reconnu
- **Vérifier** : `java -version`
- **Configurer JAVA_HOME** si nécessaire
- **Redémarrer l'éditeur** après installation

---

## � Workflow d'Intervention

### 1. Analyse Initiale
- Lire les fichiers concernés
- Comprendre le contexte existant
- Identifier le problème exact

### 2. Proposition de Solution
- Expliquer la cause du problème
- Proposer une solution minimale
- Justifier les modifications

### 3. Implémentation
- Faire des modifications ciblées
- Respecter les conventions existantes
- Tester si possible

### 4. Vérification
- Confirmer que le problème est résolu
- Vérifier qu'aucune régression n'est introduite
- Documenter si nécessaire

---

## 🔍 Outils et Commandes

### Recherche dans le Code
```bash
# Rechercher un pattern dans tous les fichiers Dart
grep -r "pattern" lib/ --include="*.dart"

# Trouver tous les fichiers d'un type
find lib/ -name "*.dart" | grep -E "(screen|widget)"
```

### Flutter Commands
```bash
flutter clean          # Nettoyer le projet
flutter pub get        # Installer les dépendances
flutter run            # Lancer l'application
flutter doctor         # Vérifier l'environnement
```

---

## � Packages Courants du Projet

### Dépendances Fréquentes
- `flutter/material.dart` : UI Material Design
- `intl` : Internationalisation et formatage
- `http` : Appels API REST
- `provider` : Gestion d'état (si utilisé)

### Imports Standards
```dart
// Toujours dans cet ordre
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/service_locator.dart';
import '../../../models/site.dart';
```

---

## � Ce qu'il ne faut PAS faire

- **Ne jamais modifier** les fichiers sans les lire d'abord
- **Ne pas créer** de fichiers temporaires ou inutiles
- **Ne pas faire** d'assomptions sur le code existant
- **Ne pas utiliser** de code copié-collé sans adaptation
- **Ne pas ignorer** les conventions de nommage
- **Ne pas oublier** les imports nécessaires

---

## 🎯 Objectifs Principaux

1. **Maintenir la cohérence** du code
2. **Résoudre les problèmes** efficacement
3. **Respecter les standards** établis
4. **Être pédagogique** dans les explications
5. **Minimiser les impacts** des modifications

---

## 📞 Références Rapides

### Fichiers Importants
- `pubspec.yaml` : Dépendances du projet
- `lib/services/service_locator.dart` : Injection de dépendances
- `lib/models/` : Modèles de données
- `android/gradle/wrapper/` : Configuration Gradle

### Commandes de Diagnostic
```bash
flutter doctor -v      # État détaillé de l'environnement
flutter devices        # Appareils connectés
flutter pub deps       # Arbre des dépendances
```

---

*Mis à jour le 2 Avril 2026 - À consulter avant toute intervention*
