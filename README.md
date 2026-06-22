# DataXpress Mobile

Application mobile Flutter connectée à GLPI pour la gestion des interventions techniques.

## Fonctionnalités

### Technicien
- Authentification via API GLPI
- Voir et gérer les tickets assignés
- Prendre en charge et marquer résolu
- Tracking GPS en temps réel
- Faire signer le client après intervention
- Changement de statut des tickets

### Superviseur
- Voir les positions des techniciens en temps réel
- Consulter les tickets fermés
- Voir les signatures des clients

### Client
- Signer le document d'intervention sur l'écran du technicien

---

## Stack technique

| Technologie | Usage |
|---|---|
| Flutter | Framework mobile |
| Dart | Langage |
| GLPI REST API | Backend |
| Docker | Hébergement GLPI |
| flutter_map | Carte OpenStreetMap |
| geolocator | GPS |
| signature | Zone de signature |
| shared_preferences | Stockage local |
| http | Appels API |

---

## Installation

### Prerequis
- Flutter SDK >= 3.0.0
- Android Studio ou VS Code
- Docker pour GLPI

### Lancer GLPI avec Docker

```bash
docker-compose up -d
```

### Configurer l'API

Dans `lib/services/glpi_services.dart` :

```dart
static const String baseUrl = 'http://TON_IP:8080/apirest.php';
static const String appToken = 'TON_APP_TOKEN';
```

### Lancer l'application

```bash
flutter pub get
flutter run
```

---

## Structure du projet
---

## Utilisateurs de test

| Role | Username | Mot de passe |
|---|---|---|
| Technicien | tech1 | 1234 |
| Technicien | tech2 | 0000|
| Superviseur | supervisor1 | 1111 |

---

## Auteur

Projet realise dans le cadre d'un stage

---

## Licence

MIT License