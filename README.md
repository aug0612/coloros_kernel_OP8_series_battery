# OnePlus 8 Pro — Kernel Battery & Thermal (ColorOS 16)

Kernel personnalisé pour **OnePlus 8 Pro (instantnoodlep)** sous **ColorOS 16 / OxygenOS 16**, orienté **économie de batterie** et **limitation de la chauffe**.

Ce dépôt est un **fork** du système de build de [JackA1ltman/ColorOS_NonGKI_Kernel_Build](https://github.com/JackA1ltman/ColorOS_NonGKI_Kernel_Build), qui compile automatiquement le kernel via **GitHub Actions** — donc **aucun toolchain à installer chez soi** : tout le monde peut compiler sa propre copie directement depuis le navigateur.

## ⚙️ Ce qui a été modifié par rapport à l'original

- Nouveau workflow dédié : [`build-battery-thermal.yml`](.github/workflows/build-battery-thermal.yml)
- Un fragment de configuration [`config-fragments/battery-thermal.config`](config-fragments/battery-thermal.config) est injecté dans le `defconfig` du kernel pendant le build. Il active :
  - des gouverneurs CPU/mémoire orientés économie d'énergie (schedutil, conservative, powersave, devfreq powersave) ;
  - une gestion plus stricte des wakelocks (le téléphone ne reste pas éveillé pour rien) ;
  - un idle CPU plus profond et plus réactif ;
  - un throttling thermique plus progressif (step-wise + power allocator) pour limiter la chauffe avant qu'elle ne devienne gênante.

⚠️ **Honnêteté technique** : ces réglages sont des options standards du framework cpufreq/thermal/PM de Linux, présentes dans la quasi-totalité des kernels Android. Elles donnent un vrai mieux en pratique (moins de wakelocks fantômes, throttling plus doux), mais elles n'attaquent pas les tables de fréquences ni les seuils thermiques bruts définis dans le Device Tree — ceux-ci demandent une édition plus fine (voir [Aller plus loin](#-aller-plus-loin)). Ne t'attends pas à des miracles inconditionnels : le gain dépend aussi de ton usage, des apps installées, et du firmware ColorOS sous-jacent.

## 🚀 Comment compiler (pour toi ou n'importe qui d'autre)

1. **Forker** ce dépôt sur ton propre compte GitHub (bouton "Fork" en haut à droite).
2. Dans ton fork, aller dans l'onglet **Actions**.
3. Sélectionner le workflow **"OnePlus 8 Pro - ColorOS 16 - Battery & Thermal Kernel"**.
4. Cliquer sur **"Run workflow"** :
   - choisir si tu veux inclure **KernelSU** (root) ou non ;
   - lancer.
5. Le build dure environ 30 à 60 minutes selon la charge des runners GitHub.
6. Une fois terminé, ouvrir le run terminé → section **Artifacts** → télécharger le zip :
   - `*-DTB.zip` → si tu utilises un firmware/ROM qui a besoin du DTB séparé.
   - `*.zip` (sans DTB) → sinon, à utiliser dans la majorité des cas courants.

Aucune installation locale n'est nécessaire : la compilation entière se fait sur les serveurs GitHub.

## 📲 Comment flasher

1. Récupérer le zip AnyKernel3 généré par le build.
2. Booter en recovery (TWRP/OrangeFox) **ou** utiliser une app de flash type Kernel Flasher/Franco Kernel Manager si le ROM le permet.
3. Flasher le zip comme un module AnyKernel3 classique.
4. Redémarrer.

⚠️ Toujours faire une sauvegarde (backup) de ton boot/kernel actuel avant de flasher un kernel custom. Un bootloop reste toujours possible avec un kernel modifié — c'est un risque inhérent au modding.

## 🧩 Aller plus loin (implémenté dans ce fork)

Les trois pistes évoquées plus haut ne sont pas restées de la théorie : elles sont **implémentées et appliquées automatiquement à chaque build** par le workflow.

### 1. Fragment `defconfig` (gouverneurs, wakelocks, idle)
Déjà détaillé plus haut : [`config-fragments/battery-thermal.config`](config-fragments/battery-thermal.config).

### 2. Trip points thermiques réels (Device Tree)
Étape *"Application du tuning thermique (trip points DTS)"* du workflow → exécute [`scripts/apply-dts-thermal-tuning.sh`](scripts/apply-dts-thermal-tuning.sh) sur `kona-thermal.dtsi` des sources du kernel.

J'ai inspecté les sources réelles (`android_kernel_oneplus_sm8250_los_noksu`) pour ne modifier **que les zones effectivement pilotées par le kernel** (`thermal-governor = "step_wise"` avec un vrai `cooling-device`), et laisser intactes les zones `"user_space"` gérées par le thermal-engine propriétaire d'Oplus (les toucher n'aurait aucun effet garanti) :

| Zone | Avant | Après | Effet |
|---|---|---|---|
| Throttle fréquence cluster Gold/Prime (`cpufreq_1X_config`, ×8) | 75 °C | **65 °C** | La fréquence du cluster performant est bridée 10 °C plus tôt |
| Throttle GPU (`gpu_trip0`) | 95 °C | **85 °C** | Le GPU est bridé plus tôt en jeu/benchmark |
| Throttle mémoire POP proche CPU4/CPU7 (`pop_trip`) | 95 °C | **85 °C** | Protection thermique plus précoce |

Détails et justification complète dans [`config-fragments/THERMAL_TUNING.md`](config-fragments/THERMAL_TUNING.md) — notamment pourquoi je n'ai *pas* touché aux tables de fréquences CPU (elles sont lues depuis des registres matériels `qcom,cpufreq-hw-epss`, pas depuis un simple `opp-hz` éditable).

### 3. Script de tuning au boot (ramdisk)
Étape *"Injection du script de tuning au boot (ramdisk)"* → exécute [`scripts/apply-ramdisk-tuning.sh`](scripts/apply-ramdisk-tuning.sh), qui :
- copie [`boot-scripts/init.battery_thermal.sh`](boot-scripts/init.battery_thermal.sh) dans le ramdisk du kernel compilé ;
- ajoute un service `battery_thermal` dans `init.rc` (via [`boot-scripts/battery_thermal_service.rc`](boot-scripts/battery_thermal_service.rc)), déclenché une fois au premier `sys.boot_completed=1`.

Ce script, exécuté une fois par boot :
- réaffirme le gouverneur `schedutil` sur tous les cœurs ;
- plafonne le cœur **Prime** (cpu7) à ~90 % de sa fréquence max (calculé dynamiquement, pas de valeur en dur) pour lisser les pics de conso/chauffe sans brider les cœurs Gold/Silver ;
- relâche les wakelocks actifs restants ;
- force le gouverneur thermique `step_wise` sur les zones qui le supportent.

Chaque action est protégée par un test d'existence de fichier : si un nœud sysfs n'existe pas sur une variante de firmware, l'action est simplement ignorée — le script ne peut pas faire planter le boot.

### Si tu veux pousser encore plus loin
- éditer aussi les zones `"user_space"` nécessiterait de reconstruire l'équivalent du thermal-engine Oplus (fermé, hors des sources du kernel) — hors de portée d'un simple patch kernel ;
- ajuster précisément le pourcentage de cap du cœur Prime : modifie la ligne `CAPPED=$((MAXFREQ * 90 / 100))` dans `boot-scripts/init.battery_thermal.sh` (descendre à 80 % bride davantage, au prix d'un peu de perf en pointe) ;
- ajuster l'agressivité des trip points DTS : modifie directement les valeurs dans `scripts/apply-dts-thermal-tuning.sh`.

## 🙏 Crédits

- [JackA1ltman](https://github.com/JackA1ltman) — système de build CI d'origine (ColorOS_NonGKI_Kernel_Build)
- toraidl — sources du kernel OnePlus 8 series pour ColorOS 16
- [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — support KernelSU
- [osm0sis](https://github.com/osm0sis/AnyKernel3) — outil de packaging AnyKernel3

## 📄 Licence

Ce dépôt reste sous licence **Apache-2.0**, comme le projet d'origine (voir [LICENSE](LICENSE) et [NOTICE](NOTICE)).
