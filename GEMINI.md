# Instructions du Projet Voxelands

## Exécutable Godot 4.x
- **Chemin exact de l'exécutable console Windows** :
  `C:\Users\re_wa\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- **Commande de validation headless** :
  `& "C:\Users\re_wa\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --quit`

## Règles Fondamentales du Projet
1. **Projet** : Jeu d'aventure/RPG voxel en monde ouvert, application native (pas de navigateur), inspiré des RPG d'exploration voxel, avec son propre nom ("Voxelands") et son style propre. Aucun asset, nom ou code copié.
2. **Moteur** : Godot 4.x, langage GDScript exclusivement.
3. **Zéro asset externe** : Modèles, textures, particules et sons sont tous générés par code (couleurs par vertex, cubes procéduraux, ArrayMesh / SurfaceTool, AudioStreamGenerator).
4. **Organisation de l'arborescence** :
   - Scripts dans `res://scripts/` avec sous-dossiers :
     - `res://scripts/world/`
     - `res://scripts/player/`
     - `res://scripts/enemies/`
     - `res://scripts/items/`
     - `res://scripts/ui/`
   - Scènes dans `res://scenes/`
5. **Autonomie de création** : Créer et modifier soi-même l'intégralité des fichiers (`project.godot`, scènes `.tscn`, scripts `.gd`), sans demander à l'utilisateur de le faire manuellement.
6. **Contrôle d'erreurs systématique** : Après chaque modification, tester avec l'exécutable Godot console en mode headless (`--headless --path . --quit`) et corriger les erreurs avant d'enchaîner.
7. **Conventions de code** :
   - Commentaires en français.
   - Noms de variables, fonctions et classes en anglais.
8. **Feuille de route** : Mettre à jour `ROADMAP.md` à chaque étape franchie.
9. **Templates d'export** : Ne télécharger les export templates qu'à l'étape finale d'export.
