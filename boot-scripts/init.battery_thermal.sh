#!/system/bin/sh
# =============================================================================
# init.battery_thermal.sh
# Script de tuning exécuté une fois le boot terminé (sys.boot_completed=1).
# OnePlus 8 Pro (instantnoodlep) — SM8250 (Kryo 585 : 4 Silver + 3 Gold + 1 Prime)
# =============================================================================
# Toutes les actions sont protégées par des tests d'existence de fichier :
# si un nœud sysfs n'existe pas (autre variante de kernel/firmware), l'action
# est simplement ignorée, sans faire planter le script ni le boot.

# --- Gouverneur schedutil sur tous les cœurs (sécurité, déjà mis par défaut
#     via le defconfig, mais on le réaffirme au cas où l'init userspace le
#     change) ---
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  gov_file="$cpu/cpufreq/scaling_governor"
  [ -f "$gov_file" ] && echo schedutil > "$gov_file" 2>/dev/null
done

# --- Plafonnement du cœur Prime (cpu7) à ~90% de sa fréquence max pour
#     limiter les pics de conso/chauffe lors des lancements d'apps lourdes,
#     sans bloquer les 3 cœurs Gold ni les 4 Silver ---
PRIME_CPU=/sys/devices/system/cpu/cpu7/cpufreq
if [ -f "$PRIME_CPU/cpuinfo_max_freq" ] && [ -f "$PRIME_CPU/scaling_max_freq" ]; then
  MAXFREQ=$(cat "$PRIME_CPU/cpuinfo_max_freq" 2>/dev/null)
  if [ -n "$MAXFREQ" ]; then
    CAPPED=$((MAXFREQ * 90 / 100))
    echo "$CAPPED" > "$PRIME_CPU/scaling_max_freq" 2>/dev/null
  fi
fi

# --- Nettoyage des wakelocks actifs restants (évite qu'un wakelock oublié
#     empêche la mise en veille profonde) ---
[ -f /sys/power/wake_unlock ] && echo 0 > /sys/power/wake_unlock 2>/dev/null

# --- Gouverneur thermique step_wise explicite sur les zones qui le supportent
#     (throttling progressif plutôt que brutal) ---
for tz in /sys/class/thermal/thermal_zone*; do
  policy_file="$tz/policy"
  if [ -f "$policy_file" ] && grep -q "step_wise" "$tz/available_policies" 2>/dev/null; then
    echo step_wise > "$policy_file" 2>/dev/null
  fi
done

exit 0
