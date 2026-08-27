# Tuning des trip points thermiques (kona-thermal.dtsi)

Ce fichier documente les seuils réellement modifiés par
`scripts/apply-dts-thermal-tuning.sh` dans
`arch/arm64/boot/dts/vendor/qcom/kona-thermal.dtsi` des sources du kernel
(`android_kernel_oneplus_sm8250_los_noksu`).

Seules les zones pilotées directement par le kernel (`thermal-governor =
"step_wise"`, avec un vrai `cooling-device` associé) sont modifiées. Les
zones `"user_space"` (`*-usr`) sont laissées intactes : elles sont pilotées
par le thermal-engine propriétaire d'Oplus en espace utilisateur (fermé,
hors des sources du kernel), et servent surtout de garde-fou matériel —
les toucher n'aurait pas d'effet prévisible sans le composant fermé qui va
avec.

| Zone (step_wise réel) | Cooling device | Trip d'origine | Nouveau trip | Effet |
|---|---|---|---|---|
| `cpu-1-0-step` à `cpu-1-7-step` (`cpufreq_1X_config`) | `cpu7_notify` (limite la fréquence du cluster Gold/Prime) | 75000 (75 °C) | **65000 (65 °C)** | Le throttling de fréquence du cluster performant démarre 10 °C plus tôt |
| `gpuss-max-step` (`gpu_trip0`) | `msm_gpu` | 95000 (95 °C) | **85000 (85 °C)** | Le GPU est bridé plus tôt en charge (jeux, benchmarks) |
| `pop-mem-step` (`pop_trip`) | `CPU4` + `CPU7` | 95000 (95 °C) | **85000 (85 °C)** | Protège la mémoire POP proche des cœurs performants, throttle un peu plus tôt |

Les trips "isolate" (`cpuXX-config` à 110000, `silver-trip`/`gold-trip` à
120000) ne sont **pas** modifiés : ce sont des filets de sécurité qui
mettent un cœur hors ligne en dernier recours — les laisser hauts évite de
désactiver des cœurs pour rien.

## Pourquoi cette approche plutôt qu'éditer les tables de fréquence

Sur ce kernel (SM8250 "kona"), les fréquences CPU sont pilotées par
`qcom,cpufreq-hw-epss` : la table de fréquences est lue directement depuis
des registres matériels (fusibles) au boot, elle n'est pas une simple liste
`opp-hz` éditable dans un fichier `.dtsi`. Il n'est donc pas possible de
plafonner la fréquence max proprement à ce niveau — c'est pour ça que le
plafonnement du cœur Prime se fait plutôt au runtime via sysfs
(`scaling_max_freq`), dans `boot-scripts/init.battery_thermal.sh`.
