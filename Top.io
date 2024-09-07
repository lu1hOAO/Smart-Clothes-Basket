// #include <SoftwareSerial.h>
#include <EEPROM.h>
#include <Arduino.h>
#include <AccelStepper.h>

#include <Wire.h>
#include "SSD1306Ascii.h"
#include "SSD1306AsciiWire.h"

// Declaration for an SSD1306 display connected to I2C (SDA, SCL pins)
// On an arduino UNO:       A4(SDA), A5(SCL)
// On an arduino MEGA:      20(SDA), 21(SCL)
#define RST_PIN -1
#define I2C_ADDRESS 0x3C // 0x3C for 128x32
SSD1306AsciiWire oled;

// SoftwareSerial r200Serial(2, 3); // RX, TX pins for SoftwareSerial
#define r200Serial Serial3 // use Serial1 on pins 19(Rx) and 18(Tx)

// 3 buttons used for mode switching / start / type selection
int button1 = 26;     // switch mode / type 1: personal
int button2 = 24;     // start mode / type 2: light colored
int button3 = 22;     // type 3: dark colored

// Define pin connections for Nema step
const int dirPin1  = 4;
const int stepPin1 = 5;
const int dirPin2  = 6;
const int stepPin2 = 7;

// Define positions for the most left, most right, and middle
const long leftNEMA  = 0;
const long rightNEMA = -1325 * 64; // must be a multiple of 64? (1375 * 64)

const long leftBYJ  = 0;
const long rightBYJ = 2048;

// Define motor interface type for Nema step control
#define motorInterfaceType 1

#define NEMA1_PIN1 8
#define NEMA1_PIN2 9
#define NEMA1_PIN3 10

#define NEMA2_PIN1 11
#define NEMA2_PIN2 12
#define NEMA2_PIN3 13

AccelStepper Nema1(motorInterfaceType, stepPin1, dirPin1);
AccelStepper Nema2(motorInterfaceType, stepPin2, dirPin2);

// Define pin connections for stepper 28BYJ48 + ULN2003 
#define FULLSTEP 4 // parameters for full step
#define HALFSTEP 8 // parameters for half step

#define BYJ1_PIN1 43
#define BYJ1_PIN2 47
#define BYJ1_PIN3 41
#define BYJ1_PIN4 45

#define BYJ2_PIN1 42
#define BYJ2_PIN2 46
#define BYJ2_PIN3 40
#define BYJ2_PIN4 44

AccelStepper BYJ1(FULLSTEP, BYJ1_PIN1, BYJ1_PIN2, BYJ1_PIN3, BYJ1_PIN4);
AccelStepper BYJ2(FULLSTEP, BYJ2_PIN1, BYJ2_PIN2, BYJ2_PIN3, BYJ2_PIN4);

// parameters to determine function finish
bool finish_read = false;
bool finish_drop = false;
bool finish_add = false;
bool finish_remove = false;

enum State {
  STATE_READ,
  STATE_READ_START,
  STATE_ADD,
  STATE_ADD_START,
  STATE_REMOVE,
  STATE_REMOVE_START
};

struct RFIDTag {
  byte epc[12];
  byte group;
};

#define MAX_TAGS 10
#define TAG_SIZE sizeof(RFIDTag)

RFIDTag tags[MAX_TAGS];

void clearEEPROM() {
  for (int i = 0; i < EEPROM.length(); i++) {
    EEPROM.write(i, 0xFF);  // Write 0xFF to each byte of EEPROM
  }
  Serial.println("EEPROM cleared");
}

void writeTagToEEPROM(int index, RFIDTag tag) {
  int startAddress = index * TAG_SIZE;
  for (int i = 0; i < TAG_SIZE; i++) {
    EEPROM.write(startAddress + i, ((byte*)&tag)[i]);
  }
}

RFIDTag readTagFromEEPROM(int index) {
  RFIDTag tag;
  int startAddress = index * TAG_SIZE;
  for (int i = 0; i < TAG_SIZE; i++) {
    ((byte*)&tag)[i] = EEPROM.read(startAddress + i);
  }
  return tag;
}

