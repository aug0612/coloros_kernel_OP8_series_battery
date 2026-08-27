#!/usr/bin/env bash
# =============================================================================
# apply-ramdisk-tuning.sh <chemin vers le dossier Anykernel3>
# Prépare l'injection du script de boot battery-thermal dans le ramdisk :
# - copie le script et le bloc de service dans Anykernel3/patch/
# - modifie anykernel.sh pour appeler replace_file / insert_file entre
#   dump_boot et write_boot (voir la doc AnyKernel3 / ak3-core.sh)
# Le résultat est un flashable zip qui, au premier boot, installe le script
# dans le ramdisk et l'exécute une fois via un service déclenché par
# sys.boot_completed=1.
# =============================================================================
set -euo pipefail

AK3_DIR="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$AK3_DIR/patch"
cp "$REPO_ROOT/boot-scripts/init.battery_thermal.sh" "$AK3_DIR/patch/"
cp "$REPO_ROOT/boot-scripts/battery_thermal_service.rc" "$AK3_DIR/patch/"

ANYKERNEL_SH="$AK3_DIR/anykernel.sh"

if [ ! -f "$ANYKERNEL_SH" ]; then
  echo "⚠️ anykernel.sh introuvable dans $AK3_DIR, injection ramdisk ignorée."
  exit 0
fi

# Supprime le bloc d'exemple spécifique à l'ExampleKernel (init.tuna.rc, fstab.tuna...)
# situé entre dump_boot et write_boot, pour le remplacer par notre propre bloc.
python3 - "$ANYKERNEL_SH" << 'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

start_marker = "# init.rc\n"
end_marker = "write_boot;"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

our_block = (
    '# init.rc — battery & thermal boot tuning (fork perso OnePlus 8 Pro)\n'
    'backup_file init.rc;\n'
    'replace_file $RAMDISK/init.battery_thermal.sh 750 init.battery_thermal.sh;\n'
    'insert_file init.rc "battery_thermal" after '
    '"service adbd /system/bin/adbd" battery_thermal_service.rc;\n\n'
)

if start_idx != -1 and end_idx != -1 and start_idx < end_idx:
    content = content[:start_idx] + our_block + content[end_idx:]
    with open(path, "w") as f:
        f.write(content)
    print("✅ Bloc ramdisk d'exemple remplacé par le tuning battery/thermal.")
else:
    print("⚠️ Marqueurs attendus introuvables dans anykernel.sh, aucune modification appliquée.")
PYEOF

echo "Fichiers injectés dans $AK3_DIR/patch/ :"
ls "$AK3_DIR/patch/"
