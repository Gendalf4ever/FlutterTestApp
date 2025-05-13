import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test_application/Views/secondScreen.dart';
import 'package:modbus_client/modbus_client.dart';
import 'package:modbus_client_tcp/modbus_client_tcp.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  TextEditingController valueController = TextEditingController();
  int? selectedRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: "Ваше число"),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: selectedRegister,
              onChanged: (int? newValue) {
                setState(() {
                  selectedRegister = newValue;
                  modbusRead(selectedRegister!);
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Номер регистра',
              ),
              items: List.generate(10, (index) => index)
                  .map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
            ),
            ElevatedButton(
              child: const Text('Enter'),
              onPressed: () {
                if (valueController.text.isEmpty || selectedRegister == null) {
                  // Check if selectedRegister is null
                  const Text("Value or register is null");
                  return;
                }

                int userValue = int.parse(valueController.text);

                print(userValue);
                sendModbusWriteMessage(userValue, selectedRegister!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MySecondScreen(
                      selectedRegister!,
                      userValue,
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  void modbusRead(int userRegister) async {
    var value = ModbusInt16Register(
        name: "data",
        type: ModbusElementType.holdingRegister,
        address: userRegister,
        onUpdate: (self) => setState(() {
              print(self.value);
              valueController.text =
                  double.parse(self.value.toString()).toStringAsFixed(0);
            }));

    var serverIp =
        await ModbusClientTcp.discover("127.0.0.60"); // IP of the server
    print(serverIp);

    if (serverIp == null) {
      return;
    }

    var modbusClient = ModbusClientTcp(serverIp, unitId: 1);

    // Send a read request
    await modbusClient.connect();
    await modbusClient.send(value.getReadRequest());
    await modbusClient.disconnect();
  } // modbusRead

  void sendModbusWriteMessage(int userValue, int userRegister) {
    ReceivePort receivePort = ReceivePort();
    Isolate.spawn(modbusWriteIsolate, {
      'userValue': userValue,
      'userRegister': userRegister,
      'sendPort': receivePort.sendPort,
    });
    receivePort.listen((message) {
      print('Message from isolate: $message');
      receivePort.close();
    });
  }

  static void modbusWriteIsolate(Map<String, dynamic> message) async {
    int userValue = message['userValue'];
    int userRegister = message['userRegister'];
    SendPort sendPort = message['sendPort'];

    var value = ModbusInt16Register(
      name: "data",
      type: ModbusElementType.holdingRegister,
      address: userRegister,
      onUpdate: (self) => print(self),
    );

    var serverIp =
        await ModbusClientTcp.discover("127.0.0.60"); // IP of the server
    print(serverIp);

    if (serverIp == null) {
      return;
    }

    var modbusClient = ModbusClientTcp(serverIp, unitId: 1);

    // Send a write request
    await modbusClient.connect();
    await modbusClient.send(value.getWriteRequest(userValue));
    await modbusClient.disconnect();

    sendPort.send('Write operation completed');
  } //modbusWrite
}
