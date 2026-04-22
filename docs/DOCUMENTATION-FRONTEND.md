# Documentation API Mombongo - Guide d'Intégration Frontend

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Configuration de base](#configuration-de-base)
3. [Authentification](#authentification)
4. [Endpoints principaux](#endpoints-principaux)
5. [Modèles de données](#modèles-de-données)
6. [Gestion des erreurs](#gestion-des-erreurs)
7. [Exemples d'intégration](#exemples-dintégration)
8. [Bonnes pratiques](#bonnes-pratiques)

---

## 🎯 Vue d'ensemble

L'API Mombongo est une API RESTful construite avec ASP.NET Core 6.0 qui gère les opérations de vente, les stocks, les clients et les paiements pour l'application Mombongo.

### 🔧 Stack Technique
- **Framework**: ASP.NET Core 6.0
- **Base de données**: MySQL 8.0
- **Authentification**: JWT Bearer Token
- **Sérialisation**: JSON (camelCase)
- **Rate Limiting**: Configuré par endpoint
- **Compression**: Brotli/Gzip activé

### 🌐 URLs de l'API
- **Développement**: `http://192.168.43.233:5001` ou `https://192.168.43.233:7001`
- **Production**: `https://mombongo.asdc-rdc.org`
- **Documentation Swagger**: `/swagger` (dev) ou `/api-docs` (prod)

---

## ⚙️ Configuration de base

### Headers requis

```javascript
const headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json'
};

// Pour les endpoints protégés
const authHeaders = {
  ...headers,
  'Authorization': `Bearer ${token}`
};
```

### Configuration CORS

L'API est configurée pour accepter les requêtes depuis:
- `https://mombongov2.asdc-rdc.org`
- `https://mombongo.kansaconsulting.com`
- En développement: toutes les origines sont autorisées

---

## 🔐 Authentification

### Flow d'authentification

1. **Login**: Obtenir un token JWT
2. **Stockage**: Sauvegarder le token localement
3. **Utilisation**: Inclure le token dans les headers des requêtes protégées

### Endpoint de connexion

```http
POST /api/Utilisateurs/authentifier
```

**Corps de la requête:**
```json
{
  "email": "utilisateur@example.com",
  "motDePasse": "password123"
}
```

**Réponse réussie:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "string",
  "expiration": "2024-01-27T10:30:00Z",
  "utilisateur": {
    "id": 1,
    "nom": "Nom",
    "prenom": "Prénom",
    "email": "utilisateur@example.com",
    "roles": ["Caissier"]
  }
}
```

### Exemple d'implémentation (JavaScript)

```javascript
class AuthService {
  constructor() {
    this.token = localStorage.getItem('token');
    this.refreshToken = localStorage.getItem('refreshToken');
  }

  async login(email, password) {
    try {
      const response = await fetch('/api/Utilisateurs/authentifier', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, motDePasse: password })
      });

      if (!response.ok) {
        throw new Error('Échec de l\'authentification');
      }

      const data = await response.json();
      this.token = data.token;
      this.refreshToken = data.refreshToken;
      
      localStorage.setItem('token', this.token);
      localStorage.setItem('refreshToken', this.refreshToken);
      
      return data;
    } catch (error) {
      console.error('Erreur de connexion:', error);
      throw error;
    }
  }

  getAuthHeaders() {
    return this.token ? {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json'
    } : {
      'Content-Type': 'application/json'
    };
  }

  logout() {
    this.token = null;
    this.refreshToken = null;
    localStorage.removeItem('token');
    localStorage.removeItem('refreshToken');
  }
}
```

---

## 🚀 Endpoints principaux

### 1. Gestion des Ventes

#### Enregistrer une vente
```http
POST /api/Vente/enregistrer
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "nom": "Jean",
  "prenom": "Dupont",
  "genre": "M",
  "email": "jean.dupont@example.com",
  "telephone": "+243123456789",
  "idSite": 1,
  "province": "Kinshasa",
  "ville": "Kinshasa",
  "commune": "Lukunga",
  "idUtilisateur": 5,
  "dateCommande": "2024-01-27T10:30:00Z",
  "statutCommande": "En cours",
  "datePaiement": "2024-01-27T10:30:00Z",
  "modePaiement": "Mobile Money",
  "montant": 150.50,
  "referencePaiement": "MP-123456",
  "statutPaiement": "Payé",
  "lignesCommandes": [
    {
      "idStock": 10,
      "quantite": 2,
      "prixUnitaire": 75.25,
      "tva": 0,
      "remise": 0
    }
  ]
}
```

### 2. Gestion des Articles

#### Lister tous les articles
```http
GET /api/Articles
Authorization: Bearer {token}
```

#### Détails d'un article
```http
GET /api/Articles/{id}
Authorization: Bearer {token}
```

#### Articles par société (avec pagination et recherche)
```http
GET /api/Articles/societe/{idSociete}?page=1&pageSize=20&sortField=libelle&sortOrder=asc&search=term&withStock=true
Authorization: Bearer {token}
```

**Paramètres de requête:**
- `page`: Numéro de page (défaut: 1)
- `pageSize`: Taille de page (défaut: 20)
- `sortField`: Champ de tri (libelle, datecreation, withstock)
- `sortOrder`: Ordre de tri (asc, desc)
- `search`: Terme de recherche (libelle ou code barre)
- `withStock`: Filtre sur la gestion de stock (true/false)

### 3. Gestion des Stocks

#### Lister tous les stocks
```http
GET /api/Stocks
Authorization: Bearer {token}
```

#### Détails d'un stock
```http
GET /api/Stocks/{id}
Authorization: Bearer {token}
```

#### Stock par article
```http
GET /api/Stocks/article/{idArticle}
Authorization: Bearer {token}
```

#### Stocks avec/sans gestion de stock
```http
GET /api/Stocks/with-stock/{withStock}
Authorization: Bearer {token}
```

#### Stocks par site et type de gestion
```http
GET /api/Stocks/site/{idSite}/with-stock/{withStock}
Authorization: Bearer {token}
```

#### Stocks par site (vue optimisée)
```http
GET /api/V_StockArticleSite/par-site/{idSite}
Authorization: Bearer {token}
```

#### Créer un stock
```http
POST /api/Stocks
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "idArticle": 5,
  "idSite": 1,
  "quantite": 100,
  "quantiteMin": 10,
  "prixUnitaire": 75.50,
  "dateCreation": "2024-01-27T10:30:00Z"
}
```

#### Mettre à jour un stock
```http
PUT /api/Stocks/{id}
Authorization: Bearer {token}
```

### 4. Gestion des Clients

#### Lister tous les clients
```http
GET /api/Clients
Authorization: Bearer {token}
```

#### Détails d'un client
```http
GET /api/Clients/{id}
Authorization: Bearer {token}
```

#### Rechercher des clients
```http
GET /api/Clients/search?email=example@email.com&nom=NomClient
Authorization: Bearer {token}
```

#### Créer un client
```http
POST /api/Clients
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "nom": "Dupont",
  "prenom": "Jean",
  "genre": "M",
  "email": "jean.dupont@example.com",
  "telephone": "+243123456789",
  "dateNaissance": "1990-01-01",
  "pieceIdentite": "AB123456",
  "statut": true,
  "idSite": 1
}
```

#### Mettre à jour un client
```http
PUT /api/Clients/{id}
Authorization: Bearer {token}
```

#### Supprimer un client
```http
DELETE /api/Clients/{id}
Authorization: Bearer {token}
```

### 5. Gestion des Paiements

#### Lister tous les paiements
```http
GET /api/Paiements
Authorization: Bearer {token}
```

#### Détails d'un paiement
```http
GET /api/Paiements/{id}
Authorization: Bearer {token}
```

#### Rechercher des paiements
```http
GET /api/Paiements/search?idCommande=5&statut=Payé
Authorization: Bearer {token}
```

#### Paiements par société
```http
GET /api/Paiements/societe/{idSociete}
Authorization: Bearer {token}
```

#### Historique des paiements (vue détaillée)
```http
GET /api/V_Paiement
Authorization: Bearer {token}
```

#### Enregistrer un paiement
```http
POST /api/Paiements
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "idCommande": 15,
  "datePaiement": "2024-01-27T10:30:00Z",
  "modePaiement": "Mobile Money",
  "montant": 150.50,
  "referencePaiement": "MP-123456",
  "statutPaiement": "Payé",
  "libellePaiement": "Paiement commande #15"
}
```

#### Mettre à jour un paiement
```http
PUT /api/Paiements/{id}
Authorization: Bearer {token}
```

### 6. Gestion des Sites

#### Lister tous les sites actifs
```http
GET /api/Sites
Authorization: Bearer {token}
```

#### Sites par société
```http
GET /api/Sites/societe/{idSociete}
Authorization: Bearer {token}
```

#### Détails d'un site
```http
GET /api/Sites/{id}
Authorization: Bearer {token}
```

### 7. Gestion des Notifications

#### Lister toutes les notifications
```http
GET /api/Notifications?type=Info&priorite=Haute
Authorization: Bearer {token}
```

#### Notifications par utilisateur
```http
GET /api/Notifications/utilisateur/{idUtilisateur}?nonLusSeulement=true
Authorization: Bearer {token}
```

#### Marquer une notification comme lue
```http
PUT /api/Notifications/{id}/marquer-lu
Authorization: Bearer {token}
```

#### Créer une notification
```http
POST /api/Notifications
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "idUtilisateur": 5,
  "titre": "Nouvelle vente enregistrée",
  "message": "Une vente de 150.50 $ a été enregistrée",
  "type": "Info",
  "priorite": "Normale",
  "dateCreation": "2024-01-27T10:30:00Z",
  "lu": false
}
```

### 8. Gestion des Utilisateurs

#### Authentification
```http
POST /api/Utilisateurs/authentifier
```

#### Mettre à jour le statut d'un utilisateur
```http
PUT /api/Utilisateurs/{id}/statut
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
true  // pour activer, false pour désactiver
```

#### Changer le mot de passe
```http
POST /api/Utilisateurs/changer-mot-de-passe
Authorization: Bearer {token}
```

**Corps de la requête:**
```json
{
  "ancienMotDePasse": "oldPassword123",
  "nouveauMotDePasse": "newPassword456"
}
```

---

## 📊 Modèles de données

### Utilisateur
```typescript
interface Utilisateur {
  id: number;
  nom: string;
  prenom: string;
  email: string;
  telephone?: string;
  statut: boolean;
  dateCreation: string;
  dateLastModification?: string;
  roles: string[];
}
```

### Article
```typescript
interface Article {
  id: number;
  reference: string;
  designation: string;
  description?: string;
  prixUnitaire: number;
  tva: number;
  statut: boolean;
  idCategorie: number;
  idUniteMesure: number;
  dateCreation: string;
}
```

### Client
```typescript
interface Client {
  id: number;
  nom: string;
  prenom: string;
  genre?: string;
  email?: string;
  telephone?: string;
  dateNaissance?: string;
  pieceIdentite?: string;
  statut: boolean;
  dateCreation: string;
}
```

### Vente
```typescript
interface Vente {
  id: number;
  idClient: number;
  idUtilisateur: number;
  dateCommande: string;
  statutCommande: string;
  montantTotal: number;
  reference: string;
  lignesCommandes: LigneCommande[];
}
```

### LigneCommande
```typescript
interface LigneCommande {
  id: number;
  idCommande: number;
  idStock: number;
  quantite: number;
  prixUnitaire: number;
  tva: number;
  remise: number;
  montantTotal: number;
}
```

---

## ⚠️ Gestion des erreurs

### Format des réponses d'erreur

```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "Email": ["L'email est requis"],
    "Montant": ["Le montant doit être supérieur à 0"]
  }
}
```

### Codes d'erreur courants

- **400**: Bad Request - Validation échouée
- **401**: Unauthorized - Token invalide ou expiré
- **403**: Forbidden - Permissions insuffisantes
- **404**: Not Found - Ressource non trouvée
- **429**: Too Many Requests - Rate limit dépassé
- **500**: Internal Server Error - Erreur serveur

### Gestion du token expiré

```javascript
async function apiCall(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: authService.getAuthHeaders()
  });

  if (response.status === 401) {
    // Token expiré, tentative de rafraîchissement
    try {
      await authService.refreshToken();
      // Réessayer avec le nouveau token
      return fetch(url, {
        ...options,
        headers: authService.getAuthHeaders()
      });
    } catch (refreshError) {
      // Échec du rafraîchissement, déconnexion
      authService.logout();
      window.location.href = '/login';
      throw new Error('Session expirée');
    }
  }

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.title || 'Erreur serveur');
  }

  return response.json();
}
```

---

## 💡 Exemples d'intégration

### Service API complet (JavaScript)

```javascript
class MombongoAPI {
  constructor() {
    this.baseURL = process.env.REACT_APP_API_URL || 'https://mombongo.asdc-rdc.org';
    this.authService = new AuthService();
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: this.authService.getAuthHeaders(),
      ...options
    };

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        if (response.status === 401) {
          await this.handleUnauthorized();
        }
        const error = await response.json();
        throw new Error(error.title || 'Erreur API');
      }

      return await response.json();
    } catch (error) {
      console.error(`Erreur API ${endpoint}:`, error);
      throw error;
    }
  }

  async handleUnauthorized() {
    try {
      await this.authService.refreshToken();
    } catch (error) {
      this.authService.logout();
      window.location.href = '/login';
      throw new Error('Session expirée');
    }
  }

  // Ventes
  async enregistrerVente(venteData) {
    return this.request('/api/Vente/enregistrer', {
      method: 'POST',
      body: JSON.stringify(venteData)
    });
  }

  async getVentes() {
    return this.request('/api/Vente');
  }

  // Articles
  async getArticles() {
    return this.request('/api/Articles');
  }

  async getArticle(id) {
    return this.request(`/api/Articles/${id}`);
  }

  // Stocks
  async getStocksParSite(idSite) {
    return this.request(`/api/V_StockArticleSite/par-site/${idSite}`);
  }

  // Clients
  async getClients() {
    return this.request('/api/Clients');
  }

  async createClient(clientData) {
    return this.request('/api/Clients', {
      method: 'POST',
      body: JSON.stringify(clientData)
    });
  }

  // Paiements
  async getPaiements() {
    return this.request('/api/V_Paiement');
  }

  async createPaiement(paiementData) {
    return this.request('/api/Paiements', {
      method: 'POST',
      body: JSON.stringify(paiementData)
    });
  }
}
```

### Hook React pour les appels API

```javascript
import { useState, useEffect } from 'react';
import { MombongoAPI } from './api';

