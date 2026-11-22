# BLASTI Mobile

App mobile Expo iOS/Android pour BLASTI. Interface tounsi, recherche départ/arrivée, carte avec places libres, compte passager/chauffeur, billets QR, scan de montée et libération du siège quand le chauffeur indique une descente.

## Ouvrir sur un téléphone

1. Installe Node.js (npm est inclus).
2. Dans PowerShell, va dans `mobile` puis exécute :

   ```powershell
   & 'C:\Program Files\nodejs\npm.cmd' install
   & 'C:\Program Files\nodejs\npm.cmd' start
   ```

3. Installe **Expo Go** sur iPhone ou Android et scanne le QR code du terminal. Le téléphone et le PC doivent être sur le même Wi-Fi.

La carte native et le scan QR fonctionnent avec Expo Go. Pour la démo, choisis « Dkhol k mousfer demo » ou « Dkhol k chauffeur demo ». Les données de démonstration restent sur ce téléphone et ne sont pas partagées.

## Synchronisation multi-téléphone

Pour voir les réservations et places changer immédiatement sur plusieurs appareils, crée un projet Supabase dédié à BLASTI. Copie `.env.example` vers `.env`, mets l’URL et la clé publique/publishable du projet, puis redémarre Expo. N’utilise jamais la clé `service_role` dans l’application.

Applique dans l’ordre les migrations du dossier `../supabase/migrations/` à l’aide du SQL Editor Supabase. Ajoute ensuite les comptes chauffeurs via un processus administratif de confiance et crée leur véhicule actif en lui assignant `operator_id`. Un nouvel utilisateur public ne peut créer qu’un compte passager. La liste live, le scan, la libération des sièges et les notifications de changement nécessitent la connexion Internet.

Les lieux et tracés de la démo sont des coordonnées approximatives autour de Sousse, pas une navigation GPS précise. Les horaires et tarifs d’exemple ne représentent pas des départs confirmés.
