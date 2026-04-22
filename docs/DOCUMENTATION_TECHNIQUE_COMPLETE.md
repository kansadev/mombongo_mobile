# Documentation Technique Complète 

## Table des matières
1. [Vue d'ensemble du projet](#vue-densemble-du-projet)
2. [Architecture technique](#architecture-technique)
3. [Structure du projet](#structure-du-projet)
4. [Modèles de données](#modèles-de-données)
5. [Services métier](#services-métier)
6. [Gestion des rôles et permissions](#gestion-des-rôles-et-permissions)
7. [Navigation et routing](#navigation-et-routing)
8. [Pages et fonctionnalités](#pages-et-fonctionnalités)
9. [Configuration et déploiement](#configuration-et-déploiement)
10. [Intégrations externes](#intégrations-externes)
11. [Bonnes pratiques et conventions](#bonnes-pratiques-et-conventions)
12. [Dépannage et maintenance](#dépannage-et-maintenance)

---

## Vue d'ensemble du projet

### Description
L'application **Gestion Hôtelière Mobile** est une solution de gestion hôtelière complète développée avec .NET MAUI, permettant la gestion multi-sites, multi-utilisateurs avec différents niveaux de permissions.

### Technologies principales
- **Plateformes cibles**: Android, Windows
- **Langage**: C#
- **Base de données**: SQL Server (backend), SQLite (local)
- **Architecture**: MVVM (Model-View-ViewModel)
- **DI**: Microsoft.Extensions.DependencyInjection

### Fonctionnalités clés
- Gestion multi-sociétés et multi-sites
- Gestion des rôles (SuperAdmin, SuperManager, Administrateur, Manager, Caissier, Client)
- Synchronisation des données online/offline
- Gestion des stocks et des articles
- Facturation et paiements multiples
- Rapports et analyses
- Impression tickets (intégration Sunmi)

---

## Architecture technique

### Pattern MVVM
L'application suit le pattern Model-View-ViewModel:

- **Models**: Classes de données (Models/)
- **Views**: Pages XAML (Views/)
- **ViewModels**: Logique de présentation (ViewsModels/)

### Injection de dépendances
Configurée dans `MauiProgram.cs`:
```csharp
builder.Services.AddSingleton<Services.IPrintService, PrintService>();
builder.Services.AddSingleton<LocalDatabaseService>();
builder.Services.AddSingleton<StockService>();
// ... autres services
```

### Services principaux
- **SessionService**: Gestion de session utilisateur
- **PermissionService**: Contrôle d'accès
- **SyncService**: Synchronisation online/offline
- **LocalDatabaseService**: Base de données locale

---

## Structure du projet

```
GestionHotelliereMobile/
├── Config/                 # Fichiers de configuration
├── Constants/              # Constantes de l'application
├── Controls/               # Contrôles personnalisés
├── Converters/             # Convertisseurs de données
├── Data/                   # Accès aux données
├── Helpers/                # Utilitaires
├── Interfaces/             # Interfaces de services
├── Models/                 # Modèles de données (52 fichiers)
├── Services/               # Services métier (22 fichiers)
├── Utils/                  # Utilitaires divers
├── ViewModels/             # ViewModels (7 fichiers)
├── Views/                  # Pages XAML (114 fichiers)
├── ViewsModels/            # ViewModels additionnels (47 fichiers)
├── Resources/              # Ressources (images, polices, etc.)
└── Platforms/             # Code spécifique aux plateformes
```

---

## Modèles de données

### Modèles principaux

#### Utilisateur et authentification
- **V_Utilisateur**: Vue utilisateur complète avec informations société/site
- **Utilisateur**: Modèle utilisateur de base
- **UtilisateurCreation**: Modèle pour création utilisateur
- **Role**: Gestion des rôles utilisateurs

#### Structure organisationnelle
- **Societe**: Informations société (raison sociale, etc.)
- **Site**: Informations site (adresse, contact, etc.)
- **Agent**: Informations agents

#### Articles et stocks
- **Article**: Article avec prix, catégorie, etc.
- **ArticleSocieteApi**: Article par société
- **StockArticle**: Gestion des stocks
- **MouvementStock**: Mouvements de stock

#### Ventes et facturation
- **Vente**: Transaction vente
- **Facture**: Facturation
- **LigneFacture**: Lignes de facture
- **Paiement**: Informations paiement

#### Rapports et analyses
- **RapportJournalier**: Rapports quotidiens
- **RapportFinancier**: Rapports financiers
- **CaissierPerformance**: Performance caissiers
- **JournalVente**: Journal des ventes

### Variables globales
**VariablesPubliques.cs**: Gestion des variables globales utilisateur
- Maintient l'état de l'utilisateur connecté
- Propriétés société/site courants
- Méthodes de sauvegarde/réinitialisation

---

## Services métier

### Services de gestion

#### SessionService.cs
**Service singleton de gestion de session**
```csharp
public static SessionService Instance { get; }
public string IdSociete { get; set; }
public int IdSite { get; set; }
public V_Utilisateur? UtilisateurConnecte { get; set; }
```

**Fonctionnalités:**
- Gestion de l'utilisateur connecté
- Contexte société/site
- Déconnexion

#### PermissionService.cs
**Service statique de gestion des permissions**
```csharp
public static bool CanAccessFinancialData()
public static bool CanManageCompanies()
public static bool CanManageUsers()
public static List<string> GetAccessiblePages()
```

**Rôles et permissions:**
- **SuperAdmin**: Gestion globale (sauf finances)
- **SuperManager**: Multi-sites avec accès financiers
- **Administrateur/Manager**: Gestion site
- **Caissier**: Opérations de vente
- **Client**: Self-service

### Services métier principaux

#### SocieteService.cs (14.6KB)
- CRUD sociétés
- Gestion multi-sociétés
- Synchronisation

#### SiteService.cs (9.3KB)
- CRUD sites
- Gestion multi-sites
- Association société

#### ArticleService.cs (13.2KB)
- Gestion articles
- Catégories
- Prix par société

#### StockService.cs (12.7KB)
- Gestion stocks
- Mouvements
- Alertes

#### VenteService.cs (15.6KB)
- Processus vente
- Facturation
- Historique

#### UtilisateurService.cs (7.8KB)
- Gestion utilisateurs
- Rôles
- Permissions

### Services techniques

#### LocalDatabaseService.cs (36.6KB)
- Base SQLite locale
- Synchronisation
- Cache offline

#### SyncService.cs (16.8KB)
- Synchronisation online/offline
- Gestion des conflits
- Mode dégradé

#### PrintService.cs (12.4KB)
- Impression tickets
- Intégration Sunmi (Android)
- PDF

---

## Gestion des rôles et permissions

### Hiérarchie des rôles

1. **SuperAdmin** (admin/admin)
   - Gestion globale plateforme
   - CRUD sociétés/sites/utilisateurs
   - ❌ Pas accès aux données financières

2. **SuperManager** (manager/manager)
   - Gestion multi-sites
   - Accès rapports financiers globaux
   - ✅ Accès données financières

3. **Administrateur/Manager**
   - Gestion site unique
   - Rapports site
   - ✅ Accès données financières site

4. **Caissier**
   - Opérations vente
   - Gestion stock limitée
   - ✅ Accès données financières limitées

5. **Client**
   - Self-service
   - Commandes/réservations
   - ❌ Pas accès back-office

### Matrice des permissions

| Fonctionnalité | SuperAdmin | SuperManager | Admin/Manager | Caissier | Client |
|---------------|------------|--------------|---------------|----------|--------|
| Gérer sociétés | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gérer sites | ✅ | ❌ | ✅ | ❌ | ❌ |
| Gérer utilisateurs | ✅ | ❌ | ✅ | ❌ | ❌ |
| Accès finances global | ❌ | ✅ | ❌ | ❌ | ❌ |
| Accès finances site | ❌ | ✅ | ✅ | ✅ | ❌ |
| Ventes | ❌ | ❌ | ❌ | ✅ | ❌ |
| Self-service | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## Navigation et routing

### Configuration des routes
Dans `AppShell.xaml.cs` (86 lignes):
```csharp
// Pages principales
Routing.RegisterRoute(nameof(MainPage), typeof(MainPage));
Routing.RegisterRoute(nameof(ListeMarchePage), typeof(ListeMarchePage));

// Pages SuperAdmin
Routing.RegisterRoute(nameof(SuperAdminDashboardPage), typeof(SuperAdminDashboardPage));
// ... autres routes

// Pages SuperManager
Routing.RegisterRoute(nameof(SuperManagerDashboardPage), typeof(SuperManagerDashboardPage));
```

### Navigation sécurisée
Utilisation de `NavigationHelper` pour:
- Validation des permissions
- Redirection selon rôle
- Messages d'accès refusé

### Flux de navigation

1. **Login** → Redirection selon rôle
2. **SuperAdmin** → Dashboard SuperAdmin
3. **SuperManager** → Dashboard SuperManager
4. **Admin/Manager** → Dashboard Gestionnaire
5. **Caissier** → Page principale vente
6. **Client** → Interface client

---

## Pages et fonctionnalités

### Pages SuperAdmin (7 pages)

#### SuperAdminDashboardPage
- Statistiques globales plateforme
- Actions rapides création
- Navigation gestion

#### SuperAdminSocietesPage
- Liste sociétés
- CRUD sociétés
- Navigation vers création/édition

#### SuperAdminSitesPage
- Liste sites multi-sociétés
- Gestion sites
- Filtrage par société

#### SuperAdminUtilisateursPage
- Gestion utilisateurs globale
- Filtrage par rôle/société/site
- CRUD utilisateurs

#### SuperAdminRolesPage
- Gestion rôles et permissions
- Vue d'ensemble permissions

#### SuperAdminParametresPage
- Paramètres plateforme
- Informations permissions

#### SuperAdminEditSocietePage
- Édition société existante

### Pages SuperManager (2 pages)

#### SuperManagerDashboardPage
- Sélection site (dropdown)
- Statistiques multi-sites
- Accès rapports globaux

#### SuperManagerParametresPage
- Paramètres SuperManager
- Informations rôle

### Pages Gestionnaire (8 pages)

#### GestionnaireMainPage
- Dashboard site
- Statistiques locales
- Navigation modules

#### RapportsFinanciersPage
- Rapports financiers site
- Export PDF/Excel
- Filtres temporels

#### AnalysePerformancesPage
- Performance caissiers
- Analyses ventes
- Graphiques

#### GestionStocksPage
- Gestion stocks site
- Mouvements
- Alertes

#### GestionUtilisateursPage
- Gestion utilisateurs site
- Rôles locaux
- Permissions

#### RapportsVentePage
- Rapports ventes détaillés
- Export
- Filtres

#### ParametresSystemePage
- Configuration site
- Paramètres locaux

#### RapportVenteCaissierPage
- Rapports individuels caissiers
- Performance détaillée

### Pages Caissier (8 pages)

#### MainPage
- Interface vente principale
- Recherche articles
- Panier

#### FacturationPage
- Processus facturation
- Calculs taxes
- Validation

#### PaiementPage
- Modes de paiement
- Mobile Money
- Carte/espèces

#### ListeDesArticlesPage
- Catalogue articles
- Recherche/filtres
- Détails

#### StockDisponiblePage
- Consultation stocks
- Alertes
- Recherche

#### HistoriqueVentesPage
- Historique transactions
- Détails ventes
- Recherche

#### JournalDesVentesPage
- Journal quotidien
- Résumés
- Export

#### RapportJournalierPage
- Rapport journée
- Chiffre d'affaires
- Articles vendus

### Pages Client (5 pages)

#### ClientMainPage
- Portail client
- Menu principal
- Navigation

#### MenuPage
- Carte restaurant
- Catégories
- Détails plats

#### CommandePage
- Passer commande
- Panier
- Validation

#### ReservationPage
- Réservations
- Calendrier
- Confirmation

#### ClientsJournaliersPage
- Historique commandes
- Favoris
- Répétitions

### Pages utilitaires (15 pages)

#### Pages création/inscription
- CreationSocietePage
- CreationSitePage
- InscriptionUtilisateurPage
- WelcomePage

#### Pages gestion articles/stocks
- ArticlePage
- MiseAJourArticlePage
- MiseAJourStockPage
- ListeProduitsPage
- ArticlesParSitePage
- ImportExportStockPage
- AlertesStockPage

#### Pages paiement
- MobileMoneyPage
- VisaPage

#### Pages système
- ChangementMotDePassePage
- AboutPage
- NotificationsPage
- ProfilAgentPage

#### Pages popups
- ArticleSelectionPopup
- NouveauClientPopup
- ChangementMotDePassePopup
- StockSelectionPopup

---

## Configuration et déploiement

### Configuration projet (.csproj)

```xml
<TargetFrameworks>net8.0-android</TargetFrameworks>
<TargetFrameworks Condition="$([MSBuild]::IsOSPlatform('windows'))">$(TargetFrameworks);net8.0-windows10.0.19041.0</TargetFrameworks>

<ApplicationTitle>Lejecolia App</ApplicationTitle>
<ApplicationId>com.lejecolia</ApplicationId>
<ApplicationDisplayVersion>1.2</ApplicationVersion>
```

### Dépendances principales

#### Packages NuGet
```xml
<PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="8.0.0" />
<PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
<PackageReference Include="Refit" Version="8.0.0" />
<PackageReference Include="ZXing.Net.Maui.Controls" Version="0.4.0" />
<PackageReference Include="iTextSharp" Version="5.5.13.4" />
```

#### Packages Android spécifiques
```xml
<PackageReference Include="SunmiPOSLib" Version="1.0.0" />
<PackageReference Include="TomiSoft.Printing.Thermal.AndroidQ2Pos.Maui" Version="1.0.0" />
```

### Configuration Android

#### Debug Android
```xml
<AndroidLinkMode>None</AndroidLinkMode>
<AndroidEnableProguard>false</AndroidEnableProguard>
<RunAOTCompilation>false</RunAOTCompilation>
```

#### Release Android
```xml
<AndroidLinkMode>SdkOnly</AndroidLinkMode>
<AndroidUseAapt2>true</AndroidUseAapt2>
```

### Ressources

#### Images et icônes
- Icône app: `Resources/AppIcon/appicon.svg`
- Splash screen: `Resources/Splash/splash.svg`
- Images: `Resources/Images/*`

#### Polices
- OpenSans-Regular.ttf
- OpenSans-Semibold.ttf
- FontAwesome (fa-solid-900.ttf)

#### Assets bruts
- Fichiers de configuration
- Templates documents

---

## Intégrations externes

### API Backend

#### Configuration API
`ApiConfig.cs` - Configuration endpoints et authentification

#### Gestion erreurs
`ApiErrorHandler.cs` - Centralisation gestion erreurs HTTP

#### Services API
- Refit pour appels REST
- Sérialisation Newtonsoft.Json
- Gestion tokens JWT

### Impression

#### Intégration Sunmi (Android)
```csharp
#if ANDROID
builder.Services.AddSingleton(SunmiPrinter.Current);
builder.UseSunmiPrinter();
#endif
```

#### Service impression
`PrintService.cs` - Impression tickets et factures
- Support imprimantes thermiques
- Génération PDF
- Formatage tickets

### Paiements

#### Mobile Money
Intégration opérateurs africains
- MTN Mobile Money
- Orange Money
- Autres opérateurs

#### Carte bancaire
Intégration terminaux paiement
- VisaPage.xaml
- Request/response cartes

### QR Code

#### Scanning QR
`ZXing.Net.Maui.Controls` - Génération et scan QR codes
- Identification articles
- Paiements rapides
- Accès rapide

---

## Bonnes pratiques et conventions

### Conventions de nommage

#### Fichiers
- **Pages**: `NomPage.xaml` + `NomPage.xaml.cs`
- **ViewModels**: `NomPageViewModel.cs`
- **Services**: `NomService.cs`
- **Models**: `NomModel.cs`

#### Code
- **Classes**: PascalCase
- **Méthodes**: PascalCase
- **Propriétés**: PascalCase
- **Champs**: _camelCase (privés)
- **Constantes**: PascalCase

### Architecture MVVM

#### Views (XAML)
- Interface utilisateur uniquement
- Data binding vers ViewModels
- Command binding pour actions

#### ViewModels
- Logique présentation
- Propriétés bindables (INotifyPropertyChanged)
- Commands pour interactions
- Services injection

#### Models
- Données pures
- Pas de logique métier
- Validation annotations

### Gestion des erreurs

#### Centralisation
`ApiErrorHandler.cs` pour erreurs API
- Logging structuré
- Messages utilisateur
- Retry patterns

#### Validation
- DataAnnotations models
- Validation ViewModels
- Messages utilisateurs clairs

### Performance

#### Optimisations
- Async/await systématique
- Lazy loading données
- Cache local SQLite
- Pagination listes

#### Memory management
- IDisposable correct
- Unsubscribe events
- Weak references si nécessaire

### Sécurité

#### Authentification
- Tokens JWT
- Refresh tokens
- Session timeout

#### Permissions
- Validation systématique
- Role-based access
- Navigation sécurisée

#### Données
- Chiffrement local si sensible
- HTTPS obligatoire
- Validation inputs

---

## Dépannage et maintenance

### Problèmes courants

#### Synchronisation
**Symptôme**: Données non synchronisées
**Causes possibles**:
- Réseau indisponible
- Conflit de données
- Backend inaccessible

**Solutions**:
1. Vérifier connectivité (`NetworkService`)
2. Consulter logs `SyncService`
3. Forcer synchronisation manuelle
4. Vérifier état backend

#### Performance
**Symptôme**: Application lente
**Causes possibles**:
- Trop de données chargées
- Memory leak
- Database locking

**Solutions**:
1. Profiler avec Visual Studio
2. Implémenter pagination
3. Vérifier IDisposable
4. Optimiser requêtes SQL

#### Impression
**Symptôme**: Impression échoue
**Causes possibles**:
- Imprimante non connectée
- Permissions Android
- Format incorrect

**Solutions**:
1. Vérifier connexion Sunmi
2. Permissions AndroidManifest
3. Tester format ticket
4. Logs `PrintService`

### Debug et logging

#### Logs structurés
```csharp
_logger.LogInformation("Traitement vente {VenteId} pour utilisateur {UserId}", 
    vente.Id, utilisateur.Id);
```

#### Niveaux de log
- Debug: Développement
- Information: Production normal
- Warning: Problèmes non critiques
- Error: Erreurs critiques

#### Outils
- Visual Studio Debugger
- Application Insights (optionnel)
- Logs fichier local
- Console output

### Maintenance préventive

#### Monitoring
- Performance application
- Taux d'erreur API
- Utilisation mémoire
- Synchronisation données

#### Mises à jour
- Packages NuGet réguliers
- MAUI updates
- Sécurité Android
- Tests régression

#### Sauvegardes
- Base de données locale
- Configuration utilisateur
- Logs erreurs
- Versioning code

### Support technique

#### Informations à collecter
- Version application
- Version OS
- Message erreur exact
- Logs récents
- État réseau
- Screenshot si possible

#### Escalade
1. Niveau 1: Problèmes connus (documentation)
2. Niveau 2: Analyse logs et debugging
3. Niveau 3: Correction code/infrastructure

---

## Conclusion

Cette documentation couvre l'ensemble de l'architecture et du fonctionnement de l'application Gestion Hôtelière Mobile. Le code est structuré pour être maintenable, évolutif et robuste avec une séparation claire des responsabilités et une gestion complète des permissions multi-rôles.

Pour toute question ou besoin d'assistance technique, se référer aux sections de dépannage ou contacter l'équipe de développement.

**Dernière mise à jour**: Janvier 2026
**Version**: 1.2
