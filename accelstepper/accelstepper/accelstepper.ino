#include "AccelStepper.h"
// 电机步进方式定义
#define FULLSTEP 4 //全步进参数
#define HALFSTEP 8 //半步进参数
// 定义步进电机引脚
#define motor1Pin1 8 // 一号28BYJ48连接的ULN2003电机驱动板引脚 in1
#define motor1Pin2 9 // 一号28BYJ48连接的ULN2003电机驱动板引脚 in2
#define motor1Pin3 10 // 一号28BYJ48连接的ULN2003电机驱动板引脚 in3
#define motor1Pin4 11 // 一号28BYJ48连接的ULN2003电机驱动板引脚 in4

#define motor2Pin1 4 // 二号28BYJ48连接的ULN2003电机驱动板引脚 in1
#define motor2Pin2 5 // 二号28BYJ48连接的ULN2003电机驱动板引脚 in2
#define motor2Pin3 6 // 二号28BYJ48连接的ULN2003电机驱动板引脚 in3
#define motor2Pin4 7 // 二号28BYJ48连接的ULN2003电机驱动板引脚 in4
// 定义两个步进电机对象
// 1号电机设置为半步进运行，2号电机设置为全步进运行
AccelStepper stepper1(FULLSTEP, motor1Pin1, motor1Pin3, motor1Pin2, motor1Pin4);
AccelStepper stepper2(FULLSTEP, motor2Pin1, motor2Pin3, motor2Pin2, motor2Pin4);


void setup() {
 stepper1.setMaxSpeed(500.0); // 1号电机最大速度500
 stepper1.setAcceleration(50.0); // 1号电机加速度50.0
 stepper2.setMaxSpeed(500.0); // 2号电机最大速度500
 stepper2.setAcceleration(50.0); // 2号电机加速度50.0
}
void loop() {
 if ( stepper1.currentPosition() == 0 && stepper2.currentPosition() == 0 ){
 // 1号电机转动半周
 stepper1.moveTo(2048);
 // 2号电机转动一周
 stepper2.moveTo(2048);

 } else if ( stepper1.currentPosition() == 2048 && stepper2.currentPosition() == 2048 ){
 // 1号电机转动半周
 stepper1.moveTo(0);
 // 2号电机转动一周
 stepper2.moveTo(0);
 }

 stepper1.run(); // 1号电机运行
 stepper2.run(); // 2号电机运行
}