// 左馬達控制設定
const byte LEFT1 = 8;  //IN1
const byte LEFT2 = 9;  //IN2
const byte LEFT_PWM = 10;

// 右馬達控制設定
const byte RIGHT1 = 7;  //IN3
const byte RIGHT2 = 6;  //IN4
const byte RIGHT_PWM = 5;

// 設定PWM輸出值（代表的是車子的速度）
byte LEFT_motorSpeed = 90;
byte RIGHT_motorSpeed = 120;

// 按鈕設定
const byte BUTTON_START = 2;//purple
const byte BUTTON_STOP = 3;//green
const byte BUTTON_TYPE1 = 4;  // 白色衣物,brown
const byte BUTTON_TYPE2 = 11; // 貼身衣物, orange
const byte BUTTON_TYPE3 = 12; // 其他衣物, yellow

// 訊號輸出PIN
const byte SIGNAL_PIN = 13; // 代表訊號輸出的PIN腳

// flag
bool isMoving = false;
bool stopRequested = false;

void setup() {
  // 設定每一個PIN的模式
  pinMode(LEFT1, OUTPUT);
  pinMode(LEFT2, OUTPUT);
  pinMode(LEFT_PWM, OUTPUT);
  pinMode(RIGHT1, OUTPUT);
  pinMode(RIGHT2, OUTPUT);
  pinMode(RIGHT_PWM, OUTPUT);

  // 設定按鈕的模式
  pinMode(BUTTON_START, INPUT_PULLUP);
  pinMode(BUTTON_STOP, INPUT_PULLUP);
  pinMode(BUTTON_TYPE1, INPUT_PULLUP);
  pinMode(BUTTON_TYPE2, INPUT_PULLUP);
  pinMode(BUTTON_TYPE3, INPUT_PULLUP);

  // 設定訊號輸出的PIN
  pinMode(SIGNAL_PIN, OUTPUT);
  digitalWrite(SIGNAL_PIN, LOW); // 初始設置為low

  // 停止馬達
  stopMotor();
}

void loop() {
  if (digitalRead(BUTTON_START) == LOW) {
    isMoving = true;
    stopRequested = false;
    delay(300); // 消抖動
  }
  
  if (digitalRead(BUTTON_STOP) == LOW) {
    stopRequested = true;
    isMoving = false;
    stopMotor();
    digitalWrite(SIGNAL_PIN, LOW); // 結束設為low
    delay(300); // 消抖動
  }

  if (isMoving && !stopRequested) {
    if (digitalRead(BUTTON_TYPE1) == LOW) {
      moveToBasket1();
      returnToStart(2000); // 回到原位，時間與前進時間相同
      sendSignal();
      delay(300); // 消抖動
    } else if (digitalRead(BUTTON_TYPE2) == LOW) {
      moveToBasket2();
      returnToStart(4000); // 回到原位，時間與前進時間相同
      sendSignal();
      delay(300); // 消抖動
    } else if (digitalRead(BUTTON_TYPE3) == LOW) {
      moveToBasket3();
      returnToStart(6000); // 回到原位，時間與前進時間相同
      sendSignal();
      delay(300); // 消抖動
    }
  }
}

void forward() {  // 前進
  //左輪
  digitalWrite(LEFT1, HIGH);
  digitalWrite(LEFT2, LOW);
  analogWrite(LEFT_PWM, LEFT_motorSpeed);
  
  //右輪
  digitalWrite(RIGHT1, LOW);
  digitalWrite(RIGHT2, HIGH);
  analogWrite(RIGHT_PWM, RIGHT_motorSpeed);
}

void backward() { // 後退
  digitalWrite(LEFT1, LOW);
  digitalWrite(LEFT2, HIGH);
  analogWrite(LEFT_PWM, LEFT_motorSpeed);

  digitalWrite(RIGHT1, HIGH);
  digitalWrite(RIGHT2, LOW);
  analogWrite(RIGHT_PWM, RIGHT_motorSpeed);
}

void stopMotor() {  // 停止，兩輪速度為0
  analogWrite(LEFT_PWM, 0);
  analogWrite(RIGHT_PWM, 0);
}

void moveToBasket1() {
  forward();
  delay(2000);  // 假設到第一個籃子需要2秒
  stopMotor();
  delay(5000);
  // 這裡可以加入控制底部打開的程式碼
}

void moveToBasket2() {
  forward();
  delay(4000);  // 假設到第二個籃子需要4秒
  stopMotor();
  delay(5000);
  // 這裡可以加入控制底部打開的程式碼
}

void moveToBasket3() {
  forward();
  delay(6000);  // 假設到第三個籃子需要6秒
  stopMotor();
  delay(5000);
  // 這裡可以加入控制底部打開的程式碼
}

void returnToStart(int moveTime) {
  backward();
  delay(moveTime);  // 根據前進的時間返回
  stopMotor();
}

void sendSignal() {
  digitalWrite(SIGNAL_PIN, HIGH);  // 將訊號pin設為High
  delay(2000);                      // 保持High 2000毫秒
  digitalWrite(SIGNAL_PIN, LOW);   // 再將訊號引腳設為Low
}