void addTag(byte* epc, byte group) {
  RFIDTag newTag;
  memcpy(newTag.epc, epc, 12);
  newTag.group = group;

  for (int i = 0; i < MAX_TAGS; i++) {
    RFIDTag storedTag = readTagFromEEPROM(i);
    if (storedTag.epc[0] == 0xFF) { // Assuming 0xFF means an empty slot
      writeTagToEEPROM(i, newTag);
      Serial.println("Tag added to EEPROM");
      return;
    }
  }
  Serial.println("No space left to store the tag");
}

byte matchTag(byte* epc) {
  for (int i = 0; i < MAX_TAGS; i++) {
    RFIDTag storedTag = readTagFromEEPROM(i);
    if (memcmp(storedTag.epc, epc, 12) == 0) {
      return storedTag.group;
    }
  }
  return 0xFF; // Return 0xFF if no match is found
}

void removeTag(byte* epc) {
  for (int i = 0; i < MAX_TAGS; i++) {
    RFIDTag storedTag = readTagFromEEPROM(i);
    if (memcmp(storedTag.epc, epc, 12) == 0) {
      RFIDTag emptyTag = {{0xFF}, 0xFF}; // Empty tag
      writeTagToEEPROM(i, emptyTag);
      Serial.println("Tag removed from EEPROM");
      return;
    }
  }
  Serial.println("Tag not found");
}

void printTag(RFIDTag tag) {
  Serial.print("EPC: ");
  for (int i = 0; i < 12; i++) {
    Serial.print(tag.epc[i], HEX);
    Serial.print(" ");
  }
  Serial.print(" | Group: ");
  Serial.println(tag.group, HEX);
}

void printAllTags() {
  for (int i = 0; i < MAX_TAGS; i++) {
    RFIDTag storedTag = readTagFromEEPROM(i);
    if (storedTag.epc[0] != 0xFF) {  // Assuming 0xFF means an empty slot
      printTag(storedTag);
    }
  }
}

void moveScrew(byte group) {
  finish_drop = false;
  while (!finish_read) {
    // Move from left to right

    if (group != 0x01 && group != 0x02 && group != 0x03) {
      finish_read = true;
    }
    else if (group == 0x01) {
      finish_read = true;
      moveDoor();
    }
    else if (Nema1.currentPosition() == leftNEMA && Nema2.currentPosition() == leftNEMA) {
      Nema1.moveTo(rightNEMA * (group - 1));
      Nema2.moveTo(rightNEMA * (group - 1));
    }
    else if (finish_drop == false && (Nema1.currentPosition() == rightNEMA * (group - 1) && Nema2.currentPosition() == rightNEMA * (group - 1))) {
      moveDoor();
    }
    // Move from right to left
    else if (finish_drop == true && (Nema1.currentPosition() == rightNEMA * (group - 1) && Nema2.currentPosition() == rightNEMA * (group - 1))) {
      Nema1.moveTo(leftNEMA);
      Nema2.moveTo(leftNEMA);
    }

    // Run the motors
    Nema1.run();
    Nema2.run();

    if (Nema1.currentPosition() == leftNEMA && Nema2.currentPosition() == leftNEMA) {
      finish_read = true; // Set finish flag to true when movement is complete
    }
  }
}

/* ----- the motors should be moving in the opposite direction when closing v ----- */
void moveDoor() {
  while (!finish_drop) {
    // open and close basket door
    if (BYJ1.currentPosition() == leftBYJ && BYJ2.currentPosition() == leftBYJ) {
      BYJ1.moveTo(rightBYJ);
      BYJ2.moveTo(rightBYJ);
    }
    else if (BYJ1.currentPosition() == rightBYJ && BYJ2.currentPosition() == rightBYJ) {
      BYJ1.moveTo(leftBYJ);
      BYJ2.moveTo(leftBYJ);
    }

    BYJ1.run();
    BYJ2.run();

    if (BYJ1.currentPosition() == leftBYJ && BYJ2.currentPosition() == leftBYJ) {
      finish_drop = true; // Set finish flag to true when movement is complete
    }
  }
}

