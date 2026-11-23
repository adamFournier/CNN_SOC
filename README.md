# CNN Convolution Engine — VHDL / AXI4-Stream

Bloc de convolution destiné à une chaîne CNN embarquée sur un SoC FPGA Zynq-7000. **Projet en cours de développement, non présenté comme un CNN complet validé.**

## Sources
- `rtl/cnn_conv.vhd` : bloc de convolution pour entrée 8 bits, image 28 × 28 par défaut et sortie AXI4-Stream 32 bits (4 activations 8 bits regroupées).
- `rtl/conv_kernel.vhd` : convolution 3 × 3 pondérée (9 produits puis accumulation) et ajout du biais.
- `rtl/cnn_weights_package.vhd` : définition des 4 jeux de poids et biais. **Les valeurs actuellement versionnées sont toutes nulles** : ce sont des placeholders, pas des poids entraînés.

## Architecture
Le code assemble quatre instances de `conv_kernel` pour une extraction multi-filtre. Il utilise deux line buffers et une fenêtre glissante 3 × 3, ainsi que `TVALID`, `TREADY` et `TLAST` pour les transferts AXI4-Stream. Le code contient des opérations de mise à l'échelle et d'activation, à valider avant d'annoncer une inférence complète.

## Reproduction
Depuis la racine du dépôt :
```sh
vivado -mode batch -source vivado/create_cnn_project.tcl
```
Le script crée un projet RTL minimal et ajoute les trois sources VHDL. Il ne prétend **pas** reconstituer un SoC complet avec PS, DMA et pilote logiciel : le block design présent dans l'ancien projet Vivado portait sur `top_config_conv`, c'est-à-dire la convolution configurable, et a été conservé dans le dépôt Sobel/convolution.

## Validation et limitations
- Aucun testbench CNN autonome n'a été identifié dans l'ancien dépôt.
- Les poids/biais sont actuellement tous à zéro.
- Le pooling, le classifieur final et la validation end-to-end ne sont pas démontrés par les trois sources conservées.
- Aucune simulation ou synthèse n'a été relancée lors de cette réorganisation GitHub.

Les tests fonctionnels, l'intégration SoC et les mesures réelles de ressources/latence restent à documenter.

## Sauvegarde
La branche `backup-before-cleanup-2026-11-23` conserve l'intégralité de l'ancien projet Vivado, y compris fichiers générés et historique. Le nettoyage distant ne modifie aucun répertoire local.
