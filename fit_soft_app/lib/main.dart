/*
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
  double _weighFromScale = 0;

  //#region NUEVO

  final String targetMac = "B4:56:5D:7D:70:F2";
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? weightCharacteristic;  

  //#endregion

  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results);
    });
    _startScan();
  }
  
  Future<void> requestPermissions() async {
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5), androidUsesFineLocation: true,);
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.id.id.toUpperCase() == targetMac) {
          print("Báscula encontrada: ${r.device.name} - ${r.device.id}");
          targetDevice = r.device;
          connectedDevice = r.device;
          FlutterBluePlus.stopScan();
          await connectToDevice();//antiguo
          //_readWeightData(r);
          break;
        }
      }
    });
  }  

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

   Future<void> connectToDevice() async {
    try{
      if (targetDevice == null) return;
      if (connectedDevice == null) return;

      //await targetDevice!.connect(autoConnect: false);
      //print("Conectado a la báscula");

      var subscription = connectedDevice!.connectionState.listen((BluetoothConnectionState state) async {
          if (state == BluetoothConnectionState.disconnected) {
              // 1. typically, start a periodic timer that tries to 
              //    reconnect, or just call connect() again right now
              // 2. you must always re-discover services after disconnection!
              print("Test Angel 0: $connectedDevice");
              print("Test Angel: ${connectedDevice!.disconnectReason?.code} ${connectedDevice!.disconnectReason?.description}");
          }
      });

      //subscription.cancel();
      connectedDevice!.cancelWhenDisconnected(subscription, delayed:true, next:true);

      await Future.delayed(Duration(seconds: 1));
      //await connectedDevice!.connect(autoConnect: false);

      try {
        await connectedDevice!.disconnect();

        await connectedDevice!.connect(
          autoConnect: false,             // evita problemas de reconexión
          mtu: null,                      // evita conflicto mtu+autoConnect
          timeout: const Duration(seconds: 50),
        ).onError((e, st) async {
          print('Errorrr: $e');        
        });
  
      } on FlutterBluePlusException catch (e) {
        if (e.code == 133) {
          
          await connectedDevice!.connect(
            autoConnect: false,
            mtu: null,
            timeout: Duration(seconds: 40),
          );
        }
      }


      //await connectedDevice!.connect();
      //await connectedDevice!.connect(autoConnect: false, mtu: 11600);

      int mtu = await connectedDevice!.requestMtu(512);
      print("MTU negociado: $mtu");


      discoverServices();
      //readWeight(connectedDevice.ch);
    }
    catch(ex){
      print("Error en la báscula: $ex");
    }
  }

  void readWeight(BluetoothCharacteristic characteristic) async {
    List<int> val = await characteristic.read();

    print('Test');
  }

  void discoverServices() async {
    if (targetDevice == null) return;
    if (connectedDevice == null) return;

    //await connectedDevice!.connect();

    List<BluetoothService> services = await connectedDevice!.discoverServices();

    await connectedDevice!.disconnect();

    for (var service in services) {
      print("Servicio encontrado: ${service.uuid}");

      for (var char in service.characteristics) {
        print("  Característica: ${char.uuid}");
        if (char.properties.notify || char.properties.read) {
          // Aquí aún no sabemos cuál es la de peso, probamos todas
          await char.setNotifyValue(true);
          char.value.listen((value) {
            if (value.isNotEmpty) {
              parseWeight(value);
            }
          });
        }
      }
    }
  }

  void parseWeight(List<int> value) {
    // ⚠️ Depende del protocolo de la báscula — este es un ejemplo genérico
    final hexString = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ");
    print("Datos crudos HEX: $hexString");

    // Si el peso viene como entero en gramos (ejemplo)
    if (value.length >= 2) {
      int rawWeight = (value[0] << 8) + value[1];
      setState(() {
        weight = (rawWeight / 100).toStringAsFixed(2) + " kg";
      });
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
                    result.device.advName.isNotEmpty//.name.isNotEmpty
                        ? result.device.advName
                        : 
                        result.device.remoteId.str == "B4:56:5D:7D:70:F2"
                        ?
                        "Balanza"
                        :
                        "Dispositivo sin nombre",
                  ),
                  subtitle: Text(result.device.remoteId.str),
                  //onTap: () => connectToDevice(result.device),
                  onTap: () => connectToDevice(),
                );
              }).toList(),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Peso actual:",),
                  //Text('$_weighFromScale'),
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
*/

