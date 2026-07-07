# 🔗 Relier votre projet Flutter à votre projet Firebase "Bongolava-Guide-IA"

Ceci doit être fait **sur votre ordinateur**, dans un terminal, car ça nécessite
votre compte Google connecté. Je ne peux pas le faire à votre place depuis ici,
mais voici exactement quoi taper, étape par étape.

## ⚠️ Constat important sur votre projet actuel

Le dossier que vous m'avez envoyé contient seulement `main.dart`,
`bongolava_chat_page.dart`, `pubspec.yaml` — il **manque les dossiers
`android/` et `ios/`**. Un vrai projet Flutter en a besoin pour se compiler.
Vérifiez d'abord si votre projet complet (sur votre PC) contient bien ces
dossiers. S'ils n'existent pas :

```bash
cd chemin/vers/bongolava_ai
flutter create . 
```

Cette commande complète un projet existant sans toucher à votre `lib/`.

## Étape 1 — Installer les outils nécessaires

```bash
# CLI Firebase (si pas déjà fait)
npm install -g firebase-tools
firebase login

# CLI FlutterFire
dart pub global activate flutterfire_cli
```

## Étape 2 — Lancer la configuration automatique

Depuis la racine de votre projet Flutter (là où se trouve `pubspec.yaml`) :

```bash
flutterfire configure --project=bongolava-guide-ia
```

- `bongolava-guide-ia` est l'identifiant de votre projet Firebase (visible dans
  l'URL de la console : `.../project/bongolava-guide-ia/...`).
- La commande va lister vos plateformes (Android, iOS, Web...) : cochez au
  minimum **Android**.
- Elle détectera l'app déjà enregistrée `com.ruphin.bongolava_ai` (visible sur
  votre capture d'écran) ou vous proposera d'en créer une nouvelle.
- Elle génère automatiquement **`lib/firebase_options.dart`** avec les vraies
  clés — remplacez le fichier modèle que je vous ai fourni par celui-ci.
- Elle télécharge aussi `android/app/google-services.json` automatiquement.

## Étape 3 — Vérifier la cohérence du nom de package

⚠️ J'ai remarqué une incohérence :
- Dans Firebase Console (capture d'écran) : `com.ruphin.bongolava_ai`
- Dans votre ancien README : `com.ruphinhenri.bongolava_ai`

Le `applicationId` dans `android/app/build.gradle` **doit être identique** au
package enregistré dans Firebase, sinon `google-services.json` ne
correspondra à aucune app et l'initialisation échouera. Choisissez-en un
(ex. `com.ruphin.bongolava_ai`, déjà enregistré) et utilisez-le partout.

## Étape 4 — Configuration Gradle (si `flutterfire configure` ne l'a pas fait)

Dans `android/build.gradle` :
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
}
```

Dans `android/app/build.gradle` :
```gradle
apply plugin: 'com.google.gms.google-services'

android {
    defaultConfig {
        applicationId "com.ruphin.bongolava_ai"
        minSdkVersion 23   // Firebase AI (Gemini) exige au minimum API 23
    }
}
```

## Étape 5 — Activer Firebase AI Logic / Gemini côté Firebase

Vous l'avez déjà fait (capture d'écran "Firebase AI Logic"). Vérifiez juste :
- Le **Billing (facturation)** est activé sur le projet Google Cloud lié
  (obligatoire pour Gemini via Firebase AI, même en usage gratuit limité).
- Le modèle `gemini-2.5-flash-preview-image-generation` est bien disponible
  dans votre région/quota — sinon utilisez `gemini-2.5-flash` sans génération
  d'image si besoin.

## Étape 6 — Installer et lancer

```bash
flutter pub get
flutter run
```

Si tout est bien relié, l'app doit démarrer sans erreur `Firebase
initialization` et le chat doit répondre.

---

### Résumé express

1. `flutterfire configure --project=bongolava-guide-ia`
2. Remplacer `lib/firebase_options.dart` par celui généré
3. Aligner `applicationId` Android avec le package Firebase
4. `flutter pub get && flutter run`
