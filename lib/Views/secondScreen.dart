import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:modbus_client/modbus_client.dart';
import 'package:modbus_client_tcp/modbus_client_tcp.dart';

class MySecondScreen extends StatefulWidget {
  final int userRegister;
  int userValue;
  MySecondScreen(this.userRegister, this.userValue);

  @override
  _MySecondScreenState createState() => _MySecondScreenState();
}

class _MySecondScreenState extends State<MySecondScreen> {
  int globalVar = 0;
  int countDown = 0;
  int initialUserValue = 0;
  double _progressValue = 0.0;
  late Isolate _isolate;
  late ReceivePort _receivePort;

  @override
  void initState() {
    super.initState();
    initialUserValue = widget.userValue;
    _initIsolate();
  }

  @override
  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
    super.dispose();
  }

  void _initIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort);
    _receivePort.listen((message) {
      if (message is int) {
        setState(() {
          globalVar = message;
          print("Received value: $globalVar");
        });
      }
    });

    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      updateValues();
      sendModbusWriteMessage(widget.userValue, widget.userRegister); //!
      _updateProgress();
      if (countDown == 10) {
        timer.cancel();
        print("Countdown finished");
      }
    });
  }

  void _updateProgress() {
    setState(() {
      _progressValue += 0.1;
      if (_progressValue > 1.0) {
        _progressValue = 1.0;
      }
    });
  }

  void updateValues() {
    widget.userValue++;
    countDown++;
  }

  static void _isolateEntryPoint(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final serverIp = await ModbusClientTcp.discover("127.0.0.60");
    print("Server IP: $serverIp");

    if (serverIp != null) {
      final modbusClient = ModbusClientTcp(serverIp, unitId: 1);
      await modbusClient.connect();

      final value = ModbusInt16Register(
        name: "data",
        type: ModbusElementType.holdingRegister,
        address: 0, // Address needs to be set accordingly
        onUpdate: (self) {
          sendPort.send(self.value);
        },
      );

      await modbusClient.send(value.getReadRequest());
    }
  }

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

    if (serverIp != null) {
      var modbusClient = ModbusClientTcp(serverIp, unitId: 1);

      await modbusClient.connect();
      await modbusClient.send(value.getWriteRequest(userValue));
      await modbusClient.disconnect();
    }

    sendPort.send('Write operation completed');
  }

  @override
  Widget build(BuildContext context) {
    final userNumber = widget.userValue;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () {
            Navigator.pop(context); // Go back
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            LinearProgressIndicator(
              minHeight: 50,
              value: _progressValue,
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 50),
            Text("Initial Value: $initialUserValue"),
            Text('Changed Value: $userNumber'),
          ],
        ),
      ),
    );
  }
}
