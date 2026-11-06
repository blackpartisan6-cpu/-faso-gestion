# Faso Gestion — MVP Flutter

Application de gestion d'une alimentation au Burkina Faso (FCFA/XOF).

## Fonctionnalités présentes
- Tableau de bord (ventes, bénéfice brut, dépenses, alertes de stock)
- Catalogue produits : création, modification, recherche et seuil d'alerte
- Enregistrement des ventes avec déduction automatique du stock
- Modes de paiement proposés : espèces, Orange Money, Moov Money, Coris Money, crédit
- Dépenses
- Répertoire clients et fournisseurs
- Base SQLite locale : fonctionnement sans Internet

## Lancer le projet
1. Installer Flutter et Android Studio (pour compiler Android).
2. Dans ce dossier, exécuter `flutter pub get`.
3. Pour Android : `flutter run` ou `flutter build apk --release`.
4. Pour iPhone : sur un Mac avec Xcode, exécuter `flutter build ipa --release`.
   La compilation iOS et la publication App Store nécessitent macOS/Xcode et un compte Apple Developer.

## Important — limites de cette première version
Ceci est un MVP fonctionnel de départ, pas encore une version prête pour une exploitation commerciale multi-utilisateurs.
Les données restent sur l'appareil. Il manque encore : authentification et rôles sécurisés, synchronisation cloud multi-appareils, sauvegarde/export, tickets imprimables, gestion détaillée des achats/retours/crédits, tests et durcissement.
Les paiements Mobile Money sont des modes de suivi manuel ici : aucun paiement réel n'est encaissé par l'application.
Avant utilisation réelle, tester les calculs, sauvegarder les données et faire vérifier le projet.
