# FP4 Earpiece Volume Fix

A Magisk module that fixes the excessively low in-call earpiece volume on the **Fairphone 4** running **/e/OS** (tested on /e/OS 4.1, Qualcomm "Lagoon" / SM6350 platform).

## The Problem

On the FP4 running /e/OS, the earpiece volume during regular phone calls (GSM/VoLTE, not VoIP/WhatsApp) is extremely low, even at maximum volume, making conversations difficult to hear in moderately noisy environments. This is a known issue on /e/OS that remains unresolved:

* [/e/OS Forum — FP4 low volume at phone calls](https://community.e.foundation/t/fp4-low-volume-at-phone-calls-speaker-not-loud-speaker/81579)
* [/e/OS Forum — Speaker too quiet during calls](https://community.e.foundation/t/speaker-too-quiet-during-calls/79088)
* [e Foundation GitLab — issue #2](https://gitlab.e.foundation/e/devices/FP4/android_hardware_qcom_audio/-/issues/2)
* [e Foundation GitLab — backlog #9185](https://gitlab.e.foundation/e/backlog/-/work_items/9185)

Since the developers have not been able to reproduce the bug internally, the issue remains open. This module provides a user-side workaround without waiting for an official fix.

## Technical Background

On this SoC, the earpiece amplifier is **not** a simple headset amplifier with a fixed gain defined in `mixer_paths.xml`. Instead, the Fairphone 4 reuses the external **aw882xx** smart amplifier (normally dedicated to the main loudspeaker), switched into `Rcv` mode for earpiece operation:

```xml
<path name="handset">
    <ctl name="QUIN_MI2S_RX Channels" value="One" />
    <ctl name="aw882xx_mode_switch_l" value="Rcv" />
    <ctl name="aw882xx_pa_switch_l" value="On" />
</path>
```

The actual amplifier gain in `Rcv` mode is controlled through a dynamic ALSA register, **not present in the static XML file**, and therefore cannot be modified through a conventional `mixer_paths.xml` patch:

* `numid=2175` — `aw882xx_mode_switch_l` (0 = Spk, 1 = Rcv, 2 = Voice)
* `numid=2181` — `aw882xx_rx_volume_l` (range 0–255, **lower value = louder volume**; the scale works in reverse compared to a traditional dB gain control)

This register is also **reset by the driver whenever a new call starts** (observed default value: `80`). Therefore, applying the setting once at boot is not sufficient; it must be reapplied for every call.

## How the Module Works

`service.sh` starts a background monitoring loop (launched by Magisk at boot) that runs once per second:

1. Reads `aw882xx_mode_switch_l` (numid 2175).
2. If the value is `1` (earpiece active), forces `aw882xx_rx_volume_l` (numid 2181) to the target value defined in `target_value.txt`.
3. Does nothing outside of earpiece mode (speakerphone, media playback, etc. remain untouched — only the `_l` channel used by the earpiece is affected).

## Dependency

The module relies on the `amixer` binary from the **alsa-utils** package installed through **Termux**, since /e/OS 4.1 on the FP4 provides neither `tinymix` nor `amixer` natively.

```bash
pkg install alsa-utils
```

The script searches for `amixer` in the following locations, in order:

```
/data/data/com.termux/files/usr/bin/amixer
/system/bin/amixer
/vendor/bin/amixer
```

⚠️ If Termux or the `alsa-utils` package is removed, the fix simply becomes inactive without causing any issues. Reinstalling them is sufficient to reactivate the module; reinstalling the module itself is not required.

## Installation

1. Install Termux (from F-Droid, not the Play Store), then run:

   ```bash
   pkg update && pkg install alsa-utils
   ```
2. Open Magisk → Modules → Install from storage.
3. Select the module ZIP file.
4. Reboot.

## Configuration

The target value (0–255, lower = louder) can be changed on the fly without reinstalling the module or rebooting:

```bash
su
echo 10 > /data/adb/modules/earpiece_volume_fix/target_value.txt
```

Default value: `20`.

No audible distortion was observed during testing, even at `0` (maximum volume), but hearing sensitivity varies from person to person—adjust the value to your own comfort level.

## Verification / Logs

```bash
su
cat /data/adb/modules/earpiece_volume_fix/log.txt
```

You should see a line similar to:

```text
Rcv mode detected, applying gain=20
```

each time a call is initiated.

## Known Limitations

* Calibrated specifically for this SoC and this version of /e/OS. A system update may change the ALSA `numid` values. If the fix stops working after an update, verify them with:

  ```bash
  amixer -c 0 controls | grep aw882xx
  ```
* The `_r` (right) channel is not used by the earpiece audio path on this device and is therefore not modified.
* The monitoring loop runs once per second, resulting in a small battery impact (one `amixer` process invocation per second while idle, two during a call), considered negligible under normal usage.

## Disclaimer

Provided as-is, without warranty. Tested and confirmed working on a Fairphone 4 running /e/OS 4.1, but ALSA registers on audio chips may vary between hardware revisions and firmware versions. Always verify the behavior on your own device before relying on it for everyday use.

## License

No particular restrictions — use it however you like.

# FP4 Earpiece Volume Fix - Français 

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
