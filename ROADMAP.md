# Feuille de Route - Voxelands

## Progression du Projet

- [x] **Étape 0 : Initialisation de l'environnement & Règles**
  - Vérification / Installation de Godot 4.x via winget (Godot 4.7.2 stable officiel).
  - Détection et enregistrement du binaire console Windows dans `GEMINI.md`.
  - Mise en place de l'arborescence (`scripts/`, `scenes/`) et des directives strictes.

- [x] **Étape 1 : Initialisation du projet Godot & Scène Principale**
  - Fichier `project.godot` configuré (nom, rendu, inputs, etc.).
  - Scène principale `main.tscn` créée.
  - Validation headless réussie (Godot v4.7.2 stable officiel).

- [ ] **Étape 2 : Moteur Voxel Procédural (World)**
  - Générateur de terrain voxel par code (ArrayMesh / SurfaceTool, couleurs par vertex).
  - Gestion des chunks, types de blocs (herbe, terre, pierre, eau, sable, bois, feuillage).
  - Génération de reliefs (bruit de Perlin / FastNoiseLite) et arbres procéduraux.
  - Collisions 3D des chunks.

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
