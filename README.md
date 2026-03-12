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

### Recommandation V1 (native Apple)
Utiliser **ImageIO + UniformTypeIdentifiers**:
- lecture : `CGImageSourceCreateWithURL`
- écriture : `CGImageDestinationCreateWithURL(..., UTType.webP.identifier, ...)`
- qualité : `kCGImageDestinationLossyCompressionQuality`

**Avantages**:
- 100% natif Apple (pas de dépendance externe).
- Intégration simple avec SwiftUI/AppKit.
- Suffisant pour une V1 fiable et rapide à maintenir.

### Alternative avancée (si besoin futur)
Passer à `libwebp` (via SPM/C wrapper) si vous avez besoin de:
- réglages encodeur très fins (preset, near-lossless, effort, alpha options, etc.)
- performances ou contrôle strict du ratio qualité/taille au-delà d’ImageIO.

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