export function useAPI() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const api = new MombongoAPI();

  const execute = async (apiCall, ...args) => {
    try {
      setLoading(true);
      setError(null);
      const result = await apiCall(...args);
      return result;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return { execute, loading, error };
}

// Utilisation
export function VentesPage() {
  const { execute, loading, error } = useAPI();
  const [ventes, setVentes] = useState([]);

  useEffect(() => {
    const loadVentes = async () => {
      try {
        const data = await execute(api.getVentes);
        setVentes(data);
      } catch (err) {
        console.error('Erreur chargement ventes:', err);
      }
    };

    loadVentes();
  }, []);

  const handleEnregistrerVente = async (venteData) => {
    try {
      await execute(api.enregistrerVente, venteData);
      // Recharger la liste
      const data = await api.getVentes();
      setVentes(data);
    } catch (err) {
      console.error('Erreur enregistrement vente:', err);
    }
  };

  return (
    <div>
      {loading && <div>Chargement...</div>}
      {error && <div className="error">{error}</div>}
      {/* Interface utilisateur */}
    </div>
  );
}
```

---

## 📋 Bonnes pratiques

### 1. Gestion des tokens
- Toujours vérifier l'expiration du token
- Implémenter un mécanisme de rafraîchissement automatique
- Stocker les tokens de manière sécurisée (localStorage ou httpOnly cookies)

### 2. Gestion des erreurs
- Intercepter et logger toutes les erreurs
- Afficher des messages utilisateur clairs
- Implémenter un retry automatique pour les erreurs réseau

### 3. Performance
- Utiliser la pagination pour les listes importantes
- Implémenter du caching côté client
- Compresser les payloads quand possible

### 4. Sécurité
- Ne jamais stocker de mots de passe côté client
- Valider les données côté client avant envoi
- Utiliser HTTPS en production

### 5. Rate Limiting
L'API implémente des limites de requêtes:
- **Général**: 10 req/s, 100 req/min, 1000 req/h, 5000 req/j
- **Authentification**: 5 req/min, 20 req/h
- **Paiements**: 10 req/min, 100 req/h

### 6. Monitoring
- Surveiller les temps de réponse
- Tracker les taux d'erreur
- Logger les requêtes importantes

---

## 🔧 Débogage

### Outils de développement
1. **Swagger UI**: `/swagger` (dev) ou `/api-docs` (prod)
2. **Logs**: Consultez les logs applicatifs pour les erreurs détaillées
3. **Network Tab**: Utilisez les outils de développement du navigateur

### Tests de connexion
```bash
# Test de santé de l'API
curl -X GET https://mombongo.asdc-rdc.org/api/health

# Test d'authentification
curl -X POST https://mombongo.asdc-rdc.org/api/Utilisateurs/authentifier \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","motDePasse":"password"}'
```

---

## 📞 Support

Pour toute question ou problème d'intégration:
- **Email**: dev@kansaconsulting.com
- **Documentation**: Swagger UI disponible sur l'API
- **Logs**: Consultez les logs applicatifs pour les erreurs détaillées

---

*Cette documentation est mise à jour régulièrement. Dernière mise à jour: 27 janvier 2026*
