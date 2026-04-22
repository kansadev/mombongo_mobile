# Debug - Création de Client

## Problème
La création d'un nouveau client échoue car un champ obligatoire reçoit une valeur nulle.

## Champs obligatoires du modèle Client
D'après `lib/models/client.dart`, les champs **obligatoires** (required) sont :
- `id` (int)
- `nom` (String)
- `prenom` (String)
- `statut` (bool)
- `dateCreation` (DateTime)

## Logs ajoutés

### 1. Dans `lib/models/client.dart`
- **Constructeur** : Affiche toutes les valeurs reçues lors de la création d'un objet Client
- **fromJson()** : Affiche le JSON reçu et chaque champ individuellement avec son type

### 2. Dans `lib/services/api_service.dart`
- **createClient()** : Affiche les données envoyées à l'API et la réponse reçue

### 3. Dans `lib/ui/screens/caissier/create_client_screen.dart`
- **_saveClient()** : Affiche toutes les données du formulaire avant l'envoi
- **_searchClients()** : Affiche les résultats de recherche
- **_selectClientFromSearch()** : Affiche les conversions de données

### 4. Dans `lib/ui/screens/caissier/payment_screen.dart`
- **_showLoyaltyDialog()** : Affiche le client reçu après création

## Comment voir les logs

### Option 1 : Lancer l'app depuis VS Code
1. Ouvrez le terminal dans VS Code
2. Lancez : `flutter run`
3. Ouvrez la console "Debug Console" pour voir les logs

### Option 2 : Lancer l'app depuis la ligne de commande
```bash
flutter run --verbose
```

### Option 3 : Voir les logs d'un appareil connecté
```bash
# Pour Android
adb logcat | findstr "flutter"

# Pour iOS
idevicesyslog | findstr "flutter"
```

## Scénario de test
1. Lancez l'application
2. Allez dans l'écran de paiement
3. Cliquez sur "Ajouter un client" ou le bouton pour créer un client
4. Remplissez le formulaire avec :
   - Nom : Test
   - Prénom : Client
   - (Les autres champs sont optionnels)
5. Cliquez sur "Enregistrer"
6. Observez les logs dans la console

## Logs attendus (dans l'ordre)

```
=== DEBUT CREATION CLIENT ===
Formulaire validé avec succès
Utilisateur actuel: [nom de l'utilisateur]
Site ID: [id du site]
Données du client à créer:
  - Nom: Test
  - Prénom: Client
  - Email: null
  - Téléphone: null
  ...
Envoi de la requête API...

=== API_SERVICE.createClient ===
URL: [url de l'API]
Données client envoyées: {...}
Données JSON encodées: {...}
Envoi de la requête POST...
Réponse reçue: {...}
================================

=== CLIENT.fromJson ===
JSON reçu: {...}
Valeurs individuelles:
  - id: [valeur] ([type])
  - nom: [valeur] ([type])
  - prenom: [valeur] ([type])
  - statut: [valeur] ([type])
  - dateCreation: [valeur] ([type])
  ...

=== CONSTRUCTEUR CLIENT ===
Client créé avec:
  - id: [valeur]
  - nom: [valeur]
  - prenom: [valeur]
  ...
===========================

Client créé avec succès:
  - ID: [id]
  - Nom complet: [nom] [prenom]
  ...
=== FIN CREATION CLIENT (SUCCES) ===
```

## Si une erreur se produit

Les logs afficheront :
```
=== ERREUR [NOM_METHODE] ===
Erreur: [message d'erreur]
Stack trace: [trace complète]
===============================
```

Cherchez particulièrement :
- **"Required value was null"** : Un champ obligatoire est null
- **"type 'Null' is not a subtype of type"** : Un champ reçoit null au lieu d'une valeur
- Le nom du champ qui pose problème sera dans le message d'erreur

## Solution appliquée

Le problème était que l'API retourne `idClient` (String) au lieu de `id` (num).

**Correction dans `lib/ui/screens/caissier/create_client_screen.dart`** :

Après avoir reçu la réponse de l'API, nous convertissons maintenant :
1. `idClient` → `id` (String vers int)
2. Vérification que `dateCreation` existe
3. Vérification que `statut` est un bool
4. Gestion de `dateNaissance` null

Le code ajouté (lignes ~260-285) :
```dart
// Convertir idClient en id si nécessaire
if (response.containsKey('idClient') && !response.containsKey('id')) {
  final idClientValue = response['idClient'];
  if (idClientValue is String) {
    response['id'] = int.parse(idClientValue);
  } else if (idClientValue is num) {
    response['id'] = idClientValue.toInt();
  }
}

// S'assurer que dateCreation est présent
if (!response.containsKey('dateCreation') || response['dateCreation'] == null) {
  response['dateCreation'] = DateTime.now().toIso8601String();
}

// S'assurer que statut est un bool
if (response.containsKey('statut') && response['statut'] is! bool) {
  final statutValue = response['statut'];
  if (statutValue is String) {
    response['statut'] = statutValue.toLowerCase() == 'true' || statutValue == '1';
  } else if (statutValue is int) {
    response['statut'] = statutValue == 1;
  }
}
```

## Solution probable

Si le problème vient de `dateCreation`, vérifiez que l'API retourne bien ce champ.
Si l'API ne retourne pas `dateCreation`, modifiez `create_client_screen.dart` ligne 259 pour ajouter :

```dart
// Après avoir reçu la réponse de l'API
if (!response.containsKey('dateCreation')) {
  response['dateCreation'] = DateTime.now().toIso8601String();
}
```

Si le problème vient de `id`, l'API doit retourner l'ID du client créé.
