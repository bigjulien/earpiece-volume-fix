#!/system/bin/sh
# FP4 Earpiece Volume Fix
# Surveille en permanence le mode de l'ampli aw882xx (numid=2175).
# Quand le mode "Rcv" (oreillette, valeur=1) est detecte, force le
# registre de gain aw882xx_rx_volume_l (numid=2181) a la valeur cible,
# car ce registre est reinitialise par le pilote a chaque nouvel appel.
# Le mode "Spk" (haut-parleur) n'est jamais touche.

MODDIR=${0%/*}
LOG="$MODDIR/log.txt"
CONFIG="$MODDIR/target_value.txt"

AMIXER_CANDIDATES="
/data/data/com.termux/files/usr/bin/amixer
/system/bin/amixer
/vendor/bin/amixer
"

CARD=0
NUMID_MODE=2175
NUMID_VOL_L=2181
POLL_INTERVAL=1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
    # Garde le log sous ~50 Ko pour ne pas grossir indefiniment
    if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 51200 ]; then
        tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

get_target_value() {
    if [ -f "$CONFIG" ]; then
        val=$(tr -d ' \t\r\n' < "$CONFIG")
        case "$val" in
            ''|*[!0-9]*) echo 20 ;;   # valeur invalide -> repli sur 20
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
    # $1 = numid ; renvoie la derniere valeur "values=N" de la sortie amixer
    "$AMIXER" -c "$CARD" cget numid="$1" 2>/dev/null \
        | grep -o 'values=[0-9]*' | tail -n 1 | cut -d= -f2
}

# --- Attente du binaire amixer (jusqu'a 60s apres le demarrage du service) ---
AMIXER=""
i=0
while [ "$i" -lt 30 ]; do
    for c in $AMIXER_CANDIDATES; do
        if [ -x "$c" ]; then
            AMIXER="$c"
            break 2
        fi
    done
    i=$((i + 1))
    sleep 2
done

if [ -z "$AMIXER" ]; then
    log "amixer introuvable apres 60s (Termux/alsa-utils installe ?) - arret du service"
    exit 0
fi

log "service demarre, amixer=$AMIXER"

# --- Boucle de surveillance en arriere-plan ---
(
    last_mode=""
    while true; do
        mode=$(read_ctl_value "$NUMID_MODE")
        target=$(get_target_value)

        if [ "$mode" = "1" ]; then
            if [ "$last_mode" != "1" ]; then
                log "mode Rcv detecte, application du gain=$target"
            fi
            cur=$(read_ctl_value "$NUMID_VOL_L")
            if [ "$cur" != "$target" ]; then
                "$AMIXER" -c "$CARD" cset numid="$NUMID_VOL_L" "$target" >/dev/null 2>&1
            fi
        else
            if [ "$last_mode" = "1" ]; then
                log "sortie du mode Rcv"
            fi
        fi

        last_mode="$mode"
        sleep "$POLL_INTERVAL"
    done
) &

exit 0
