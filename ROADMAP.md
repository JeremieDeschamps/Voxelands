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
  - Couleurs par vertex pour chaque type de bloc et ombrage Ambient Occlusion (AO).
  - Génération multithreadée asynchrone sans saccade via `WorkerThreadPool`.
  - Chargement et déchargement infini dynamique autour de la cible (rayon configurable).
  - Génération de collisions solides 3D via `ConcavePolygonShape3D` (avec traversée fluide des fleurs/herbes).
  - Système de 6 Biomes pilotés par deux cartes de bruit (température et humidité) :
    - Prairie (herbe vive, fleurs rouges et jaunes, herbes hautes, chênes).
    - Forêt (herbe dense, chênes feuillus, bouleaux élancés).
    - Désert (dunes de sable, grès, cactus à bras multiples, arbustes secs, rochers).
    - Neige / Taïga (sol enneigé, pins coniques à aiguilles sombres).
    - Montagnes (falaises de pierre et de roche, sommets enneigés, rochers).
    - Océan & Plages (eau bleue au niveau de la mer y=32, plages de sable doré).
  - Décor procédural déterministe par cellule avec graine maîtresse (`world_seed`) pour une reproductibilité intégrale.
  - Caméra libre de test (`FreeCamera`) avec contrôles WASD + souris + élévation + accélération Shift.
  - Validation headless réussie.

- [x] **Étape 3 : Contrôleur Joueur & Caméra (Player)**
  - Personnage voxel articulé construit 100% en code ([`voxel_character.gd`](file:///Z:/scripts/player/voxel_character.gd)) : tête, yeux, cheveux, torse en tunique, bras avec manchettes, jambes et bottes.
  - Animation procédurale en code : balancement synchronisé des bras et des jambes lors de la marche/course, oscillation de brasse en nage, posture de vol en planeur.
  - Modèle de planeur / parapente procédural déployable en l'air.
  - Contrôleur physique `CharacterBody3D` ([`player.gd`](file:///Z:/scripts/player/player.gd)) :
    - Déplacements ZQSD / WASD configurés dans la `InputMap`.
    - Saut (`jump` via Espace) et course (`sprint` via Shift).
    - Gravité et gestion des collisions solides avec le relief voxel via capsule 3D.
    - Nage fluide sous le niveau de la mer avec flottabilité vers la surface et propulsion verticale.
    - Planeur activable en l'air (touche Espace) réduisant la vitesse terminale de chute et augmentant la vitesse planante.
  - Caméra orbitale à la 3e personne avec `SpringArm3D` anti-clipping, visée souris (pitch/yaw) et zoom progressif à la molette.
  - Remplacement de la caméra libre par le joueur dans [`Main.tscn`](file:///Z:/scenes/Main.tscn).
  - Validation headless réussie.

- [ ] **Étape 4 : Système d'Inventaire & Objets (Items)**
  - Structure de données d'inventaire et barre de raccourcis (hotbar).
  - Objets, outils et ressources générés procéduralement.
  - Système de fabrication basique (crafting).

- [x] **Étape 5 : Entités & Ennemis (Enemies) & Système de Combat**
  - 4 modèles d'ennemis voxel procéduraux construits en code :
    - **Loups sauvages** ([`wolf.gd`](file:///Z:/scripts/enemies/wolf.gd)) : quadrupède avec museau, oreilles pointues, queue et animation de course (plaines, forêts, toundra).
    - **Squelettes guerriers** ([`skeleton.gd`](file:///Z:/scripts/enemies/skeleton.gd)) : bipède avec crâne, cavités sombres, cage thoracique et épée d'os (désert, nuit).
    - **Slimes cubiques** ([`slime.gd`](file:///Z:/scripts/enemies/slime.gd)) : gelée translucide avec noyau intérieur et sautillement squash & stretch (prairies, forêts, rivages).
    - **Golems anciens** ([`golem.gd`](file:///Z:/scripts/enemies/golem.gd)) : colosse de roche massif avec yeux runiques cyan luisants et frappe lourde (montagnes, désert).
  - IA complète sur [`enemy_base.gd`](file:///Z:/scripts/enemies/enemy_base.gd) : patrouille aléatoire, détection de proximité, poursuite et attaque de mêlée.
  - Spawner dynamique d'ennemis par biome ([`enemy_spawner.gd`](file:///Z:/scripts/enemies/enemy_spawner.gd)) avec contrôle de population et déchargement au-delà de 65m.
  - Système de combat réactif :
    - Clic gauche : attaque de base ciblée (22 dégâts, animation de frappe).
    - Clic droit : compétence tourbillon circulaire à 360° (45 dégâts, onde de choc, coût 30 endurance).
  - Feedback visuel de combat :
    - Barres de vie 3D procédurales au-dessus de chaque ennemi toujours orientées vers la caméra.
    - Dégâts flottants 3D avec ascension et fondu ([`damage_label_3d.gd`](file:///Z:/scripts/ui/damage_label_3d.gd)).
    - Particules de débris cubiques voxel à l'explosion mortelle ([`death_particles.gd`](file:///Z:/scripts/enemies/death_particles.gd)).
    - Jauges de vie et d'endurance du joueur sur le HUD ([`player_hud.gd`](file:///Z:/scripts/ui/player_hud.gd)).
    - Invincibilité temporaire (i-frames) avec clignotement du joueur et flash rouge à l'écran lors d'un coup reçu.
  - Validation headless réussie.

- [ ] **Étape 6 : Générateur Audio Procédural**
  - Synthèse sonore en temps réel via `AudioStreamGenerator` (bruits de pas, casse de bloc, coup, musique d'ambiance 8/16-bit synthétisée).

- [ ] **Étape 7 : Interface Utilisateur (UI)**
  - Rendu UI avec Godot Control nodes (barre de vie/mana/endurance, réticule, hotbar, menu d'inventaire/crafting).
  - Style visuel épuré sans texture externe.

- [ ] **Étape 8 : Finitions, Optimisation & Export**
  - Optimisation du maillage des voxels (culling des faces cachées).
  - Téléchargement des templates d'export et compilation/exportation native.
