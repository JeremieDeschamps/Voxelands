# 🌍 Voxelands

**Voxelands** est un jeu d'aventure et RPG d'action en monde ouvert voxel infini, développé de zéro sous **Godot 4.x** exclusivement en **GDScript**.

Le projet repose sur une règle stricte d'ingénierie : **zéro asset externe**. Tous les modèles 3D, animations, textures, particules, sons d'effets et musiques d'ambiance sont générés **intégralement par code** en temps réel.

---

## ✨ Fonctionnalités Majeures

### 1. 🌐 Moteur Voxel Infini & Optimisations
- **Génération multithreadée asynchrone** par chunks de 16x16x128 blocs via `WorkerThreadPool` sans ralentissement.
- **Culling des faces internes cachées** entre blocs adjacents (`SurfaceTool` et `ArrayMesh`).
- **Niveau de détail (LOD)** : les chunks distants (> 2 chunks) allègent le calcul d'Ambient Occlusion (AO) et désactivent la génération physique superflue.
- **Rendu GPU par instanciation (`MultiMeshInstance3D`)** pour tout le décor de surface (fleurs, herbes, buissons), réduisant drastiquement le nombre de draw calls.
- **Collisions 3D solides** via `ConcavePolygonShape3D` autour du joueur et traversée fluide des herbes et fleurs.

### 2. 🌄 Biomes, Relief & Cycle Jour/Nuit
- **Génération par double bruit déterministe** (température et humidité via `FastNoiseLite`) et graine maîtresse reproductible (`world_seed`).
- **6 Biomes distincts** :
  - 🌿 **Prairie** : collines verdoyantes, chênes denses, herbes et fleurs colorées.
  - 🌲 **Forêt** : canopée ombragée, bouleaux et chênes touffus.
  - 🏜️ **Désert** : dunes de sable doré, grès, cactus géants et rochers arides.
  - ❄️ **Neige / Taïga** : toundra givrée et conifères aux aiguilles sombres.
  - 🏔️ **Montagnes** : falaises rocheuses escarpées et cimes enneigées.
  - 🌊 **Océans & Plages** : niveau de mer (y=32) avec eau limpide, mécanique de nage fluide et plages de sable.
- **Cycle Jour / Nuit dynamique** : rotation 360° du soleil et de la lune, dégradés d'horizon et zénith atmosphériques, ombres solaires dynamiques et modulation du brouillard.

### 3. ⚔️ Classes de Héros & Arbre de Talents
- **4 Classes jouables** sélectionnables au départ :
  - 🔴 **Guerrier** : Coup d'Épée, Tourbillon d'Acier, Cri de Guerre (+dégâts/résistance), Heurt Sismique.
  - 🟣 **Mage** : Projectile Arcanique, Boule de Feu Explosive, Nova de Givre (gel de zone), Éruption de Mana.
  - 🟢 **Rôdeur** : Flèche Voxel, Tir Perforant, Piège Voxel, Pluie de Flèches.
  - ⚫ **Voleur** : Coup de Dague critique, Danse des Lames, Pas de l'Ombre (téléportation), Bombe Fumigène.
- **Arbre de talents RPG** avec 5 branches spécialisées (Force Brute, Vitalité, Vigueur, Coups Critiques, Maîtrise des Sorts) accessible depuis l'inventaire (`I`).

### 4. 🐾 Compagnons Sauvages Apprivoisables (24 Espèces)
- Répartis sur tous les biomes : Chiens de berger, Ours, Sangliers, Fennecs, Scarabées dorés, Loups arctiques, Léopards des neiges, Griffons nains, Faucons, Tortues marines, Crabes géants...
- Apprivoisement de proximité via la touche `[F]`.
- IA de combat dédiée : suit le joueur, engage automatiquement les cibles hostiles avec bond offensif et jauge de vie dédiée sur le HUD.
- Ordres tactiques via la touche `[G]` (*Suivre* / *Rester sur place*).

