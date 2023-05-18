#include <SoftwareSerial.h>
#include <LedControl.h>

// Définir les broches de la plaque LED MAX7219
const int DIN_PIN = 11;  // Broche de données
const int CLK_PIN = 13;  // Broche d'horloge
const int CS_PIN = 10;   // Broche de sélection

// Créer une instance de LedControl pour gérer la plaque LED
LedControl lc = LedControl(DIN_PIN, CLK_PIN, CS_PIN, 4);

// Définir les broches du module bluetooth BLE
SoftwareSerial bluetooth(6, 7);  // RX, TX


//Initialisation de la variable contenant le charactere recu par le BLE
char receivedChar = 'z';

//Initialisation de la variable contenant le charactere pour le cligno gauche
char receivedGauche = 'b';

//Initialisation de la variable contenant le charactere pour le cligno droit
char receivedDroite = 'd';

//Initialisation de la variable contenant le charactere pour le frein
char receivedFrein = 'f';


/*
* CLIGNOTANT:
- a allume le droit, b l'eteint
- c allume le gauche, d l'eteint

FREIN:
- e allume le frein, f l'eteint
*/

void setup() {

  // Initialisation des plaques de LED
  for (int i = 0; i < 4; i++) {
    lc.shutdown(i, false);  // Activer la matrice
    lc.setIntensity(i, 8);  // Définir l'intensité lumineuse (0-15)
    lc.clearDisplay(i);     // Effacer l'affichage
  }

  Serial.begin(9600);
  while (!Serial)
    ;

  bluetooth.begin(9600);  // Start Bluetooth serie communication with Bluetooth module
}

void loop() {
  if (bluetooth.available()) {  // Si des données sont disponibles sur le module Bluetooth

    receivedChar = bluetooth.read();
    Serial.write(receivedChar);  // Affiche le caractère reçu sur le moniteur série
  }

  // si c'est un char pour le cligno gauche on lui attribu
  if (receivedChar == 'a' || receivedChar == 'b') {
    receivedGauche = receivedChar;

    // si c'est l'ordre d'allumer à gauche on eteint celui de droitr
    if(receivedChar == 'a'){
      receivedDroite = 'd';
    }
  }

  // idem pour le coté droit
  if (receivedChar == 'c' || receivedChar == 'd') {
    receivedDroite = receivedChar;
      if(receivedChar == 'c'){
      receivedGauche = 'b';
    }
  }

  if (receivedChar == 'e' || receivedChar == 'f') {
    receivedFrein = receivedChar;
  }


  if (receivedFrein == 'f') {
    lc.clearDisplay(1);
    lc.clearDisplay(2);
  }

  if (receivedFrein == 'e') {
    lc.setRow(1, 0, B11111000);
    lc.setRow(1, 1, B11111100);
    lc.setRow(1, 2, B11111110);
    lc.setRow(1, 3, B11111110);
    lc.setRow(1, 4, B11111110);
    lc.setRow(1, 5, B11111110);
    lc.setRow(1, 6, B11111100);
    lc.setRow(1, 7, B11111000);

    lc.setRow(2, 0, B00011111);
    lc.setRow(2, 1, B00111111);
    lc.setRow(2, 2, B01111111);
    lc.setRow(2, 3, B01111111);
    lc.setRow(2, 4, B01111111);
    lc.setRow(2, 5, B01111111);
    lc.setRow(2, 6, B00111111);
    lc.setRow(2, 7, B00011111);
  }

  if (receivedDroite == 'c') {
    lc.setRow(3, 0, B00010000);
    lc.setRow(3, 1, B00110000);
    lc.setRow(3, 2, B01111111);
    lc.setRow(3, 3, B11111111);
    lc.setRow(3, 4, B11111111);
    lc.setRow(3, 5, B01111111);
    lc.setRow(3, 6, B00110000);
    lc.setRow(3, 7, B00010000);

    delay(500);  // Fait une pause de 500ms
    lc.clearDisplay(3);
    delay(500);  // Fait une pause de 500ms
  }


  if (receivedGauche == 'a') {
    lc.setRow(0, 0, B00001000);
    lc.setRow(0, 1, B00001100);
    lc.setRow(0, 2, B11111110);
    lc.setRow(0, 3, B11111111);
    lc.setRow(0, 4, B11111111);
    lc.setRow(0, 5, B11111110);
    lc.setRow(0, 6, B00001100);
    lc.setRow(0, 7, B00001000);

    delay(500);  // Fait une pause de 500ms
    lc.clearDisplay(0);
    delay(500);  // Fait une pause de 500ms
  }
}