# WebP Converter Mac (SwiftUI)

V1 d’une application macOS native SwiftUI pour convertir des images PNG/JPG/JPEG/HEIC en WEBP, avec conversion par lot et redimensionnement optionnel.

## 1) Architecture proposée

Architecture en couches simple et maintenable:

- **UI (SwiftUI Views)**
  - `ContentView` : interface, drag & drop, tableau des fichiers, réglages.
- **ViewModel (state + orchestration)**
  - `ConversionViewModel` : état global, progression, statut par fichier, appels asynchrones aux services.
- **Services (métier / I/O)**
  - `ImageConversionService` : chargement image, redimensionnement, encodage WEBP.
  - `FileService` : sélection fichiers/dossier, validation extensions, tailles de fichiers.
- **Models**
  - `ConversionSettings`, `ResizeSettings`, `FileConversionItem`, `FileConversionStatus`.

## 2) Stratégie recommandée pour encoder du WEBP sur macOS

### Stratégie d'encodage WEBP (V1 robuste)
- **Essai natif** : ImageIO (`CGImageDestination` + `UTType.webP`) quand le type est réellement annoncé par le système (`CGImageDestinationCopyTypeIdentifiers`).
- **Fallback automatique** : si le support natif est absent (ou échoue au runtime), l'application utilise l'encodeur `cwebp` s'il est installé (`/opt/homebrew/bin/cwebp`, `/usr/local/bin/cwebp`).
- **Erreurs explicites** : message utilisateur clair si aucun encodeur WEBP n'est disponible.

Cette approche reste macOS-native côté UI/flux, tout en étant fiable sur des machines où l'export WEBP ImageIO est indisponible.

## 3) V1 implémentée

Fonctionnalités livrées:
- Sélection multi-fichiers (OpenPanel).
- Drag & drop de fichiers.
- Conversion par lot.
- Poids avant / après conversion.
- Réglage qualité WEBP.
- Redimensionnement:
  - taille originale,
  - pourcentage,
  - largeur,
  - hauteur,
  - conservation des proportions.
- Choix du dossier de sortie.
- Progression globale.
- Statut individuel par fichier (attente, en cours, succès, erreur).
- Erreurs explicites en UI.
- Conversion asynchrone avec `Task.detached` pour ne pas bloquer l’UI.

## Lancer le projet

```bash
swift run
```

> Nécessite macOS (SwiftUI + AppKit + ImageIO WebP).