### 5. 🏘️ Villages Procéduraux, PNJ & Quêtes
- Villages déterministes adaptés au biome (chaumières, maisons en adobe, chalets de rondins, forts de pierre, cabanes sur pilotis).
- Places centrales animées (puits, oasis, feux de camp monumentaux).
- PNJ amicaux avec tenues régionales et dialogues interactifs (`[F]`).
- Système de quêtes dynamiques (chasse aux monstres, exploration de donjons, découverte de trésors) avec récompenses d'XP et d'or.

### 6. 🗝️ Donjons Souterrains, Coffres & Boss Titanesque
- Entrées cryptiques en surface menant à des complexes souterrains de pierre.
- Coffres au trésor antiques avec ouverture animée (`[F]`) et butin rare garanti.
- Boss redoutable : **Gorgaroth le Titan Voxel**, équipé d'un marteau colossal, d'attaques sismiques de zone, d'invocations d'acolytes et d'une jauge de boss monumentale à l'écran.

### 7. 🎒 Objets, Équipement & Butin RPG
- Génération procédurale d'Armes, Armures et Anneaux.
- 4 niveaux de rareté : **Commun** (Blanc), **Rare** (Bleu), **Épique** (Violet), **Légendaire** (Or).
- Butins 3D scintillants au sol avec ramassage au contact.
- Panneau d'inventaire (`[I]`) complet avec comparaison dynamique des statistiques (+ / - / =).
- Échelonnage de la puissance des monstres selon la distance au point d'origine du monde.
- Sauvegarde et chargement automatique ou manuel via `user://save.json`.

### 8. 🗺️ Navigation & Repérage
- **Boussole 360° sur le HUD** indiquant le cap et les icônes de repérage :
  - 🏠 Village le plus proche
  - 💀 Donjon souterrain
  - 🐾 Compagnon actif
- **Carte du Monde interactive (`[M]`)** affichant le relief, les biomes colorés, la position du joueur et ses coordonnées GPS.

### 9. 🔊 Synthétiseur Audio 100% Procédural
- Conçu autour de `AudioStreamGenerator` en temps réel :
  - Bruits de pas selon la cadence de marche.
  - Sauts, atterrissages et battements d'ailes du planeur.
  - Sons de frappes d'armes blanches et détonations arcaniques.
  - Impacts de coups subis, bruits d'ouverture de coffres et gazouillis des compagnons.
  - Fanfare de passage de niveau.
  - Musique d'ambiance continue en harmoniques douces (Do, Sol, La mineur, Fa).

### 10. 🖥️ Menus & Réglages
- **Menu Principal** : Nouvelle Partie, Continuer (détection automatique de sauvegarde), Paramètres, Quitter.
- **Menu Pause (`[Échap]`)** : Reprendre, Sauvegarde manuelle instantanée, Paramètres, Écran Titre, Quitter.
- **Réglages graphiques et audio** : Distance de rendu (2 à 8 chunks), Volume principal (0 à 100%), Ombres dynamiques on/off, Brouillard on/off, Limite de framerate (60 FPS, 120 FPS, Illimité).

---

## 🎮 Commandes en Jeu

| Action | Clavier / Souris |
| :--- | :--- |
| **Se déplacer** | `Z` `Q` `S` `D` ou `W` `A` `S` `D` |
| **Sauter / Déployer le planeur en l'air** | `Espace` |
| **Courir (Sprint)** | `Shift Gauche` |
| **Orienter la caméra** | Déplacement de la `Souris` |
| **Zoom caméra** | `Molette Souris` |
| **Attaque de base** | `Clic Gauche` |
| **Compétence 1 (Spéciale / Zone)** | `Clic Droit` |
| **Compétence 2** | Touche `E` |
| **Compétence 3 (Ultime)** | Touche `R` |
| **Interagir (Apprivoiser / PNJ / Coffre)** | Touche `F` |
| **Ordre au compagnon (Suivre / Rester)** | Touche `G` |
| **Inventaire & Arbre de talents** | Touche `I` |
| **Carte du monde** | Touche `M` |
| **Fermer interface / Menu Pause** | Touche `Échap` |