void readTagOperation() {
  displayString("Group 6: Clothes Sort", "----- READ START ----", "Searching for tag ...", "");

  // continuous read EPC until a tag is read
  while (!finish_read) {
    Serial.println("----- READ -----");
    clearSerialBuffer();
    // Command frame for single polling
    uint8_t cmd[] = {0xAA, 0x00, 0x22, 0x00, 0x00, 0x22, 0xDD};
    r200Serial.write(cmd, sizeof(cmd));
    Serial.println("Command sent");
    // wait for response
    delay(250);

    Serial.println(r200Serial.available());
    
    if (r200Serial.available()) {
      uint8_t start, command;
      uint8_t response[22];
      uint8_t epc[12];
      start = r200Serial.read();
      command = r200Serial.read();
      if (start == 0xAA && command == 0x02) {   // EPC tag read
        for (int i = 0; i < 22; i++) { 
          response[i] = r200Serial.read();
        }
        for (int i = 0; i < 12; i++) {
          epc[i] = response[i + 6];
        }
        for (int i = 0; i < 22; i++) {
          Serial.print(response[i], HEX);
          Serial.print(" ");
        }
        Serial.println();
        for (int i = 0; i < 12; i++) {
          Serial.print(epc[i], HEX);
          Serial.print(" ");
        }
        Serial.println();

        Serial.print("Match EPC Response: ");
        byte foundGroup = matchTag(epc);
        // Serial.print()
        if (foundGroup == 0x01) {
          Serial.println("Tag found in group: 1. personal clothing");
          displayString("Group 6: Clothes Sort", "----- READ START ----", "1. Personal clothing", "");
          delay(250);
        } else if (foundGroup == 0x02) {
          Serial.println("Tag found in group: 2. light colored");
          displayString("Group 6: Clothes Sort", "----- READ START ----", "2. Light colored", "");
          delay(250);
        } else if (foundGroup == 0x03) {
          Serial.println("Tag found in group: 3. dark colored");
          displayString("Group 6: Clothes Sort", "----- READ START ----", "3. Dark colored", "");
          delay(250);
        } else {
          Serial.println("Tag not found in any group");
          displayString("Group 6: Clothes Sort", "----- READ START ----", "# Not in any group #", "");
          delay(250);
        }  
        printAllTags();
        moveScrew(foundGroup);
        // finish_read = true;
      }
    }
  }
}

void addTagOperation() {
  int group = 0;
  displayString("Group 6: Clothes Sort", "----- ADD START -----", "Push buttons 1, 2, 3", "for group selection");
  while (group == 0) {
    if (digitalRead(button1) == LOW) {
      Serial.println("add tag to 1. personal");
      group = 1;
    } else if (digitalRead(button2) == LOW) {
      Serial.println("add tag to 2. light colored");
      group = 2;
    } else if (digitalRead(button3) == LOW) {
      Serial.println("add tag to 3. dark colored");
      group = 3;
    } else {
      group = 0;
    }
  }

  displayString("Group 6: Clothes Sort", "----- ADD START -----", "Searching for tag ...", "");

  while (!finish_add) {
    Serial.println("----- ADD -----");
    clearSerialBuffer();
    // Command frame for single polling
    uint8_t cmd[] = {0xAA, 0x00, 0x22, 0x00, 0x00, 0x22, 0xDD};
    r200Serial.write(cmd, sizeof(cmd));
    Serial.println("Command sent");
    // wait for response
    delay(250);

    if (r200Serial.available()) {
      uint8_t start, command;
      uint8_t response[22];
      uint8_t epc[12];
      start = r200Serial.read();
      command = r200Serial.read();
      if (start == 0xAA && command == 0x02) {   // EPC tag read
        for (int i = 0; i < 22; i++) { 
          response[i] = r200Serial.read();
        }
        for (int i = 0; i < 12; i++) {
          epc[i] = response[i + 6];
        }
        for (int i = 0; i < 12; i++) {
          Serial.print(epc[i], HEX);
          Serial.print(" ");
        }
        Serial.println();   

        if (matchTag(epc) != 0xFF) {
          removeTag(epc);
        }
        addTag(epc, group);
        displayString("Group 6: Clothes Sort", "----- ADD START -----", "Added to group:", getGroupString(group));
        printAllTags();
        finish_add = true;
        delay(250);
      }
    }
  }
  finish_add = true;
}

