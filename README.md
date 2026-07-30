# FP4 Earpiece Volume Fix

Module Magisk qui corrige le volume trop faible de l'oreillette en appel sur
**Fairphone 4** sous **/e/OS** (testé sur /e/OS 4.1, plateforme Qualcomm
"Lagoon" / SM6350).

## Le problème

Sur FP4 + /e/OS, le volume de l'oreillette en appel classique (GSM/VoLTE,
pas VoIP/WhatsApp) est très faible, même à fond, ce qui rend les appels
difficiles à entendre dans un environnement un peu bruyant. C'est un bug
connu et non résolu côté /e/OS :

- [Forum /e/OS — FP4 low volume at phone calls](https://community.e.foundation/t/fp4-low-volume-at-phone-calls-speaker-not-loud-speaker/81579)
- [Forum /e/OS — Speaker too quiet during calls](https://community.e.foundation/t/speaker-too-quiet-during-calls/79088)
- [GitLab e Foundation — issue #2](https://gitlab.e.foundation/e/devices/FP4/android_hardware_qcom_audio/-/issues/2)
- [GitLab e Foundation — backlog #9185](https://gitlab.e.foundation/e/backlog/-/work_items/9185)

Les développeurs n'étant pas parvenus à reproduire le bug en interne, il
reste ouvert. Ce module contourne le problème côté utilisateur, sans
attendre un correctif officiel.

## Cause technique

Sur ce SoC, l'ampli de l'oreillette n'est **pas** un simple ampli casque
avec un gain fixe dans `mixer_paths.xml`. Le Fairphone 4 réutilise l'ampli
intelligent externe **aw882xx** (normalement dédié au haut-parleur
principal), basculé en mode `Rcv` pour l'oreillette :

```xml
<path name="handset">
    <ctl name="QUIN_MI2S_RX Channels" value="One" />
    <ctl name="aw882xx_mode_switch_l" value="Rcv" />
    <ctl name="aw882xx_pa_switch_l" value="On" />
</path>
```

Le gain réel de cet ampli en mode `Rcv` est piloté par un registre ALSA
dynamique, **absent du fichier XML statique**, et non modifiable par un
patch classique de `mixer_paths.xml` :

- `numid=2175` — `aw882xx_mode_switch_l` (0 = Spk, 1 = Rcv, 2 = Voice)
- `numid=2181` — `aw882xx_rx_volume_l` (plage 0–255, **valeur basse = volume
  fort**, l'échelle fonctionne à l'inverse d'un gain dB classique)

Ce registre est en outre **réinitialisé par le pilote à chaque nouvel
appel** (valeur par défaut observée : `80`). Un simple réglage appliqué une
fois au démarrage du téléphone ne suffit donc pas : il faut le réappliquer
à chaque appel.

## Fonctionnement du module

`service.sh` lance une boucle en arrière-plan (démarrée par Magisk au
boot) qui, toutes les secondes :

1. lit `aw882xx_mode_switch_l` (numid 2175)
2. si la valeur est `1` (oreillette active), force `aw882xx_rx_volume_l`
   (numid 2181) à la valeur cible définie dans `target_value.txt`
3. ne touche à rien en dehors de ce mode (haut-parleur, musique, etc.
   restent intacts — seul le canal `_l`, utilisé par l'oreillette, est
   concerné)

## Dépendance

Le module s'appuie sur le binaire `amixer` du paquet **alsa-utils**,
installé via **Termux** — /e/OS 4.1 sur FP4 ne fournit ni `tinymix` ni
`amixer` en natif.

```bash
pkg install alsa-utils
```

Le script cherche `amixer` à ces emplacements, dans l'ordre :

```
/data/data/com.termux/files/usr/bin/amixer
/system/bin/amixer
/vendor/bin/amixer
```

⚠️ Si Termux ou le paquet `alsa-utils` sont désinstallés, le correctif
s'arrête silencieusement (rien n'est cassé, il redevient simplement
inactif) — il suffit de les réinstaller pour le réactiver, sans réinstaller
le module.

## Installation

1. Installer Termux (F-Droid, pas le Play Store) puis :
   ```bash
   pkg update && pkg install alsa-utils
   ```
2. Dans Magisk → Modules → Installer depuis stockage local
3. Sélectionner le zip du module
4. Redémarrer

## Configuration

La valeur cible (0–255, plus bas = plus fort) se change à chaud, sans
réinstallation ni redémarrage :

```bash
su
echo 10 > /data/adb/modules/earpiece_volume_fix/target_value.txt
```

Valeur par défaut : `20`. Aucune distorsion constatée jusqu'à `0` (volume
maximal) lors des tests, mais chacun sa sensibilité auditive — ajustez
selon votre confort.

## Vérification / logs

```bash
su
cat /data/adb/modules/earpiece_volume_fix/log.txt
```

Doit afficher une ligne du type `mode Rcv detecte, application du gain=20`
à chaque prise d'appel.

## Limites connues

- Calibré pour ce SoC et cette version d'/e/OS précisément. Une mise à
  jour système peut faire changer les `numid` ALSA : si le correctif cesse
  de fonctionner après une mise à jour, revérifier avec :
  ```bash
  amixer -c 0 controls | grep aw882xx
  ```
- Le canal `_r` (droit) n'est pas utilisé par le chemin oreillette sur ce
  device et n'est donc pas modifié par ce module.
- Boucle de surveillance toutes les secondes : léger impact batterie
  (un appel de processus `amixer` par seconde en veille, deux pendant un
  appel), jugé négligeable en usage normal.

## Avertissement

Fourni tel quel, sans garantie. Testé et fonctionnel sur un Fairphone 4 /
/e/OS 4.1, mais les registres ALSA d'un chip audio peuvent varier d'une
unité à l'autre ou d'une version de firmware à l'autre. Vérifiez le
comportement sur votre propre appareil avant de vous y fier en usage
quotidien.

## Licence

Aucune restriction particulière — faites-en ce que vous voulez.
