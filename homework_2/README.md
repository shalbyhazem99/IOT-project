# Homework #1
## Assignment
Read the [traffic.csv](./traffic.csv) file
Keep only publish messages coming from the following topics:
▪ factory/department1/section1/plc
▪ factory/department3/section3/plc
▪ factory/department1/section1/hydraulic_valve
▪ factory/department3/section3/hydraulic_valve
Send the «value» field of the original message as MQTT messages to the thingspeak channel in order to fill charts and activate indicators.
## Result
The final schema is the following: 
![schema](./schema.png)
The result is discussed in the [report](./report.pdf) file
