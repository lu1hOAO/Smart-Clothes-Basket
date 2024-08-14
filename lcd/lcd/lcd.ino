#include <LiquidCrystal_PCF8574.h>

LiquidCrystal_PCF8574 lcd(0x3f);
void setup() {
  // put your setup code here, to run once:
  lcd.begin(16,2);
  lcd.setBacklight(255);
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("*~ first line");
  lcd.setCursor(0,1);
  lcd.print("~* second line.");
}

void loop() {
  // put your main code here, to run repeatedly:

}
