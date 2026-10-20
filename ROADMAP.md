# Feuille de Route - Voxelands

## Progression du Projet

- [x] **Étape 0 : Initialisation de l'environnement & Règles**
  - Vérification / Installation de Godot 4.x via winget (Godot 4.7.2 stable officiel).
  - Détection et enregistrement du binaire console Windows dans `GEMINI.md`.
  - Mise en place de l'arborescence (`scripts/`, `scenes/`) et des directives strictes.

- [x] **Étape 1 : Initialisation du projet Godot & Scène Principale**
  - Fichier `project.godot` configuré avec `res://scenes/Main.tscn` comme scène de démarrage.
  - Scène principale `Main.tscn` avec :
    - Ciel procédural à dégradé (`ProceduralSkyMaterial`).
    - Brouillard volumétrique/distance (`fog_enabled = true`).
    - `DirectionalLight3D` avec ombres activées.
    - `Camera3D` positionnée et orientée.
    - Cube de test 3D (`MeshInstance3D`).
    - Compteur FPS en haut à gauche (`CanvasLayer` + `fps_counter.gd`).
  - Arborescence complète créée (`scripts/world/`, `player/`, `enemies/`, `items/`, `ui/`, `scenes/`).
  - Validation headless réussie sans erreur.

- [x] **Étape 2 : Moteur Voxel Procédural (World)**
  - Chunks de 16x16x128 blocs avec calcul déterministe par `FastNoiseLite`.
  - Culling des faces internes cachées entre blocs adjacents.
  - Couleurs par vertex pour chaque type de bloc (herbe, terre, pierre, sable, eau).
  - Ambient Occlusion (AO) par vertex à 4 niveaux d'intensité et inversion des diagonales pour éviter les artefacts.
  - Génération multithreadée asynchrone sans saccade via `WorkerThreadPool` avec pool de tâches limitées.
  - Chargement et déchargement infini dynamique autour de la cible (rayon configurable).
  - Génération de collisions solides 3D via `ConcavePolygonShape3D` sur chaque chunk.
  - Caméra libre de test (`FreeCamera`) avec contrôles WASD + souris + élévation + accélération Shift.
  - Validation headless réussie.

- [ ] **Étape 3 : Contrôleur Joueur & Caméra (Player)**
  - Déplacement FPS/TPS à la première/troisième personne (sauts, collisions, gravité).
  - Interaction avec le monde : casser et poser des voxels par raycast.
  - Statistiques RPG (santé, endurance, niveau, expérience).

- [ ] **Étape 4 : Système d'Inventaire & Objets (Items)**
  - Structure de données d'inventaire et barre de raccourcis (hotbar).
  - Objets, outils et ressources générés procéduralement.
  - Système de fabrication basique (crafting).

- [ ] **Étape 5 : Entités & Ennemis (Enemies)**
  - Modèles de créatures voxel procédurales (ex: slimes, golems, créatures sauvages).
  - IA simple de patrouille, détection, poursuite et combat.
  - Système de dégâts et butin (loot drops).

- [ ] **Étape 6 : Générateur Audio Procédural**
  - Synthèse sonore en temps réel via `AudioStreamGenerator` (bruits de pas, casse de bloc, coup, musique d'ambiance 8/16-bit synthétisée).

- [ ] **Étape 7 : Interface Utilisateur (UI)**
  - Rendu UI avec Godot Control nodes (barre de vie/mana/endurance, réticule, hotbar, menu d'inventaire/crafting).
  - Style visuel épuré sans texture externe.

- [ ] **Étape 8 : Finitions, Optimisation & Export**
  - Optimisation du maillage des voxels (culling des faces cachées).
  - Téléchargement des templates d'export et compilation/exportation native.
