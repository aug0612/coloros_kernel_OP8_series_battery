#!/usr/bin/env bash
# =============================================================================
# apply-dts-thermal-tuning.sh <chemin vers kona-thermal.dtsi>
# Abaisse les trip points step_wise réellement pilotés par le kernel (voir
# config-fragments/THERMAL_TUNING.md pour le détail et la justification de
# chaque valeur). N'échoue jamais bruyamment : si un motif n'est pas trouvé
# (autre version de sources), il est simplement ignoré et signalé.
# =============================================================================
set -uo pipefail

DTS="$1"

if [ ! -f "$DTS" ]; then
  echo "Fichier DTS introuvable : $DTS"
  exit 0
fi

apply() {
  local desc="$1" old="$2" new="$3"
  if grep -q "$old" "$DTS"; then
    sed -i "s/${old}/${new}/g" "$DTS"
    echo "✅ ${desc} : ${old} -> ${new}"
  else
    echo "⚠️ ${desc} : motif '${old}' non trouvé, ignoré (structure DTS différente ?)"
  fi
}

# Cluster performant (Gold/Prime) : throttle de fréquence dès 65°C au lieu de 75°C
apply "Throttle fréquence cluster performant (cpufreq_1X_config)" \
  "temperature = <75000>;" "temperature = <65000>;"

# GPU + mémoire POP proche des cœurs performants : throttle dès 85°C au lieu de 95°C
# (ce motif correspond à gpu_trip0 ET pop_trip, les 2 seules occurrences de
# 95000°C dans ce fichier — voir config-fragments/THERMAL_TUNING.md)
apply "Throttle GPU + POP mem (gpu_trip0 / pop_trip)" \
  "temperature = <95000>;" "temperature = <85000>;"

echo "Patch DTS thermique appliqué sur $DTS"
