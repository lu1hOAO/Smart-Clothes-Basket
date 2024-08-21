#include <LiquidCrystal_PCF8574.h>

LiquidCrystal_PCF8574 lcd(0x27);  // i2c address，0x27 or 0x3F

void setup()
{
  lcd.begin(16, 2); // initialize LCD
  lcd.setBacklight(255);
  lcd.clear();
  lcd.setCursor(0,0); //(col,row)
  lcd.print("~* first line!");
  lcd.setCursor(0,1);
  lcd.print("*~ second line!");
  
} // setup()

void loop()
{
  
} // loop()