/*
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String? knownMacAndroid = "B4:56:5D:7D:70:F2"; // opcional (Android); iOS no usa MAC
final Guid weightScaleService = Guid("0000181D-0000-1000-8000-00805F9B34FB");
final Guid weightMeasurementChar = Guid("00002A9D-0000-1000-8000-00805F9B34FB");

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza BLE (Android/iOS)',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _found = <ScanResult>[];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _subscribed;
  StreamSubscription<List<int>>? _notifySub;

  String _status = "Listo";
  String? _reading;
  String? _activeService;
  String? _activeChar;

  @override
  void dispose() {
    _notifySub?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  Future<void> _ensurePerms() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Android <12
    ].request();
  }

  Future<void> _scanAndConnect() async {
    await _ensurePerms();
    setState(() {
      _status = "Escaneando BLE (10s)…";
      _found.clear();
      _reading = null;
      _activeService = null;
      _activeChar = null;
    });

    // Asegura que el adaptador esté ON
    if (!(await FlutterBluePlus.isSupported)) {
      setState(() => _status = "BLE no soportado en este dispositivo.");
      return;
    }
    if (FlutterBluePlus.adapterStateNow == null ||
        FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }

    // Inicia escaneo
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (_found.indexWhere((x) => x.device.remoteId == r.device.remoteId) == -1) {
          _found.add(r);
        }
      }
      setState(() {});
    }, onError: (_) {});

    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();
    await sub.cancel();

    // 1) Prioriza la MAC conocida (Android)
    ScanResult? pick;
    if (knownMacAndroid != null) {
      pick = _found.firstWhere(
        (r) => r.device.remoteId.str.toUpperCase() == knownMacAndroid!.toUpperCase(),
        orElse: () => _found.isNotEmpty ? _found.first : null as ScanResult,
      );
    } else if (_found.isNotEmpty) {
      pick = _found.first;
    }

    if (pick == null) {
      setState(() => _status = "No se encontró ningún periférico BLE (¿báscula es clásico SPP?).");
      return;
    }

    _device = pick.device;
    setState(() => _status = "Conectando a ${_device!.platformName.isNotEmpty ? _device!.platformName : _device!.remoteId.str}…");

    try {
      await _device!.connect(timeout: const Duration(seconds: 15));
    } catch (ex) {
      print("Tst error: $ex");
      //return null;
    }

    await _discoverAndSubscribe(_device!);
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice dev) async {
    setState(() => _status = "Descubriendo servicios…");
    final services = await dev.discoverServices();

    // 1) ¿Existe servicio Weight Scale / char Weight Measurement?
    BluetoothCharacteristic? std;
    for (final s in services) {
      if (s.serviceUuid == weightScaleService) {
        for (final c in s.characteristics) {
          if (c.characteristicUuid == weightMeasurementChar &&
              (c.properties.notify || c.properties.indicate)) {
            std = c;
            break;
          }
        }
      }
      if (std != null) break;
    }

    if (std != null) {
      await _subscribe(dev, std, label: "0x2A9D (Weight Measurement)");
      return;
    }

    // 2) Fallback: primera característica con Notify/Indicate
    BluetoothCharacteristic? anyNotify;
    outer:
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          anyNotify = c;
          _activeService = s.serviceUuid.str128;
          _activeChar = c.characteristicUuid.str128;
          break outer;
        }
      }
    }

    if (anyNotify == null) {
      setState(() => _status = "No hay características con Notify/Indicate en este dispositivo.");
      return;
    }

    await _subscribe(dev, anyNotify, label: "Primera Notify/Indicate");
  }

  Future<void> _subscribe(BluetoothDevice dev, BluetoothCharacteristic ch, {required String label}) async {
    _subscribed = ch;
    _activeService = ch.serviceUuid.str128;
    _activeChar = ch.characteristicUuid.str128;

    // Habilitar notificaciones
    await ch.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = ch.onValueReceived.listen((data) {
      final txt = _smartParse(Uint8List.fromList(data));
      setState(() => _reading = txt);
      // debug: print bytes
      // debugPrint("RX ${ch.characteristicUuid.str}: ${_toHex(data)}");
    });

    setState(() => _status = "Suscrito a $label. Súbete a la báscula.");
  }

  String _smartParse(Uint8List data) {
    // 1) Intento estándar 0x2A9D (flags + SFLOAT)
    final asStd = _tryParse2A9D(data);
    if (asStd != null) return "Peso: $asStd";

    // 2) Intento ASCII (algunos modelos BLE propietarios mandan texto)
    final asAscii = _tryAscii(data);
    if (asAscii != null) return "Texto: $asAscii";

    // 3) Hex
    return "Bytes: ${_toHex(data)}";
  }

  String? _tryParse2A9D(Uint8List data) {
    if (data.length < 3) return null;
    final flags = data[0];
    final isLb = (flags & 0x01) != 0;
    final bd = data.buffer.asByteData();
    final raw = bd.getUint16(1, Endian.little);
    double value = _sfloatToDouble(raw);

    // Heurística de escala por si envía 7235 en lugar de 72.35
    if (value > 5000) value *= 0.01;
    else if (value > 500) value *= 0.1;

    if (value <= 0 || value.isNaN || value.isInfinite) return null;
    final unit = isLb ? "lb" : "kg";
    return "${value.toStringAsFixed(2)} $unit";
  }

  String? _tryAscii(Uint8List data) {
    try {
      final s = ascii.decode(data, allowInvalid: true).trim();
      if (s.isEmpty) return null;
      if (!RegExp(r'\d').hasMatch(s)) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  // Utilidades
  String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  double _sfloatToDouble(int raw) {
    int mantissa = raw & 0x0FFF;
    int exponent = (raw & 0xF000) >> 12;
    if (mantissa >= 0x0800) mantissa -= 0x1000;
    if (exponent >= 0x8) exponent -= 0x10;
    return mantissa * _pow10(exponent);
  }
  double _pow10(int e) {
    const t = {
      -10: 1e-10, -9: 1e-9, -8: 1e-8, -7: 1e-7, -6: 1e-6,
      -5: 1e-5, -4: 1e-4, -3: 1e-3, -2: 1e-2, -1: 1e-1,
       0: 1.0, 1: 10.0, 2: 100.0, 3: 1000.0, 4: 10000.0,
       5: 1e5, 6: 1e6, 7: 1e7, 8: 1e8, 9: 1e9, 10: 1e10
    };
    return t[e] ?? _intPow(10.0, e);
  }
  double _intPow(double base, int exp) {
    double r = 1.0; bool pos = exp >= 0; int e = exp.abs();
    while (e > 0) { if ((e & 1) == 1) r *= base; base *= base; e >>= 1; }
    return pos ? r : 1.0 / r;
  }

  Future<void> _disconnect() async {
    _notifySub?.cancel();
    if (_subscribed != null) {
      try 
      { 
        await _subscribed!.setNotifyValue(false); 
      } 
      catch (ex) {
        print("error: $ex");
      }
    }
    await _device?.disconnect();
    setState(() {
      _status = "Desconectado";
      _reading = null;
      _activeService = null;
      _activeChar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Balanza BLE (Android/iOS)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, runSpacing: 8, children: [
              ElevatedButton.icon(
                onPressed: _scanAndConnect,
                icon: const Icon(Icons.search),
                label: const Text("Escanear y conectar"),
              ),
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text("Desconectar"),
              ),
            ]),
            const SizedBox(height: 8),
            Text("Estado: $_status"),
            if (_activeService != null && _activeChar != null) ...[
              const SizedBox(height: 8),
              Text("Suscrito a:\nServicio: $_activeService\nChar: $_activeChar",
                  style: const TextStyle(fontSize: 12)),
            ],
            const Divider(height: 24),
            if (_reading != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _reading!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _found.length,
                itemBuilder: (_, i) {
                  final r = _found[i];
                  return ListTile(
                    dense: true,
                    title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : "(sin nombre)"),
                    subtitle: Text("${r.device.remoteId.str} • RSSI ${r.rssi}"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        _device = r.device;
                        setState(() => _status = "Conectando a selección…");
                        
                        try { 
                          await _device!.connect(timeout: const Duration(seconds: 15)); 
                        }
                        catch (ex) 
                        {

                        }
                        await _discoverAndSubscribe(_device!);
                      },
                      child: const Text("Conectar"),
                    ),
                  );
                },
              ),
            ),
            const Text("Tip: muchas básculas solo emiten una notificación al detectar peso nuevo."),
          ],
        ),
      ),
    );
  }
}
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String? knownMacAndroid = "B4:56:5D:7D:70:F2";
final Guid weightScaleService = Guid("0000181D-0000-1000-8000-00805F9B34FB");
final Guid weightMeasurementChar = Guid("00002A9D-0000-1000-8000-00805F9B34FB");

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza BLE (fix GATT 133)',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _found = <ScanResult>[];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _subscribed;
  StreamSubscription<List<int>>? _notifySub;
  String _status = "Listo";
  String? _reading;
  String? _activeService;
  String? _activeChar;

  @override
  void dispose() {
    _notifySub?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  Future<void> _ensurePerms() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Android <12
    ].request();
  }

  Future<void> _scanAndConnect() async {
    await _ensurePerms();
    setState(() {
      _status = "Escaneando BLE (10s)…";
      _found.clear();
      _reading = null;
      _activeService = null;
      _activeChar = null;
    });

    if (!(await FlutterBluePlus.isSupported)) {
      setState(() => _status = "BLE no soportado.");
      return;
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }

    // Asegura no estar conectando a nada
    await FlutterBluePlus.stopScan();

    // Escaneo
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (_found.indexWhere((x) => x.device.remoteId == r.device.remoteId) == -1) {
          _found.add(r);
        }
      }
      setState(() {});
    });

    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();
    await sub.cancel();

    // Elegir candidato: prioriza MAC conocida (Android)
    ScanResult? pick;
    if (knownMacAndroid != null) {
      pick = _found.firstWhere(
        (r) => r.device.remoteId.str.toUpperCase() == knownMacAndroid!.toUpperCase(),
        orElse: () => _found.isNotEmpty ? _found.first : null as ScanResult,
      );
    } else if (_found.isNotEmpty) {
      pick = _found.first;
    }

    if (pick == null) {
      setState(() => _status = "No se encontró periférico BLE. (¿La báscula es SPP clásico?)");
      return;
    }

    _device = pick.device;
    setState(() => _status = "Conectando a ${_device!.platformName.isNotEmpty ? _device!.platformName : _device!.remoteId.str}…");

    final ok = await _safeConnectAndDiscover(_device!);
    if (!ok) {
      setState(() => _status = "Error: no se pudo conectar (mitigado GATT 133).");
    }
  }

  Future<bool> _safeConnectAndDiscover(BluetoothDevice dev) async {
    // Detén cualquier scan activo antes de conectar (mitiga 133)
    await FlutterBluePlus.stopScan();

    // Hasta 3 intentos con backoff y refresh de caché si hace falta
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Si ya está conectado, sigue
        if (await dev.connectionState.first == BluetoothConnectionState.connected) {
          // nada
        } else {
          /*
          await dev.connect(
            timeout: const Duration(seconds: 45),
            autoConnect: false, // evita problemas en Android
          );
          */

          await dev.connect(timeout: const Duration(seconds: 15), autoConnect: false);

          // (Opcional pero recomendado) sube prioridad y MTU en Android
          await dev.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high)
              .catchError((_) {});
          await dev.requestMtu(185).catchError((_) {});

          // Empareja aquí (si el dispositivo lo requiere)
          final bonded = await ensureBond(dev, pin: null /* o "123456" si aplica */);

          // Luego descubre servicios y suscríbete
          final ok = await _discoverAndSubscribe(dev);

          var tst = '';
        }

        // Pausas pequeñas ayudan al stack BLE de Android
        await Future.delayed(const Duration(milliseconds: 350));

        // Mejora enlace (Android): prioridad alta y MTU razonable
        if (Platform.isAndroid) {
          try { await dev.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high); } catch (_) {}
          try { await dev.requestMtu(185); } catch (_) {} // ignora si no soporta
        }

        await Future.delayed(const Duration(milliseconds: 250));

        final ok = await _discoverAndSubscribe(dev);
        if (ok) return true;

        // Si no hubo servicios/notify, intenta clearGattCache y reintenta
        if (Platform.isAndroid) {
          try { await dev.clearGattCache(); } catch (_) {}
        }

      } catch (e) {
        // Typical path for 133 -> reconectar
      } finally {
        // Si falló, desconecta “limpio” antes del siguiente intento
        if (await dev.connectionState.first == BluetoothConnectionState.connected) {
          try { await dev.disconnect(); } catch (_) {}
        }
        await Future.delayed(Duration(milliseconds: 400 * attempt)); // backoff 0.4s, 0.8s, 1.2s
      }
    }
    return false;
  }

  Future<bool> ensureBond(BluetoothDevice dev, {String? pin}) async {
    if (!Platform.isAndroid) return true; // iOS no tiene API explícita
    // Observa cambios de estado de bond (opcional para logs)
    final sub = dev.bondState.listen((s) {
       print("bondState: $s"); // bonding, bonded, none
    });
    try {
      await dev.createBond(
        timeout: 60,
        pin: pin != null ? Uint8List.fromList(utf8.encode(pin)) : null, // si conoces el PIN (p.ej. "123456")
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await sub.cancel();
    }
  }

  Future<bool> _discoverAndSubscribe(BluetoothDevice dev) async {
    setState(() => _status = "Descubriendo servicios…");
    List<BluetoothService> services = [];
    try {
      services = await dev.discoverServices();
    } catch (_) {
      // Si discovery cayó, deja que el caller haga clearGattCache y reintente
      return false;
    }

    // ¿Servicio estándar 0x181D / char 0x2A9D?
    BluetoothCharacteristic? std;
    for (final s in services) {
      if (s.serviceUuid == weightScaleService) {
        for (final c in s.characteristics) {
          if (c.characteristicUuid == weightMeasurementChar &&
              (c.properties.notify || c.properties.indicate)) {
            std = c; break;
          }
        }
      }
      if (std != null) break;
    }

    if (std != null) {
      await _subscribe(dev, std, label: "Weight Measurement (0x2A9D)");
      return true;
    }

    // Fallback: primera Notify/Indicate
    BluetoothCharacteristic? anyNotify;
    outer:
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) { anyNotify = c; break outer; }
      }
    }
    if (anyNotify == null) {
      setState(() => _status = "No hay características con Notify/Indicate.");
      return false;
    }
    await _subscribe(dev, anyNotify, label: "Primera Notify/Indicate");
    return true;
  }

  Future<void> _subscribe(BluetoothDevice dev, BluetoothCharacteristic ch, {required String label}) async {
    _subscribed?.setNotifyValue(false).catchError(() {});
    _subscribed = ch;

    _activeService = ch.serviceUuid.str128;
    _activeChar = ch.characteristicUuid.str128;

    await Future.delayed(const Duration(milliseconds: 200));
    await ch.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = ch.onValueReceived.listen((data) {
      final txt = _smartParse(Uint8List.fromList(data));
      setState(() => _reading = txt);
    });

    setState(() => _status = "Suscrito a $label. Súbete a la báscula.");
  }

  String _smartParse(Uint8List data) {
    final std = _tryParse2A9D(data);
    if (std != null) return "Peso: $std";
    final ascii = _tryAscii(data);
    if (ascii != null) return "Texto: $ascii";
    return "Bytes: ${_toHex(data)}";
  }

  String? _tryParse2A9D(Uint8List data) {
    if (data.length < 3) return null;
    final flags = data[0];
    final isLb = (flags & 0x01) != 0;
    final bd = data.buffer.asByteData();
    final raw = bd.getUint16(1, Endian.little);
    double value = _sfloatToDouble(raw);
    if (value > 5000) value *= 0.01; else if (value > 500) value *= 0.1;
    if (!(value > 0) || value.isNaN || value.isInfinite) return null;
    final unit = isLb ? "lb" : "kg";
    return "${value.toStringAsFixed(2)} $unit";
  }

  String? _tryAscii(Uint8List data) {
    try {
      final s = ascii.decode(data, allowInvalid: true).trim();
      if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
      return s;
    } catch (_) { return null; }
  }

  String _toHex(List<int> b) => b.map((x)=>x.toRadixString(16).padLeft(2,'0')).join(' ');
  double _sfloatToDouble(int raw) {
    int m = raw & 0x0FFF; int e = (raw & 0xF000) >> 12;
    if (m >= 0x0800) m -= 0x1000; if (e >= 0x8) e -= 0x10;
    return m * _pow10(e);
  }

  double _pow10(int e) {
    const t = {-10:1e-10,-9:1e-9,-8:1e-8,-7:1e-7,-6:1e-6,-5:1e-5,-4:1e-4,-3:1e-3,-2:1e-2,-1:1e-1,0:1,1:10,2:100,3:1000,4:10000,5:1e5,6:1e6,7:1e7,8:1e8,9:1e9,10:1e10};
    //return t[e] ?? _intPow(10.0, e);
    return _intPow(10.0, e);
  }

  double _intPow(double base, int exp) {
    double r = 1.0; bool pos = exp >= 0; int e = exp.abs();
    while (e > 0) { if ((e & 1) == 1) r *= base; base *= base; e >>= 1; }
    return pos ? r : 1.0 / r;
  }

  Future<void> _disconnect() async {
    _notifySub?.cancel();

    try { 
      await _subscribed?.setNotifyValue(false); 
    } catch (ex) {
      print("Error 1: $ex");
    }

    try { 
      await _device?.disconnect(); 
    } catch (ex) {
      print("Error 2: $ex");
    }

    setState(() {
      _status = "Desconectado";
      _reading = null;
      _activeService = null;
      _activeChar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Balanza BLE (fix 133)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, runSpacing: 8, children: [
              ElevatedButton.icon(
                onPressed: _scanAndConnect,
                icon: const Icon(Icons.search),
                label: const Text("Escanear y conectar"),
              ),
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.link_off),
                label: const Text("Desconectar"),
              ),
            ]),
            const SizedBox(height: 8),
            Text("Estado: $_status"),
            if (_activeService != null && _activeChar != null) ...[
              const SizedBox(height: 8),
              Text("Suscrito a:\nServicio: $_activeService\nChar: $_activeChar",
                  style: const TextStyle(fontSize: 12)),
            ],
            const Divider(height: 24),
            if (_reading != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _reading!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _found.length,
                itemBuilder: (_, i) {
                  final r = _found[i];
                  return ListTile(
                    dense: true,
                    title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : "(sin nombre)"),
                    subtitle: Text("${r.device.remoteId.str} • RSSI ${r.rssi}"),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await FlutterBluePlus.stopScan();
                        _device = r.device;
                        setState(() => _status = "Conectando a selección…");
                        final ok = await _safeConnectAndDiscover(_device!);
                        if (!ok) setState(() => _status = "Error: no se pudo conectar.");
                      },
                      child: const Text("Conectar"),
                    ),
                  );
                },
              ),
            ),
            const Text("Tip: muchas básculas solo notifican tras detectar peso nuevo."),
          ],
        ),
      ),
    );
  }
}
