# FABLAB - Velo Connecté

Dépot Git pour le projet de vélo connecté. Tous les fichiers sont les fichiers pour le projet Flutter, sauf "ARDUINO.ino", qui est le fichier qui contient le code Arduino.

# Qu'est ce que ce vélo connecté ?

Ce projet consiste au développement d'un boitier simple et portable à fixer derrière un vélo. Il indique la signalisation (clignotants, indicateur de freinage automatique) sur un écran LED. Ce boitier est connectable et controlable par une application mobile Flutter. Le téléphone doit être fixé sur le guidon du vélo, ce qui permet d'utiliser l'application en roulant.

L'application embarque :
- un service de connexion au boitier
- le controle des clignotants par 2 boutons
- le freinage automatique, lorsque le vélo n'est plus en mouvement, via le capteur acceleromètre du téléphone
- l'affichage de l'etat des clignotants, et de l'indicateur de freinage (permet de savoir qu'est ce qui est affiché dans mon dos quand je roule)
- l'affichage de la vitesse du vélo, via la position du vélo
- un système de navigation (position de l'utilisateur sur une carte, possibilité de rentrer un itiniéraire et de le suivre)
- l'historique de tous les trajets effectués

# Le boitier :
Le boitier est un module Arduino, alimenté par une pile 9V

Attention :
- Le module Bluetooth Arduino est un module "BLE v1.0", utilisant la technologie Bluetooth BLE
- L'écran LED est un écran "LED MAX7219"

Branchement :

Module Bluetooth BLE v1.0 : 
  - VCC: 3.3V
  - GNG: GND
  - RX: Port 6
  - TX: Port 7

Module écran LED MAX7219:
  - VCC: 5V
  - GND: GND
  - DIN: Port 11
  - CS: Port 10
  - CLK: Port 13
