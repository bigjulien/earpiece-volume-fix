ui_print "- FP4 Earpiece Volume Fix"
ui_print "- Ce module necessite Termux + le paquet alsa-utils"
ui_print "  (fournit le binaire 'amixer' utilise en arriere-plan)."
ui_print "- Valeur de gain par defaut: 20 (modifiable apres coup dans"
ui_print "  /data/adb/modules/earpiece_volume_fix/target_value.txt)"
ui_print "- Calibre pour Fairphone 4 / plateforme Lagoon / e-OS 4.1"
ui_print "  Peut necessiter une re-verification apres mise a jour systeme."

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/target_value.txt" 0 0 0644
