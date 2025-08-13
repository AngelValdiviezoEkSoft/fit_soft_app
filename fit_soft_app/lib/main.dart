
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza Bluetooth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BluetoothScaleScreen(),
    );
  }
}

class BluetoothScaleScreen extends StatefulWidget {
  const BluetoothScaleScreen({super.key});

  @override
  State<BluetoothScaleScreen> createState() => _BluetoothScaleScreenState();
}

class _BluetoothScaleScreenState extends State<BluetoothScaleScreen> {
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  String weight = "0.0 kg";

  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results);
    });
    _startScan();
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {

    if (device.isConnected) {
      await device.disconnect();
      await Future.delayed(Duration(seconds: 2));
    }

    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    await _stopScan();

    //await device.disconnect();
    //await Future.delayed(Duration(seconds: 2));

    final bsSubscription = device.bondState.listen((value) {
        print("$value prev:{$device.prevBondState}");
    });

    // cleanup: cancel subscription when disconnected
    device.cancelWhenDisconnected(bsSubscription);

    try {
      // Conectar si no está conectado
      if (await device.connectionState.first != BluetoothConnectionState.connected) {        

        await device.connect(autoConnect: false);

        // Force the bonding popup to show now (Android Only) 
        await device.createBond();

        // remove bond
        await device.removeBond();

        // wait until connected
        await device.connectionState.firstWhere((s) => s == BluetoothConnectionState.connected);

        //await Future.delayed(const Duration(milliseconds: 400));
      }
    } catch (e) {
      // Ignorar error si ya estaba conectado
      print('Test error: $e');
    }

    // Esperar hasta que realmente esté conectado
    await device.connectionState.firstWhere(
      (state) => state == BluetoothConnectionState.connected,
    );

    //setState(() => connectedDevice = device);

    // Ahora sí descubrir servicios
    services = await device.discoverServices();

    //setState(() => connectedDevice = device);

    _listenWeightData();
  }

  void _listenWeightData() {
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        // Aquí deberías poner el UUID específico de tu balanza si lo conoces
        if (characteristic.properties.notify) {
          characteristic.setNotifyValue(true).then((_) {
            characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                final data = String.fromCharCodes(value);
                setState(() => weight = data);
              }
            });
          });
        }
      }
    }
  }

  Future<void> disconnectDevice() async {
    await connectedDevice?.disconnect();
    setState(() {
      connectedDevice = null;
      weight = "0.0 kg";
    });
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balanza Bluetooth')),
      body: connectedDevice == null
          ? ListView(
              children: scanResults.map((result) {
                return ListTile(
                  title: Text(
                    result.device.name.isNotEmpty
                        ? result.device.name
                        : 
                        result.device.remoteId.str == "B4:56:5D:7D:70:F2"
                        ?
                        "Balanza"
                        :
                        "Dispositivo sin nombre",
                  ),
                  subtitle: Text(result.device.remoteId.str),
                  onTap: () => connectToDevice(result.device),
                );
              }).toList(),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Peso actual:",),
                  Text(weight),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: disconnectDevice,
                    child: const Text("Desconectar"),
                  )
                ],
              ),
            ),
      floatingActionButton: connectedDevice == null
          ? FloatingActionButton(
              onPressed: _startScan,
              child: const Icon(Icons.search),
            )
          : null,
    );
  }
}

/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:reactive_ble_mobile/reactive_ble_mobile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BalanceBluetoothPage(),
    );
  }
}

class BalanceBluetoothPage extends StatefulWidget {
  const BalanceBluetoothPage({super.key});

  @override
  State<BalanceBluetoothPage> createState() => _BalanceBluetoothPageState();
}

class _BalanceBluetoothPageState extends State<BalanceBluetoothPage> {
  //final ReactiveBleMobile _ble = ReactiveBleMobile();
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final List<DiscoveredDevice> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  String _weightData = "No conectado";
  String? _connectedDeviceId;

  // UUIDs de servicio y característica de balanza (cambia según tu dispositivo)
  final Uuid _serviceUuid = Uuid.parse("0000181d-0000-1000-8000-00805f9b34fb"); // Weight Scale Service
  final Uuid _characteristicUuid = Uuid.parse("00002a9d-0000-1000-8000-00805f9b34fb"); // Weight Measurement Characteristic

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statusScan = await Permission.bluetoothScan.request();
    final statusConnect = await Permission.bluetoothConnect.request();
    final statusLocation = await Permission.locationWhenInUse.request();

    if (statusScan.isDenied ||
        statusConnect.isDenied ||
        statusLocation.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos Bluetooth y Ubicación requeridos')),
      );
    }
  }

  void _startScan() {
    _devices.clear();
    _scanSubscription?.cancel();

    _scanSubscription = _ble.scanForDevices(
      withServices: [_serviceUuid], // opcional: filtra por servicio balanza
    ).listen((device) {
      if (!_devices.any((d) => d.id == device.id)) {
        setState(() {
          _devices.add(device);
        });
      }
    }, onError: (error) {
      setState(() {
        _devices.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error escaneando: $error')));
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void _connectToDevice(DiscoveredDevice device) async {
    _stopScan();

    _connectionSubscription?.cancel();

    _connectionSubscription = _ble.connectToDevice(id: device.id).listen(
      (connectionState) {
        setState(() {
          _connectionState = connectionState.connectionState;
          _connectedDeviceId = device.id;
          if (_connectionState == DeviceConnectionState.disconnected) {
            _weightData = "Desconectado";
          }
        });

        if (_connectionState == DeviceConnectionState.connected) {
          _subscribeWeight(device.id);
        }
      },
      onError: (error) {
        setState(() {
          _connectionState = DeviceConnectionState.disconnected;
          _weightData = "Error de conexión: $error";
        });
      },
    );
  }

  void _subscribeWeight(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: _serviceUuid,
      characteristicId: _characteristicUuid,
    );

    _ble.subscribeToCharacteristic(characteristic).listen((data) {
      final weight = _parseWeight(data);
      setState(() {
        _weightData = "$weight kg";
      });
    }, onError: (error) {
      setState(() {
        _weightData = "Error lectura peso: $error";
      });
    });
  }

  double _parseWeight(List<int> data) {
    // Ejemplo de parseo para protocolo común de balanzas BLE:
    // El peso está en los bytes 1 y 2 en unidades de 0.005kg (según estándar Bluetooth Weight Scale)
    if (data.length < 3) return 0.0;
    int weightRaw = data[1] | (data[2] << 8);
    return weightRaw * 0.005;
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Balanza Bluetooth"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _scanSubscription == null ? _startScan : _stopScan,
              child: Text(_scanSubscription == null ? "Escanear balanzas" : "Detener escaneo"),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (_, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name.isNotEmpty ? device.name : "Sin nombre"),
                    subtitle: Text(device.id),
                    trailing: (_connectedDeviceId == device.id &&
                            _connectionState == DeviceConnectionState.connected)
                        ? const Text("Conectado", style: TextStyle(color: Colors.green))
                        : ElevatedButton(
                            onPressed: () => _connectToDevice(device),
                            child: const Text("Conectar"),
                          ),
                  );
                },
              ),
            ),
            const Divider(),
            Text("Estado conexión: $_connectionState"),
            const SizedBox(height: 10),
            Text("Peso: $_weightData", style: const TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
*/