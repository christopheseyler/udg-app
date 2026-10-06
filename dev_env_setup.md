# Environnement de dev Yocto (udg / ROCK 5C / RAUC)

Procédure pour recréer l'environnement de build Yocto sur une nouvelle
machine Windows, à partir de zéro. Ce document couvre l'installation de
l'environnement (WSL2, dépendances) ; les layers Yocto du projet
(`meta-udg-min`, `meta-udg`) et toute la suite (sources, `local.conf`,
build, flash, mise à jour RAUC) vivent dans le dépôt **udg-yocto** - voir
`udg-yocto/meta-udg-min/README.md` et `udg-yocto/scripts/WSL-NOTES.md`.
Ce dépôt-ci (udg-app) ne contient que le jeu Godot.

## Prérequis machine

- Windows 10/11 avec virtualisation activée (WSL2 en dépend).
- **RAM** : 32 Go recommandés par le projet Yocto ; possible avec moins
  (testé avec 15,5 Go) mais plus lent et il faut limiter le parallélisme
  du build (voir étape 2 et `BB_NUMBER_THREADS`/`PARALLEL_MAKE` plus bas).
- **Disque** : au moins 150 Go libres sur le disque qui hébergera la
  distro WSL (sources + `sstate-cache` + `tmp/`). Vérifier l'espace libre
  réel avec `Get-Volume` en PowerShell plutôt que `Get-PSDrive`, qui peut
  donner un chiffre erroné (constaté sur une machine de dev).
- Choisir un disque **local** (SSD/NVMe idéalement), jamais un lecteur
  réseau : la distro WSL (fichier `.vhdx`) doit vivre sur un disque local
  rapide.

## 1. Installer WSL2 + Ubuntu

Dans PowerShell (admin si WSL n'est pas encore activé du tout) :

```powershell
wsl --install -d Ubuntu-24.04
```

Redémarrer si demandé, puis lancer "Ubuntu 24.04" depuis le menu Démarrer
pour créer l'utilisateur Unix (indépendant du compte Windows).

Vérifier l'installation :
```powershell
wsl --status
wsl -l -v
```

Si WSL est déjà installé mais sans version 2 par défaut :
```powershell
wsl --set-default-version 2
```

### Installer la distro sur un autre disque que C:

Si le disque système manque de place, installer/déplacer la distro
ailleurs (remplacer `D:\WSL\Ubuntu` par le chemin voulu) :
```powershell
wsl --install -d Ubuntu-24.04 --location D:\WSL\Ubuntu
```
ou, pour déplacer une distro déjà installée :
```powershell
wsl --shutdown
wsl --export Ubuntu-24.04 D:\WSL\ubuntu-export.tar
wsl --unregister Ubuntu-24.04
wsl --import Ubuntu-24.04 D:\WSL\Ubuntu D:\WSL\ubuntu-export.tar
```

## 2. Configurer les ressources allouées à WSL2

Par défaut WSL2 plafonne à 50% de la RAM de la machine, ce qui est souvent
trop juste pour Yocto. Créer/éditer `C:\Users\<toi>\.wslconfig` :

```powershell
@'
[wsl2]
memory=12GB
processors=12
swap=8GB
localhostForwarding=true
'@ | Set-Content -Encoding ascii "$env:USERPROFILE\.wslconfig"
wsl --shutdown
```

Ajuster `memory`/`processors` selon la RAM/CPU réels de la machine (laisser
~3-4 Go à Windows). Sur une machine avec beaucoup de RAM (32 Go+), monter
`memory` à 24-28GB.

## 3. Dépendances de build (dans le terminal Ubuntu/WSL)

```bash
sudo apt-get update
sudo apt-get install -y build-essential chrpath cpio debianutils diffstat file \
  gawk gcc git iputils-ping libacl1 lz4 locales python3 python3-git python3-jinja2 \
  python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd
```

## 4. Sources, configuration et build

Tout ce qui suit est documenté dans le dépôt **udg-yocto** :

- `meta-udg-min/README.md` : arbre vendor Radxa (`~/rock5c-yocto`, via
  `repo init` sur `radxa/yocto-manifests`), `local.conf`, build de
  `udg-app-image`. C'est la configuration effectivement utilisée.
- `scripts/WSL-NOTES.md` : spécificités WSL (resynchronisation du dépôt
  Windows vers le filesystem natif, ressources, espace disque).
- `meta-udg/README.md` : layer « production » (meta-rockchip communautaire
  + RAUC A/B complet), pas encore compilé.

**Ne jamais faire le build sous `/mnt/c/...`** (ou tout autre `/mnt/<lettre>`) :
ce montage passe par drvfs/9P, qui n'a pas d'`inotify` fiable, pas de vrais
liens durs/symboliques, et des I/O bien plus lentes - BitBake/PSEUDO s'en
accommodent mal. Toujours construire dans le filesystem natif de la distro
WSL (sous `$HOME`).

Si la machine a peu de RAM (< 20 Go), ajouter à `conf/local.conf` pour
éviter les OOM pendant les compilations lourdes (kernel, Mesa, LLVM/clang) :
```
BB_NUMBER_THREADS = "8"
PARALLEL_MAKE = "-j 8"
```

Le jeu lui-même n'est pas copié dans l'image depuis ce dépôt : la recette
`udg-game` de udg-yocto télécharge l'asset `udg-linux-arm64.tar.gz` d'une
release GitHub de udg-app (`GAME_RELEASE_TAG` + `sha256sum` dans la
recette).

## Pièges connus

- **Locale `en_US.UTF-8` absente** sur une image Ubuntu WSL fraîchement
  installée - bitbake refuse de démarrer (`Please make sure locale
  'en_US.UTF-8' is available on your system`, boucle de retry puis échec).
  Corriger une fois avant le premier `bitbake` :
  ```bash
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
  ```
- **Ne pas construire sous `/mnt/c`** (voir étape 4) - erreurs
  intermittentes, build très lent, parfois échecs silencieux de `pseudo`.
- **`Get-PSDrive` peut mentir sur l'espace libre réel** d'un disque -
  vérifier avec `Get-Volume` avant de conclure qu'il manque de place.
- **Antivirus Windows Defender** : exclure le dossier contenant le
  `.vhdx` de la distro WSL (`%LOCALAPPDATA%\Packages\...` ou l'emplacement
  choisi à l'étape 1) des scans temps réel - impact significatif sur les
  performances I/O sinon.
- **RAM insuffisante** : si le build s'arrête avec des erreurs de
  compilation aléatoires (gcc/ld tués), c'est presque toujours un OOM -
  réduire `BB_NUMBER_THREADS`/`PARALLEL_MAKE` avant d'investiguer ailleurs.