void removeTagOperation() {
  displayString("Group 6: Clothes Sort", "---- REMOVE START ---", "Searching for tag ...", "");

  while (!finish_remove) {
    Serial.println("----- executing remove process -----");
    clearSerialBuffer();
    // Command frame for single polling
    uint8_t cmd[] = {0xAA, 0x00, 0x22, 0x00, 0x00, 0x22, 0xDD};
    r200Serial.write(cmd, sizeof(cmd));
    Serial.println("Command sent");
    // wait for response
    delay(250);

    if (r200Serial.available()) {
      uint8_t start, command;
      uint8_t response[22];
      uint8_t epc[12];
      start = r200Serial.read();
      command = r200Serial.read();
      if (start == 0xAA && command == 0x02) {   // EPC tag read
        for (int i = 0; i < 22; i++) { 
          response[i] = r200Serial.read();
        }
        for (int i = 0; i < 12; i++) {
          epc[i] = response[i + 6];
        }
        for (int i = 0; i < 12; i++) {
          Serial.print(epc[i], HEX);
          Serial.print(" ");
        }
        Serial.println();
        
        removeTag(epc);
        displayString("Group 6: Clothes Sort", "---- REMOVE START ---", "Tag removed", "");
        printAllTags();
        finish_remove = true;
        delay(250);
      }
    }
  }
}

// empty serial buffer for receiving new packet
void clearSerialBuffer() {
  for (int i = 0; i < 24; i++) {
    r200Serial.read();
  }
}

// Set emission rate for rfid module
void setRate() {
  // command: 
  // uint8_t cmd[] = {0xBB, 0x00, 0xB6, 0x00, 0x02, 0x04, 0xE2, 0x9E, 0x7E}; // 18.5/12.5 dBm (0.6m)
  // uint8_t cmd[] = {0xBB, 0x00, 0xB6, 0x00, 0x02, 0x06, 0xA4, 0x62, 0x7E}; // 23/17 dBm (1m)
  uint8_t cmd[] = {0xBB, 0x00, 0xB6, 0x00, 0x02, 0x07, 0xD0, 0x8F, 0x7E}; // 26/20 dBm (2m)
  r200Serial.write(cmd, sizeof(cmd));
  Serial.println("Set Rate");
  delay(500);
  if (r200Serial.available()) { // Ideal response: BB 01 0C 00 01 00 0E 7E
    uint8_t response[8];
    for (int i = 0; i < 8; i++) {
      response[i] = r200Serial.read();
    }
    for (int i = 0; i < 8; i++) {
      Serial.print(response[i], HEX);
      Serial.print(" ");
    }
    Serial.println();
  } else {
    Serial.println("Rate set up fail");
  }
}

const char* getStateString(int state) {
  switch (state) {
    case STATE_READ:
      return "-------- READ -------";
    case STATE_READ_START:
      return "----- READ START ----";
    case STATE_ADD:
      return "-------- ADD --------";
    case STATE_ADD_START:
      return "----- ADD START -----";
    case STATE_REMOVE:
      return "------- REMOVE ------";
    case STATE_REMOVE_START:
      return "---- REMOVE START ---";
  }
}

const char* getGroupString(int group) {
  switch (group) {
    case 1:
      return "1. Personal clothing";
    case 2:
      return "2. Light colored";
    case 3:
      return "3. Dark colored";
    default:
      return "not available";
  }
}

// print 4 strings on OLED i2c display
void displayString(const char* string1, const char* string2, const char* string3, const char* string4) {
  oled.clear();               // Clear the display

  oled.println(string1);
  oled.println(string2);
  oled.println(string3);
  oled.println(string4);
}

State currentState = STATE_READ;
State nextState = STATE_READ;
State previousState = STATE_READ;