---

## 🏗️ Structure du Projet

```
Z:/
├── export_presets.cfg         # Préréglage officiel d'exportation Windows Desktop
├── project.godot              # Configuration Godot 4
├── ROADMAP.md                 # Feuille de route détaillée
├── scenes/
│   └── Main.tscn              # Scène maîtresse du jeu
└── scripts/
    ├── audio/
    │   └── sound_generator.gd # Synthétiseur sonore procédural
    ├── enemies/
    │   ├── death_particles.gd # Particules voxel d'explosion
    │   ├── dungeon_boss.gd    # Boss Gorgaroth
    │   ├── enemy_base.gd      # IA de base des monstres
    │   ├── enemy_spawner.gd   # Gestionnaire d'apparition
    │   ├── golem.gd           # Golem de pierre
    │   ├── skeleton.gd        # Squelette guerrier
    │   ├── slime.gd           # Slime cubique gélatineux
    │   └── wolf.gd            # Loup sauvage
    ├── items/
    │   ├── item_data.gd       # Générateur d'équipement & raretés
    │   ├── loot_drop.gd       # Butin lumineux 3D
    │   └── treasure_chest.gd  # Coffre au trésor articulé
    ├── player/
    │   ├── companion_data.gd  # Définition des 24 compagnons
    │   ├── pet_companion.gd   # IA du familier de combat
    │   ├── player_class_data.gd # Archétypes & sorts de classe
    │   ├── player.gd          # Contrôleur physique CharacterBody3D
    │   ├── save_system.gd     # Sauvegarde & chargement JSON
    │   ├── talent_tree.gd     # Arbre de talents à 5 branches
    │   └── voxel_character.gd # Modèle voxel articulé du héros
    ├── ui/
    │   ├── boss_bar_ui.gd     # Jauge de boss
    │   ├── class_select_ui.gd # Écran de sélection de classe
    │   ├── compass_ui.gd      # Ruban boussole 360°
    │   ├── damage_label_3d.gd # Chiffres de dégâts flottants
    │   ├── dialog_ui.gd       # Fenêtre de dialogues PNJ
    │   ├── fps_counter.gd     # Compteur d'images par seconde
    │   ├── inventory_ui.gd    # Grille d'inventaire & équipement
    │   ├── main_menu_ui.gd    # Écran d'accueil principal
    │   ├── pause_menu_ui.gd   # Menu pause & réglages
    │   ├── player_hud.gd      # Jauges PV/Endurance & quêtes
    │   ├── skill_bar_ui.gd    # Barre de sorts & cooldowns
    │   └── world_map_ui.gd    # Carte topographique des biomes
    └── world/
        ├── chunk.gd           # Maillage voxel, LOD & MultiMesh
        ├── day_night_cycle.gd # Cycle solaire & lunaire 24h
        ├── dungeon_generator.gd # Salles, couloirs et arènes
        ├── free_camera.gd     # Caméra libre de débogage
        ├── village_generator.gd # Villages par biome
        ├── village_npc.gd     # PNJ villageois animés
        └── world.gd           # Coordinateur multithread de chunks
```

---

## 🚀 Compilation & Exportation (.exe Windows)

### 1. Validation Headless du Projet
Pour valider l'intégrité du projet sans ouvrir de fenêtre graphique :
```powershell
& "C:\Users\re_wa\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --quit
```

### 2. Exportation Release Windows
Pour compiler le jeu complet sous forme d'exécutable natif autonome `.exe` :
```powershell
& "C:\Users\re_wa\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/Voxelands.exe
```

> [!NOTE]
> Cette commande s'appuie sur le preset `Windows Desktop` défini dans `export_presets.cfg`. Les templates d'export officiels de Godot sont requis lors de l'exécution de la commande d'exportation finale.
