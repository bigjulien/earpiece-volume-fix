#!/system/bin/sh
# FP4 Earpiece Volume Fix (v2 - evenementiel, sans polling)
#
# Ecoute les evenements ALSA via `alsactl monitor` (bloquant, ne consomme
# rien tant qu'aucun evenement audio ne survient). A chaque evenement recu
# (quel qu'il soit), verifie si le mode oreillette (aw882xx_mode_switch_l,
# numid=2175) est actif, et si oui force le gain (aw882xx_rx_volume_l,
# numid=2181) a la valeur cible, ce registre etant reinitialise par le
# pilote a chaque nouvel appel.
#
# Contrairement a la v1 (boucle "sleep 1"), cette version ne reveille pas
# le CPU en continu: alsactl monitor dort dans un appel bloquant au niveau
# noyau, seul un vrai evenement audio (deja provoque par autre chose : le
# systeme telephonique, la lecture d'un son, etc.) declenche une verification.

MODDIR=${0%/*}
LOG="$MODDIR/log.txt"
CONFIG="$MODDIR/target_value.txt"

AMIXER_CANDIDATES="
/data/data/com.termux/files/usr/bin/amixer
/system/bin/amixer
/vendor/bin/amixer
"
ALSACTL_CANDIDATES="
/data/data/com.termux/files/usr/sbin/alsactl
/data/data/com.termux/files/usr/bin/alsactl
/system/bin/alsactl
/vendor/bin/alsactl
"

CARD=0
NUMID_MODE=2175
NUMID_VOL_L=2181

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
    if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 51200 ]; then
        tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

get_target_value() {
    if [ -f "$CONFIG" ]; then
        val=$(tr -d ' \t\r\n' < "$CONFIG")
        case "$val" in
            ''|*[!0-9]*) echo 20 ;;
            *)
                if [ "$val" -ge 0 ] && [ "$val" -le 255 ]; then
                    echo "$val"
                else
                    echo 20
                fi
                ;;
        esac
    else
        echo 20
    fi
}

read_ctl_value() {
    "$AMIXER" -c "$CARD" cget numid="$1" 2>/dev/null \
        | grep -o 'values=[0-9]*' | tail -n 1 | cut -d= -f2
}

find_bin() {
    for c in $1; do
        if [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

wait_for_bin() {
    # $1 = liste de candidats, timeout 60s
    i=0
    while [ "$i" -lt 30 ]; do
        found=$(find_bin "$1")
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
        i=$((i + 1))
        sleep 2
    done
    return 1
}

AMIXER=$(wait_for_bin "$AMIXER_CANDIDATES")
if [ -z "$AMIXER" ]; then
    log "amixer introuvable apres 60s (Termux/alsa-utils installe ?) - arret du service"
    exit 0
fi

ALSACTL=$(wait_for_bin "$ALSACTL_CANDIDATES")
if [ -z "$ALSACTL" ]; then
    log "alsactl introuvable apres 60s - arret du service"
    exit 0
fi

log "service demarre (mode evenementiel), amixer=$AMIXER alsactl=$ALSACTL"

apply_if_needed() {
    mode=$(read_ctl_value "$NUMID_MODE")
    if [ "$mode" = "1" ]; then
        target=$(get_target_value)
        cur=$(read_ctl_value "$NUMID_VOL_L")
        if [ "$cur" != "$target" ]; then
            "$AMIXER" -c "$CARD" cset numid="$NUMID_VOL_L" "$target" >/dev/null 2>&1
            log "gain force a $target (mode Rcv detecte via evenement)"
        fi
    fi
}

(
    # Verification initiale au cas ou le service demarre pendant un appel deja actif
    apply_if_needed

    # Boucle de supervision : si alsactl monitor s'arrete pour une raison
    # quelconque (carte occupee, redemarrage audio HAL...), on le relance.
    while true; do
        "$ALSACTL" monitor "hw:$CARD" 2>>"$LOG" | while read -r _line; do
            apply_if_needed
        done
        log "alsactl monitor s'est arrete, relance dans 5s"
        sleep 5
    done
) &

exit 0