void setup() {
  Serial.begin(115200);     // Initialize Serial Monitor for debugging
  r200Serial.begin(115200); // Initialize SoftwareSerial for R200

  Wire.begin();
  Wire.setClock(400000L);
  oled.begin(&Adafruit128x32, I2C_ADDRESS);
  oled.setFont(Adafruit5x7);
  
  clearEEPROM();

  setRate();
  // push button mode control
  pinMode(button1, INPUT);
  pinMode(button2, INPUT);
  pinMode(button3, INPUT);

  // Nema pins 
  pinMode(NEMA1_PIN1, OUTPUT);
  pinMode(NEMA1_PIN2, OUTPUT);
  pinMode(NEMA1_PIN3, OUTPUT);
  pinMode(NEMA2_PIN1, OUTPUT);
  pinMode(NEMA2_PIN2, OUTPUT);
  pinMode(NEMA2_PIN3, OUTPUT);

  // Set all to HIGH for 1/2 microstepping
  digitalWrite(NEMA1_PIN1, HIGH);
  digitalWrite(NEMA1_PIN2, LOW);
  digitalWrite(NEMA1_PIN3, LOW);
  digitalWrite(NEMA2_PIN1, HIGH);
  digitalWrite(NEMA2_PIN2, LOW);
  digitalWrite(NEMA2_PIN3, LOW);

  // initial speed and target position for Nema
	Nema1.setMaxSpeed(1000 * 8 * 4);
	Nema1.setAcceleration(100 * 4);
	Nema1.setSpeed(1000 * 8);

  Nema2.setMaxSpeed(1000 * 8 * 4);
	Nema2.setAcceleration(100 * 4);
	Nema2.setSpeed(1000 * 8);

  Nema1.setCurrentPosition(leftNEMA);
  Nema2.setCurrentPosition(leftNEMA);

  // initial speed and target position for BYJ
  BYJ1.setMaxSpeed(500.0);
  BYJ1.setAcceleration(50.0);

  BYJ2.setMaxSpeed(500.0);
  BYJ2.setAcceleration(50.0);

  BYJ1.setCurrentPosition(leftBYJ);
  BYJ2.setCurrentPosition(leftBYJ);

  // prompt
  Serial.println("R200 UHF RFID Module Initialized");
  Serial.println("Press button to read tag.");
  displayString("Group 6: Clothes Sort", getStateString(currentState), "Button 1: switch mode", "Button 2: start mode");
}

// ----- To do list and functions -----
// check valid tag read (must end in 7E ?)
// add sort buffer time

void loop() {
  if (previousState != currentState) {
    displayString("Group 6: Clothes Sort", getStateString(currentState), "Button 1: switch mode", "Button 2: start mode");
  }
  // finite state machine
  switch (currentState) {
    case STATE_READ:
      finish_read = false;
      if (digitalRead(button1) == LOW) {
        nextState = STATE_ADD;
      }
      if (digitalRead(button2) == LOW) {
        nextState = STATE_READ_START;
      }
      break;
    case STATE_READ_START:
      if (finish_read) {
        nextState = STATE_READ;
      } else {
        readTagOperation();
        nextState = STATE_READ_START;
      }
      break;
    case STATE_ADD:
      finish_add = false;
      if (digitalRead(button1) == LOW) {
        nextState = STATE_REMOVE;
      }
      if (digitalRead(button2) == LOW) {
        nextState = STATE_ADD_START;
      }
      break;
    case STATE_ADD_START:
      if (finish_add) {
        nextState = STATE_ADD;
      } else {
        addTagOperation();
        nextState = STATE_ADD_START;
      }
      break;
    case STATE_REMOVE:
      finish_remove = false;
      if (digitalRead(button1) == LOW) {
        nextState = STATE_READ;
      }
      if (digitalRead(button2) == LOW) {
        nextState = STATE_REMOVE_START;
      }
      break;
    case STATE_REMOVE_START:
      if (finish_remove) {
        nextState = STATE_REMOVE;
      } else {
        removeTagOperation();
        nextState = STATE_REMOVE_START;
      }
      break;
    default: 
      nextState = STATE_READ;
      break;
  }
  previousState = currentState;
  currentState = nextState;
  delay(200);
}
