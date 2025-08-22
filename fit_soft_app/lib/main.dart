
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

/*
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
*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza Bluetooth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BluetoothScalePage(),
    );
  }
}

class BluetoothScalePage extends StatefulWidget {
  const BluetoothScalePage({super.key});

  @override
  State<BluetoothScalePage> createState() => _BluetoothScalePageState();
}

class _BluetoothScalePageState extends State<BluetoothScalePage> {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _weightCharacteristic;
  List<BluetoothDevice> _scanResults = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String _currentWeight = "0.0";
  String _weightUnit = "kg";
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  // UUIDs comunes para balanzas (ajustar según tu balanza específica)
  final String _serviceUUID = "0000180f-0000-1000-8000-00805f9b34fb"; // Battery Service como ejemplo
  final String _characteristicUUID = "00002a19-0000-1000-8000-00805f9b34fb"; // Battery Level como ejemplo

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    try {
      // Verificar si el dispositivo soporta Bluetooth
      if (!await FlutterBluePlus.isSupported) {
        _showError('Este dispositivo no soporta Bluetooth');
        return;
      }

      // Solicitar permisos necesarios
      await _requestPermissions();

      // Verificar si Bluetooth está encendido usando adapterStateNow
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _showError('Por favor, enciende el Bluetooth');
        // Intentar encender Bluetooth automáticamente
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print('No se puede encender Bluetooth automáticamente: $e');
        }
        return;
      }

    } catch (e) {
      print('Error inicializando Bluetooth: $e');
      _showError('Error inicializando Bluetooth: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
          statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
          statuses[Permission.location] != PermissionStatus.granted) {
        _showError('Permisos de Bluetooth necesarios no concedidos');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
  
      if (state != BluetoothAdapterState.on) {
        throw Exception('Bluetooth no está encendido');
      }

      // Detener escaneo previo si existe
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      // Comenzar escaneo con configuración específica
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );

      // Escuchar resultados del escaneo usando onScanResults
      final scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          if (mounted) {
            setState(() {
              _scanResults = results
                  .map((r) => r.device)
                  .where((device) => 
                      device.platformName.isNotEmpty || 
                      device.remoteId.toString().isNotEmpty)
                  .toList();
            });
          }
        },
        onError: (error) {
          print('Error en scanResults: $error');
        },
      );

      // Esperar a que termine el escaneo
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first;

      // Cancelar suscripción
      await scanSubscription.cancel();

    } catch (e) {
      print('Error durante el escaneo: $e');
      _showError('Error durante el escaneo: ${e.toString()}');
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        _isScanning = false;
      });

      // Detener escaneo si está activo
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      // Desconectar dispositivo previo si existe
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      // Conectar al nuevo dispositivo con timeout
      await device.connect(
        autoConnect: false,
        mtu: null,
      ).timeout(
        const Duration(seconds: 50),
        onTimeout: () {
          throw TimeoutException('Timeout conectando al dispositivo', const Duration(seconds: 10));
        },
      );
      
      setState(() {
        _connectedDevice = device;
        _isConnected = true;
      });

      // Escuchar cambios de conexión
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (mounted) {
          setState(() {
            _isConnected = state == BluetoothConnectionState.connected;
          });
          
          if (state == BluetoothConnectionState.disconnected) {
            _disconnectFromDevice();
          }
        }
      });

      // Descubrir servicios después de conectar exitosamente
      await _discoverServices();

      _showSuccess('Conectado a ${device.platformName.isEmpty ? 'Dispositivo' : device.platformName}');

    } on TimeoutException catch (e) {
      print('Timeout al conectar: $e');
      _showError('Timeout al conectar al dispositivo');
    } catch (e) {
      print('Error al conectar: $e');
      _showError('Error al conectar: ${e.toString().replaceAll('FlutterBluePlusException: ', '')}');
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      
      print('Servicios encontrados: ${services.length}');
      
      for (BluetoothService service in services) {
        print('Servicio: ${service.uuid}');
        
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print('Característica: ${characteristic.uuid}');
          print('Propiedades: notify=${characteristic.properties.notify}, read=${characteristic.properties.read}, write=${characteristic.properties.write}');
          
          // Buscar características que puedan contener datos de peso
          if (characteristic.properties.notify) {
            try {
              _weightCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              
              _characteristicSubscription?.cancel();
              _characteristicSubscription = characteristic.onValueReceived.listen(
                _onWeightDataReceived,
                onError: (error) {
                  print('Error en notificación: $error');
                },
              );
              
              print('Suscrito a notificaciones de: ${characteristic.uuid}');
            } catch (e) {
              print('Error configurando notificaciones: $e');
            }
          }
          
          // Intentar leer características legibles
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              if (value.isNotEmpty) {
                _onWeightDataReceived(value);
                _weightCharacteristic ??= characteristic;
              }
            } catch (e) {
              print('Error leyendo característica ${characteristic.uuid}: $e');
            }
          }
        }
      }
      
      if (_weightCharacteristic == null) {
        _showError('No se encontraron características de peso compatibles');
      }
      
    } catch (e) {
      print('Error al descubrir servicios: $e');
      _showError('Error descubriendo servicios: $e');
    }
  }

  void _onWeightDataReceived(List<int> data) {
    try {
      // Procesar los datos de peso recibidos
      // Este procesamiento depende del protocolo específico de tu balanza
      
      if (data.isNotEmpty) {
        // Ejemplo simple: convertir bytes a string
        String weightString = utf8.decode(data, allowMalformed: true);
        
        // O interpretar como número directamente
        // double weight = data[0] + (data[1] << 8); // Para datos de 16 bits
        
        setState(() {
          _currentWeight = _parseWeightData(data);
        });
        
        print('Datos de peso recibidos: $data');
        print('Peso interpretado: $_currentWeight $_weightUnit');
      }
    } catch (e) {
      print('Error al procesar datos de peso: $e');
    }
  }

  String _parseWeightData(List<int> data) {
    // Implementar el parsing específico según el protocolo de tu balanza
    // Este es un ejemplo genérico
    
    if (data.length >= 2) {
      // Ejemplo: interpretar como valor de 16 bits little-endian
      int rawValue = data[0] + (data[1] << 8);
      double weight = rawValue / 100.0; // Dividir por 100 si viene en centésimas
      return weight.toStringAsFixed(2);
    } else if (data.length == 1) {
      // Ejemplo: un solo byte
      return data[0].toStringAsFixed(2);
    }
    
    return "0.00";
  }

  void _disconnectFromDevice() async {
    try {
      _characteristicSubscription?.cancel();
      _connectionSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      print('Error al desconectar: $e');
    }
    
    if (mounted) {
      setState(() {
        _connectedDevice = null;
        _isConnected = false;
        _weightCharacteristic = null;
        _currentWeight = "0.0";
      });
    }
  }

  Future<void> _readWeight() async {
    if (_weightCharacteristic == null) {
      _showError('No hay característica de peso disponible');
      return;
    }
    
    try {
      if (_weightCharacteristic!.properties.read) {
        List<int> value = await _weightCharacteristic!.read();
        _onWeightDataReceived(value);
      } else {
        _showError('La característica no es legible');
      }
    } on FlutterBluePlusException catch (e) {
      print('Error FBP al leer peso: ${e.code} - ${e.description}');
      _showError('Error al leer peso: ${e.description}');
    } catch (e) {
      print('Error al leer peso: $e');
      _showError('Error al leer peso: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanza Bluetooth'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnectFromDevice,
              tooltip: 'Desconectar',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Display de peso
            Card(
              elevation: 8,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Text(
                      'Peso Actual',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_currentWeight $_weightUnit',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'Conectado' : 'Desconectado',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botones de control
            if (_isConnected) ...[
              ElevatedButton(
                onPressed: _readWeight,
                child: const Text('Leer Peso'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _disconnectFromDevice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Desconectar'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: _isScanning 
                  ? const Text('Escaneando...')
                  : const Text('Buscar Balanza'),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Lista de dispositivos encontrados
            if (!_isConnected && _scanResults.isNotEmpty) ...[
              const Text(
                'Dispositivos encontrados:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = _scanResults[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.scale),
                        title: Text(
                          device.platformName.isNotEmpty 
                            ? device.platformName 
                            : 'Dispositivo sin nombre',
                        ),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text('Conectar'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            if (_isScanning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
*/

/*
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: BlePage());
  }
}

class BlePage extends StatefulWidget {
  const BlePage({super.key});
  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;
  String _status = 'Idle';

  // Ajusta uno de los dos criterios:
  final String targetName = "MiDispositivoBLE"; // <-- preferible
  // final Guid serviceUuid = Guid("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx");

  @override
  void dispose() {
    _scanSub?.cancel();
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    try { 
      await _device?.disconnect(); 
    } 
    catch (ex) {
      print('Error al desconectar: $ex');
    }
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    // Android 12+ → Nearby devices; Android ≤11 → location
    if ((await _androidSdkInt()) >= 31) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      return statuses.values.every((s) => s.isGranted);
    } else {
      final statuses = await [Permission.location].request();
      return statuses.values.every((s) => s.isGranted);
    }
  }

  Future<int> _androidSdkInt() async {
    // Pequeño helper para evitar dependencias extra
    // Si ya usas device_info_plus, úsalo en su lugar.
    // Asumimos 31+ si no se puede obtener (conservador)
    try {
      final ver = Platform.environment['ANDROID_SDK_VERSION'];
      return ver != null ? int.tryParse(ver) ?? 31 : 31;
    } catch (_) {
      return 31;
    }
  }

  Future<void> _startScanAndConnect() async {
    setState(() => _status = 'Solicitando permisos…');
    if (!await _ensurePermissions()) {
      setState(() => _status = 'Permisos denegados');
      return;
    }

    setState(() => _status = 'Escaneando…');
    _isScanning = true;

    final foundCompleter = Completer<BluetoothDevice>();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.remoteId.str;

        if (name == "B4:56:5D:7D:70:F2") {
          if (!foundCompleter.isCompleted) {
            foundCompleter.complete(r.device);
          }
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 55),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    BluetoothDevice device;
    try {
      device = await foundCompleter.future.timeout(const Duration(seconds: 55));
    } catch (_) {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      await _scanSub?.cancel();
      setState(() => _status = 'No encontrado');
      return;
    }

    await FlutterBluePlus.stopScan();
    _isScanning = false;
    await _scanSub?.cancel();

    // pequeña pausa para evitar 133 al salir del escaneo
    await Future.delayed(const Duration(milliseconds: 250));

    setState(() => _status = 'Conectando…');
    _device = device;

    // MUY IMPORTANTE: autoConnect: false y timeout
    try {
      await device.connect(
        timeout: const Duration(seconds: 25),
        autoConnect: false,
      );

      // (opcional) negociar MTU después de conectar
      try {
        await device.requestMtu(247);
      } 
      catch (ex) {
        print('Error al ejecutar requestMtu: $ex');
      }

      // Descubrir servicios
      await device.discoverServices();

      setState(() => _status = 'Conectado ✔');
    } on FlutterBluePlusException catch (e) {
      // Si ves android-code:133, probamos a limpiar GATT (Android)
      if (Platform.isAndroid) {
        try { 
          await device.clearGattCache(); 
        } 
        catch (ex) {
          print('Error al limpiar la cache: $ex');
        }
      }
      await device.disconnect();
      setState(() => _status = 'Error al conectar: ${e.code} (${e.description})');
    } catch (e) {
      await device.disconnect();
      setState(() => _status = 'Error inesperado: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE demo (anti-133)")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status),
            const SizedBox(height: 12),
            if (_isScanning) const CircularProgressIndicator(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isScanning ? null : _startScanAndConnect,
              child: const Text('Escanear y Conectar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await _cleanup();
                setState(() => _status = 'Desconectado');
              },
              child: const Text('Desconectar'),
            ),
          ],
        ),
      ),
    );
  }
}

*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Báscula Smart Scale',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ScaleApp(),
    );
  }
}

class ScaleApp extends StatefulWidget {
  @override
  _ScaleAppState createState() => _ScaleAppState();
}

class _ScaleAppState extends State<ScaleApp> {
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  
  // Datos de la báscula
  double weight = 0.0;
  double bodyFat = 0.0;
  double muscle = 0.0;
  double water = 0.0;
  double bone = 0.0;
  double visceral = 0.0;
  double bmr = 0.0;
  double bmi = 0.0;
  
  bool isScanning = false;
  bool isConnected = false;
  String connectionStatus = "Desconectado";
  
  StreamSubscription? scanSubscription;
  StreamSubscription? connectionSubscription;

  @override
  void initState() {
    super.initState();
    checkBluetoothState();
  }

  void checkBluetoothState() async {
    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Bluetooth'),
          content: Text('Por favor, activa el Bluetooth para continuar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void startScan() {
    if (!isScanning) {
      setState(() {
        isScanning = true;
        devicesList.clear();
      });

      FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
      
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.id.str == "B4:56:5D:7D:70:F2") {//serial de báscula
            setState(() {
              devicesList.add(result.device);
            });
          }
          /*
          if (!devicesList.contains(result.device) && 
              result.device.platformName.isNotEmpty) {
            setState(() {
              devicesList.add(result.device);
            });
          }
          */
        }
      });

      Timer(Duration(seconds: 10), () {
        stopScan();
      });
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    setState(() {
      isScanning = false;
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      connectionStatus = "Conectando...";
    });

    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
        isConnected = true;
        connectionStatus = "Conectado a ${device.platformName}";
      });

      // Descubrir servicios
      services = await device.discoverServices();
      
      // Buscar servicios de la báscula y suscribirse a notificaciones
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              parseScaleData(value);
            });
          }
        }
      }

      // Escuchar desconexiones
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            isConnected = false;
            connectedDevice = null;
            connectionStatus = "Desconectado";
          });
        }
      });

    } catch (e) {
      setState(() {
        connectionStatus = "Error de conexión: ${e.toString()}";
      });
    }
  }

  void parseScaleData(List<int> data) {
    // Esta función necesitará ser adaptada según el protocolo específico de tu báscula
    // Aquí hay un ejemplo básico de parsing
    
    if (data.length >= 20) {
      setState(() {
        // Ejemplo de parsing - necesitarás ajustar según el protocolo real
        weight = ((data[2] << 8) + data[3]) / 10.0;
        bodyFat = ((data[4] << 8) + data[5]) / 10.0;
        water = ((data[6] << 8) + data[7]) / 10.0;
        muscle = ((data[8] << 8) + data[9]) / 10.0;
        bone = ((data[10] << 8) + data[11]) / 10.0;
        visceral = ((data[12] << 8) + data[13]) / 10.0;
        bmr = 0;//((data[14] << 8) + data[15]);
        
        // Calcular BMI (necesitarías la altura del usuario)
        // bmi = weight / (height * height);
      });
    }
  }

  void disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Báscula Smart Scale'),
        backgroundColor: Colors.blue[800],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Estado de conexión
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isConnected ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Botones de acción
            if (!isConnected) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isScanning ? null : startScan,
                        icon: isScanning 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.search),
                        label: Text(isScanning ? 'Buscando...' : 'Buscar Báscula'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de dispositivos
              if (devicesList.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Dispositivos encontrados:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: devicesList.length,
                    itemBuilder: (context, index) {
                      BluetoothDevice device = devicesList[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.monitor_weight, color: Colors.blue),
                          title: Text(device.platformName.isNotEmpty ? device.platformName : 'Dispositivo desconocido'),
                          subtitle: Text(device.remoteId.toString()),
                          trailing: ElevatedButton(
                            onPressed: () => connectToDevice(device),
                            child: Text('Conectar'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else ...[
              // Datos de la báscula cuando está conectada
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Peso principal
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.monitor_weight,
                              color: Colors.white,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${weight.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Peso Corporal',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Otras métricas
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildMetricCard('Grasa Corporal', '${bodyFat.toStringAsFixed(1)}%', Colors.orange, Icons.opacity),
                          _buildMetricCard('Agua', '${water.toStringAsFixed(1)}%', Colors.blue, Icons.water_drop),
                          _buildMetricCard('Músculo', '${muscle.toStringAsFixed(1)}%', Colors.green, Icons.fitness_center),
                          _buildMetricCard('Hueso', '${bone.toStringAsFixed(1)}%', Colors.grey, Icons.abc),
                          _buildMetricCard('Grasa Visceral', '${visceral.toStringAsFixed(0)}', Colors.red, Icons.favorite),
                          _buildMetricCard('TMB', '${bmr.toStringAsFixed(0)} kcal', Colors.purple, Icons.local_fire_department),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Botón desconectar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: disconnect,
                          icon: Icon(Icons.bluetooth_disabled),
                          label: Text('Desconectar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Báscula Smart Scale',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ScaleApp(),
    );
  }
}

class ScaleApp extends StatefulWidget {
  const ScaleApp({super.key});

  @override
  State<ScaleApp> createState() => _ScaleAppState();
}

class _ScaleAppState extends State<ScaleApp> {
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  
  // Datos de la báscula
  double weight = 0.0;
  double bodyFat = 0.0;
  double muscle = 0.0;
  double water = 0.0;
  double bone = 0.0;
  double visceral = 0.0;
  double bmr = 0.0;
  double bmi = 0.0;
  
  bool isScanning = false;
  bool isConnected = false;
  String connectionStatus = "Desconectado";
  
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  @override
  void initState() {
    super.initState();
    checkBluetoothState();
  }

  void checkBluetoothState() async {
    try {
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Bluetooth'),
              content: const Text('Por favor, activa el Bluetooth para continuar.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connectionStatus = "Error verificando Bluetooth: ${e.toString()}";
        });
      }
    }
  }

  void startScan() {
    if (!isScanning) {
      setState(() {
        isScanning = true;
        devicesList.clear();
      });

      try {
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        
        scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult result in results) {
            if (result.device.id.str == "B4:56:5D:7D:70:F2") {//serial de báscula
              setState(() {
                devicesList.add(result.device);
              });
            }
          
          }
        });

        Timer(const Duration(seconds: 10), () {
          stopScan();
        });
      } catch (e) {
        setState(() {
          connectionStatus = "Error al escanear: ${e.toString()}";
          isScanning = false;
        });
      }
    }
  }

  void stopScan() {
    try {
      FlutterBluePlus.stopScan();
      scanSubscription?.cancel();
      setState(() {
        isScanning = false;
      });
    } catch (e) {
      setState(() {
        connectionStatus = "Error al detener escaneo: ${e.toString()}";
        isScanning = false;
      });
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      connectionStatus = "Conectando...";
    });

    try {
      // Timeout para la conexión
      await device.connect(timeout: const Duration(seconds: 55));
      
      if (mounted) {
        setState(() {
          connectedDevice = device;
          isConnected = true;
          connectionStatus = "Conectado a ${device.platformName}";
        });
      }

      // Descubrir servicios
      try {
        services = await device.discoverServices();
        
        // Buscar servicios de la báscula y suscribirse a notificaciones
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              try {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  parseScaleData(value);
                });
              } catch (e) {
                print("Error suscribiendo a notificaciones: $e");
              }
            }
          }
        }
      } catch (e) {
        print("Error descubriendo servicios: $e");
      }

      // Escuchar desconexiones
      connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            isConnected = false;
            connectedDevice = null;
            connectionStatus = "Desconectado";
          });
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          connectionStatus = "Error de conexión: ${e.toString()}";
        });
      }
    }
  }

  void parseScaleData(List<int> data) {
    // Esta función necesitará ser adaptada según el protocolo específico de tu báscula
    // Aquí hay un ejemplo básico de parsing
    
    if (data.isNotEmpty && mounted) {
      setState(() {
        // Ejemplo de parsing - necesitarás ajustar según el protocolo real
        if (data.length >= 4) {
          // Parsing básico del peso (puede variar según el protocolo)
          weight = ((data[1] << 8) + data[2]) / 10.0;
        }
        
        if (data.length >= 20) {
          // Ejemplo de parsing completo - ajustar según protocolo real
          try {
            weight = ((data[2] << 8) + data[3]) / 10.0;
            bodyFat = ((data[4] << 8) + data[5]) / 10.0;
            water = ((data[6] << 8) + data[7]) / 10.0;
            muscle = ((data[8] << 8) + data[9]) / 10.0;
            bone = ((data[10] << 8) + data[11]) / 10.0;
            visceral = ((data[12] << 8) + data[13]) / 10.0;
            bmr = ((data[14] << 8) + data[15]).toDouble();
            
            // Calcular BMI (necesitarías la altura del usuario)
            // bmi = weight / (height * height);
          } catch (e) {
            print("Error parsing data: $e");
          }
        }
      });
    }
  }

  void disconnect() async {
    try {
      if (connectedDevice != null) {
        await connectedDevice!.disconnect();
      }
    } catch (e) {
      setState(() {
        connectionStatus = "Error al desconectar: ${e.toString()}";
      });
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báscula Smart Scale'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Estado de conexión
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isConnected ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Botones de acción
            if (!isConnected) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isScanning ? null : startScan,
                        icon: isScanning 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                        label: Text(isScanning ? 'Buscando...' : 'Buscar Báscula'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de dispositivos
              if (devicesList.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Dispositivos encontrados:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: devicesList.length,
                    itemBuilder: (context, index) {
                      BluetoothDevice device = devicesList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.monitor_weight, color: Colors.blue),
                          title: Text(device.platformName.isNotEmpty ? device.platformName : 'Dispositivo desconocido'),
                          subtitle: Text(device.remoteId.toString()),
                          trailing: ElevatedButton(
                            onPressed: () => connectToDevice(device),
                            child: const Text('Conectar'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else ...[
              // Datos de la báscula cuando está conectada
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Peso principal
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.monitor_weight,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Peso Corporal',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Otras métricas
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildMetricCard('Grasa Corporal', '${bodyFat.toStringAsFixed(1)}%', Colors.orange, Icons.opacity),
                          _buildMetricCard('Agua', '${water.toStringAsFixed(1)}%', Colors.blue, Icons.water_drop),
                          _buildMetricCard('Músculo', '${muscle.toStringAsFixed(1)}%', Colors.green, Icons.fitness_center),
                          _buildMetricCard('Hueso', '${bone.toStringAsFixed(1)}%', Colors.grey, Icons.accessibility),
                          _buildMetricCard('Grasa Visceral', '${visceral.toStringAsFixed(0)}', Colors.red, Icons.favorite),
                          _buildMetricCard('TMB', '${bmr.toStringAsFixed(0)} kcal', Colors.purple, Icons.local_fire_department),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Botón desconectar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: disconnect,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Desconectar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

*/

/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
//import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

String ipBalanza = "B4:56:5D:7D:70:F2";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Báscula Bluetooth',
      home: ScalePage(),
    );
  }
}

class ScalePage extends StatefulWidget {
  @override
  _ScalePageState createState() => _ScalePageState();
}

class _ScalePageState extends State<ScalePage> {

  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  String weightText = "Esperando datos...";
  double? lastWeight;
  Timer? stableTimer;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();    
    //startScan();
  }

  void startScan() async {
    if (isScanning) return;
    isScanning = true;
    weightText = "Escaneando dispositivos...";
    //flutterBlue.startScan(timeout: Duration(seconds: 5));

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 5),
      androidScanMode: AndroidScanMode.lowLatency
    );

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        if(r.device.remoteId.str == ipBalanza){
          
          await FlutterBluePlus.stopScan();

          await r.device.connect(
            mtu: 2085,
            autoConnect: false, 
            timeout: Duration(seconds: 50)
          );
      
        }
      }
    });

  }

  Future<void> connectToDevice() async {
    if (connectedDevice == null) return;

    connectedDevice!.state.listen((state) {
      if (state == BluetoothDeviceState.disconnected) {
        print("Báscula desconectada, reconectando...");
        weightText = "Desconectado, reconectando...";
        reconnect();
      }
    });

    try {
      await connectedDevice!.connect(autoConnect: false);
    } catch (e) {
      print("Error al conectar: $e");
    }

    services = await connectedDevice!.discoverServices();
    listenToWeight();
  }

  void reconnect() async {
    await Future.delayed(Duration(seconds: 2));
    try {
      await connectedDevice?.connect(autoConnect: false);
    } catch (_) {}
  }

  void listenToWeight() async {
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        if (c.properties.notify) {
          await c.setNotifyValue(true);
          c.value.listen((value) {
            if (value.isNotEmpty) {
              double weightKg = parseWeight(value);
              checkStableWeight(weightKg);
            }
          });
        }
      }
    }
  }

  double parseWeight(List<int> value) {
    if (value.length >= 2) {
      int raw = (value[1] << 8) | value[0];
      return raw / 200; // Ajustar según resolución de la báscula
    }
    return 0.0;
  }

  void checkStableWeight(double currentWeight) {
    if (lastWeight != null && (currentWeight - lastWeight!).abs() < 0.05) {
      stableTimer?.cancel();
      stableTimer = Timer(Duration(seconds: 2), () {
        setState(() {
          weightText = "${currentWeight.toStringAsFixed(2)} kg";
        });
      });
    } else {
      lastWeight = currentWeight;
      stableTimer?.cancel();
    }
  }

  void resetScale() {
    connectedDevice?.disconnect();
    lastWeight = null;
    weightText = "Reiniciando báscula...";
    startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Báscula Bluetooth")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weightText,
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: startScan,
              child: Text("Iniciar Báscula"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    stableTimer?.cancel();
    super.dispose();
  }
}
*/

/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String ipBalanza = "B4:56:5D:7D:70:F2";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanzaHomePage(),
    );
  }
}

class BalanzaHomePage extends StatefulWidget {
  const BalanzaHomePage({Key? key}) : super(key: key);

  @override
  State<BalanzaHomePage> createState() => _BalanzaHomePageState();
}

class _BalanzaHomePageState extends State<BalanzaHomePage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];
  String status = 'Desconectado';
  String peso = '0.00';
  BluetoothDevice? balanzaDevice;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    // Comprobar el estado del Bluetooth
    var isAvailable = await FlutterBluePlus.isAvailable;//flutterBlue.isAvailable;
    if (!isAvailable) {
      setState(() {
        status = 'Bluetooth no está disponible';
      });
      return;
    }
    
    // Si el escaneo ya está en progreso, lo detenemos primero
    if (FlutterBluePlus.isScanningNow) {
       FlutterBluePlus.stopScan();
    }

    setState(() {
      status = 'Escaneando...';
      scanResults.clear();
    });

    // Escanear por dispositivos Bluetooth
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!scanResults.any((sr) => sr.device.id == r.device.id)) {
          // Filtrar por nombre si es posible, o por un UUID de servicio conocido
          // Ejemplo: si tu balanza se llama 'MyScale'
          // if (r.device.name == 'MyScale') {
          if(r.device.remoteId.str == ipBalanza){
            _connectToDevice(r.device);
          }
          setState(() {
            scanResults.add(r);
          });
        }
      }
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      status = 'Conectando a ${device.name}...';
    });

    try {

      //var tst = _device.services;// .requestMtu();
      
      await FlutterBluePlus.stopScan();

      await device.connect();

      status = 'Conectado a ${device.name}';      

      setState(() {
        balanzaDevice = device;
      });

      _discoverServices(device);
    } catch (e) {
      setState(() {
        status = 'Error de conexión: $e';
      });
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    // Debes encontrar el servicio y la característica correctos para tu balanza
    // Esto es muy específico del dispositivo. A menudo el UUID del servicio es 
    // algo como '0000181d-0000-1000-8000-00805f9b34fb' (Perfil de peso y salud)
    for (var service in services) {
      // Ejemplo: buscar el servicio de peso (Weight Measurement Service)
      // Reemplaza 'SERVICE_UUID_DE_TU_BALANZA' con el UUID real
      // if (service.uuid.toString().toUpperCase().startsWith('0000181D')) {
      for (var characteristic in service.characteristics) {
        // Ejemplo: buscar la característica de peso (Weight Measurement Characteristic)
        // Reemplaza 'CHARACTERISTIC_UUID_DE_TU_BALANZA' con el UUID real
        // if (characteristic.uuid.toString().toUpperCase().startsWith('00002A9D')) {
        
        // Asumimos que la característica es 'notificable' para recibir actualizaciones
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          
          characteristic.value.listen((value) {
            // Aquí se procesan los bytes recibidos.
            // Esto es crucial y depende del protocolo de la balanza.
            // Por ejemplo, el peso podría estar en los bytes 1 y 2.
            if (value.isNotEmpty) {
               // Ejemplo de procesamiento (puede ser diferente para tu balanza)
               // Los primeros bytes suelen contener metadatos
               // El peso en gramos podría estar en los bytes 1 y 2
               // var gramos = (value[1] << 8) | value[2];
               // var kg = gramos / 1000.0;
               // setState(() {
               //   peso = kg.toStringAsFixed(2);
               // });

               // Para este ejemplo simple, solo mostramos los bytes sin procesar
               setState(() {
                 peso = 'Datos recibidos: ${value.toString()}';
               });
            }
          });
          
          setState(() {
            status = 'Suscrito a notificaciones de peso';
          });
          return; // Salimos de los bucles una vez que encontramos la característica
        }
      }
      // }
    }

    setState(() {
      status = 'No se encontró el servicio/característica de peso';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanza Bluetooth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startScan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Estado: $status',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Peso Actual:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                peso,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              const Text(
                'Dispositivos encontrados:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...scanResults.map((r) {
                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: r.device.remoteId.str == ipBalanza ?
                    Text('Balanza')
                    :
                    Text(r.device.name.isNotEmpty ? r.device.name : 'Dispositivo desconocido'),
                    subtitle: Text(r.device.id.toString()),
                    trailing: const Icon(Icons.bluetooth),
                    onTap: () => _connectToDevice(r.device),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
*/

//e35a448b-a5aa-4d21-b95b-54836ae7c69b
//String ipBalanza = "B4:56:5D:7D:70:F2";
/*
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanzaHomePage(),
    );
  }
}

class BalanzaHomePage extends StatefulWidget {
  const BalanzaHomePage({Key? key}) : super(key: key);

  @override
  State<BalanzaHomePage> createState() => _BalanzaHomePageState();
}

class _BalanzaHomePageState extends State<BalanzaHomePage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  String status = 'Esperando conexión...';
  String peso = '0.00 kg';
  BluetoothDevice? balanzaDevice;
  bool isScanning = false;

  // MAC address de la balanza
  final String deviceMacAddress = 'B4:56:5D:7D:70:F2';
  // UUIDs de servicio y característica. Si el código no funciona, estos son los que debes investigar con nRF Connect.
  final String serviceUuid = '0000181d-0000-1000-8000-00805f9b34fb';
  final String characteristicUuid = '00002a9d-0000-1000-8000-00805f9b34fb';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  void _checkPermissionsAndStartScan() async {
    var statusLocation = await Permission.location.request();
      var statusBluetoothScan = await Permission.bluetoothScan.request();
      var statusBluetoothConnect = await Permission.bluetoothConnect.request();
      var statusBluetoothAdvertise = await Permission.bluetoothAdvertise.request();

      if (statusLocation.isGranted &&
          statusBluetoothScan.isGranted &&
          statusBluetoothConnect.isGranted &&
          statusBluetoothAdvertise.isGranted) {
        _startScan();
      } else {
        setState(() {
          status = 'Permisos denegados. No se puede escanear.';
        });
      }
  }

  void _startScan() async {
    if (isScanning) {
      return;
    }
    
    // Si la balanza ya está conectada, no escanees
    if (balanzaDevice != null && await balanzaDevice!.state.first == BluetoothDeviceState.connected) {
      setState(() {
        status = 'Ya conectado a la balanza.';
      });
      return;
    }
    
    // Detener cualquier escaneo anterior
    if (await FlutterBluePlus.isScanning.first) {
      FlutterBluePlus.stopScan();
    }
    
    setState(() {
      status = 'Escaneando... Súbete a la balanza para activarla.';
      isScanning = true;
    });

    // Iniciar escaneo con un timeout largo o sin él para que sea continuo
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15),);

    // Escuchar los resultados del escaneo
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Encontrar la balanza por su MAC address
        if (r.device.id.toString().toUpperCase().replaceAll(':', '') == deviceMacAddress.toUpperCase().replaceAll(':', '')) {
          // Balanza encontrada, detener el escaneo y conectar
          FlutterBluePlus.stopScan();
          //setState(() {
            isScanning = false;
          //})
          _connectToDevice(r.device);
          return;
        }
      }
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      status = 'Balanza encontrada, conectando...';
      balanzaDevice = device;
    });

    try {
      
      await Future.delayed(Duration(seconds: 2));

      //await device.connect(autoConnect: true, mtu: null);
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      //await device.requestMtu(512);
      //await device.connectionState.where((val) => val == BluetoothConnectionState.connected).first;

      setState(() {
        status = 'Conectado a la balanza';
      });
      _discoverServices(device);
    } catch (e) {
      //setState(() {
        status = 'Error de conexión: $e. Súbete de nuevo para reintentar.';
      //});
      // El error 133 probablemente ocurrirá aquí. Reintentar.
      balanzaDevice?.disconnect();
      _startScan(); // Reintentar el escaneo
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    //await device.connect(autoConnect: true, mtu: null);
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      //if (service.uuid.toString().toLowerCase() == serviceUuid) {
        for (var characteristic in service.characteristics) {
          //if (characteristic.uuid.toString().toLowerCase() == characteristicUuid) {
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              
              characteristic.value.listen((value) {
                // ... (lógica de procesamiento de bytes, la misma que antes)
                if (value.length >= 2) {
                   final int weightValue = (value[2] << 8) | value[1];
                   final double weightKg = weightValue / 200.0;
                   setState(() {
                     peso = '${weightKg.toStringAsFixed(2)} kg';
                   });
                 }
              });
              
              setState(() {
                status = 'Suscrito a notificaciones de peso. Peso actualizado.';
              });
              return;
            } else {
               setState(() {
                 status = 'La característica de peso no soporta notificaciones.';
               });
            }
          //}
        }
      //}
    }

    setState(() {
      status = 'No se encontró el servicio/característica de peso.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanza Bluetooth'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Estado: $status',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'Peso Actual:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                peso,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Comenzar Escaneo y Conexión'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  FlutterBluePlus.stopScan();
                  if (balanzaDevice != null) {
                    balanzaDevice!.disconnect();
                    setState(() {
                      balanzaDevice = null;
                      status = 'Desconectado';
                      peso = '0.00 kg';
                    });
                  }
                },
                child: const Text('Desconectar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/

/*
// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

//
// This widget shows BluetoothOffScreen or
// ScanScreen depending on the adapter state
//
class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({Key? key}) : super(key: key);

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = Container(color: Colors.yellow,);
    return MaterialApp(
      color: Colors.lightBlue,
      home: screen,
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

//
// This observer listens for Bluetooth Off and dismisses the DeviceScreen
//
class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      // Start listening to Bluetooth state changes when a new route is pushed
      _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          // Pop the current route if Bluetooth is off
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the subscription when the route is popped
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}

*/

/*
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanzaHomePage(),
    );
  }
}

class BalanzaHomePage extends StatefulWidget {
  const BalanzaHomePage({Key? key}) : super(key: key);

  @override
  State<BalanzaHomePage> createState() => _BalanzaHomePageState();
}

class _BalanzaHomePageState extends State<BalanzaHomePage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus();
  String status = 'Esperando conexión...';
  String peso = '0.00 kg';
  BluetoothDevice? balanzaDevice;
  bool isScanning = false;
  late StreamSubscription<BluetoothConnectionState> connectionStateSubscription;

  final String deviceMacAddress = 'B4:56:5D:7D:70:F2';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  @override
  void dispose() {
    connectionStateSubscription.cancel();
    FlutterBluePlus.stopScan();
    balanzaDevice?.disconnect();
    super.dispose();
  }

  void _checkPermissionsAndStartScan() async {
    // ... (El código de permisos es el mismo)
      var statusLocation = await Permission.location.request();
      var statusBluetoothScan = await Permission.bluetoothScan.request();
      var statusBluetoothConnect = await Permission.bluetoothConnect.request();
      if (statusLocation.isGranted && statusBluetoothScan.isGranted && statusBluetoothConnect.isGranted) {
        _startScan();
      } else {
        setState(() { status = 'Permisos denegados. No se puede escanear.'; });
      }
    
  }

  void _startScan() async {
    if (isScanning) return;
    if (await FlutterBluePlus.isScanning.first) FlutterBluePlus.stopScan();
    
    setState(() {
      status = 'Escaneando... Súbete a la balanza.';
      isScanning = true;
    });

    FlutterBluePlus.startScan();

    var scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.id.toString().toUpperCase().replaceAll(':', '') == deviceMacAddress.toUpperCase().replaceAll(':', '')) {
          _connectToDevice(r.device);
          // Detener el escaneo inmediatamente y cancelar la suscripción
          FlutterBluePlus.stopScan();
          isScanning = false;
          return;
        }
      }
    });

    // Asegurarse de cancelar la suscripción si no se encuentra la balanza
    Future.delayed(const Duration(seconds: 20), () {
      if (isScanning) {
        scanSubscription.cancel();
        FlutterBluePlus.stopScan();
        setState(() {
          status = 'Escaneo finalizado. No se encontró la balanza.';
          isScanning = false;
        });
      }
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      status = 'Balanza encontrada, conectando...';
      balanzaDevice = device;
    });

    try {
      // Intenta conectar y manejar la desconexión
      await device.connect();

      // Suscribirse a los cambios de estado de la conexión
      connectionStateSubscription = balanzaDevice!.state.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          setState(() { status = 'Conectado a la balanza.'; });
          _discoverServices(device);
        } else if (state == BluetoothConnectionState.disconnected) {
          setState(() { status = 'Balanza desconectada. Reintentando...'; });
          // La balanza se desconectó. Dejar que Android la reconecte
          // La conexión se mantendrá en segundo plano y se reconectará cuando la balanza se active de nuevo.
          _startScan();
        }
      });

    } catch (e) {
      setState(() {
        status = 'Error de conexión: $e. Súbete de nuevo para reintentar.';
      });
      balanzaDevice?.disconnect();
      _startScan();
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    for (var service in services) {
      //if (service.uuid.toString().toLowerCase() == serviceUuid) {
        for (var characteristic in service.characteristics) {
          //if (characteristic.uuid.toString().toLowerCase() == characteristicUuid) {
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                if (value.length >= 2) {
                   final int weightValue = (value[2] << 8) | value[1];
                   final double weightKg = weightValue / 200.0;
                   setState(() { peso = '${weightKg.toStringAsFixed(2)} kg'; });
                 }
              });
              setState(() { status = 'Suscrito a notificaciones de peso. Peso actualizado.'; });
              return;
            }
          //}
        }
      //}
    }
    setState(() { status = 'No se encontró el servicio/característica.'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balanza Bluetooth')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Estado: $status', style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              const Text('Peso Actual:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(peso, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: _startScan, child: const Text('Buscar Balanza')),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  FlutterBluePlus.stopScan();
                  balanzaDevice?.disconnect();
                  connectionStateSubscription.cancel();
                  setState(() {
                    balanzaDevice = null;
                    status = 'Desconectado';
                    peso = '0.00 kg';
                  });
                },
                child: const Text('Desconectar')
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/

/*
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanzaHomePage(),
    );
  }
}

class BalanzaHomePage extends StatefulWidget {
  const BalanzaHomePage({Key? key}) : super(key: key);

  @override
  State<BalanzaHomePage> createState() => _BalanzaHomePageState();
}

class _BalanzaHomePageState extends State<BalanzaHomePage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  String status = 'Esperando peso...';
  String peso = '0.00 kg';
  bool isScanning = false;

  // MAC address de la balanza
  final String deviceMacAddress = 'B4:56:5D:7D:70:F2';
  
  // ID del fabricante (del nRF Connect log)
  final int manufacturerId = 47808;//0x0125;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _checkPermissionsAndStartScan() async {
      var statusLocation = await Permission.location.request();
      var statusBluetoothScan = await Permission.bluetoothScan.request();
      var statusBluetoothConnect = await Permission.bluetoothConnect.request();
      if (statusLocation.isGranted && statusBluetoothScan.isGranted && statusBluetoothConnect.isGranted) {
        _startScan();
      } else {
        setState(() { status = 'Permisos denegados. No se puede escanear.'; });
      }
    
  }

  void _startScan() async {
    if (isScanning) return;
    
    FlutterBluePlus.stopScan(); // Asegurarse de detener cualquier escaneo anterior
    
    setState(() {
      status = 'Escaneando... Súbete a la balanza.';
      isScanning = true;
    });

    FlutterBluePlus.startScan();

    // El stream emite una lista de resultados de escaneo
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        
        // Dentro de _startScan() y el bucle de scanResults.listen
        if (result.device.id.toString().toUpperCase().replaceAll(':', '') == deviceMacAddress.toUpperCase().replaceAll(':', '') &&
            result.advertisementData.manufacturerData.isNotEmpty) {
          
          print('Claves de manufacturerData: ${result.advertisementData.manufacturerData.keys}');

          var key = result.advertisementData.manufacturerData.keys;

          final manufacturerData = result.advertisementData.manufacturerData;          

          final rawData = manufacturerData[key.first];

          if (rawData != null && rawData.isNotEmpty) {
            // ---- NUEVO: Imprime todos los bytes para depuración ----
            print('Datos recibidos: ${rawData.toString()}');
            // ---- FIN NUEVO ----
            
            // Aquí, con base en lo que viste en la impresión, ajusta el offset y el factor
            try {
                final ByteData byteData = ByteData.sublistView(Uint8List.fromList(rawData));
                
                // --- Intenta las siguientes opciones una por una ---
                // Opción 1: El peso está en los bytes 2 y 3
                // final int weightRaw = byteData.getInt16(1, Endian.little);
                
                // Opción 2: El peso está en los bytes 3 y 4
                // final int weightRaw = byteData.getInt16(2, Endian.little);

                // Opción 3: El peso está en los bytes 5 y 6
                final int weightRaw = byteData.getInt16(4, Endian.little);

                // El factor de conversión (10, 100 o 1000) también puede ser diferente
                final double weightKg = weightRaw / 100.0;
                
                setState(() {
                  peso = '${weightKg.toStringAsFixed(2)} kg';
                  status = 'Peso recibido. Escaneando de nuevo...';
                });

            } catch (e) {
                print('Error al procesar los bytes: $e');
                setState(() {
                  status = 'Error al procesar el peso. Súbete de nuevo.';
                });
            }
          }
        }
        // ... (resto del código es el mismo)
      }
    });

    FlutterBluePlus.isScanning.listen((isScanningNow) {
      if (!isScanningNow) {
        setState(() {
          status = 'Escaneo detenido.';
          isScanning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanza Bluetooth'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Estado: $status',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'Peso Actual:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                peso,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Comenzar Escaneo'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  FlutterBluePlus.stopScan();
                  setState(() {
                    status = 'Escaneo detenido manualmente.';
                    isScanning = false;
                    peso = '0.00 kg';
                  });
                },
                child: const Text('Detener Escaneo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balanza App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BalanzaHomePage(),
    );
  }
}

class BalanzaHomePage extends StatefulWidget {
  const BalanzaHomePage({Key? key}) : super(key: key);

  @override
  State<BalanzaHomePage> createState() => _BalanzaHomePageState();
}

class _BalanzaHomePageState extends State<BalanzaHomePage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  String status = 'Esperando peso...';
  String peso = '0.00 kg';
  bool isScanning = false;

  final String deviceMacAddress = 'B4:56:5D:7D:70:F2';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _checkPermissionsAndStartScan() async {
    //if (Theme.of(context).platform == TargetPlatform.android) {
      var statusLocation = await Permission.location.request();
      var statusBluetoothScan = await Permission.bluetoothScan.request();
      var statusBluetoothConnect = await Permission.bluetoothConnect.request();
      if (statusLocation.isGranted && statusBluetoothScan.isGranted && statusBluetoothConnect.isGranted) {
        _startScan();
      } else {
        setState(() { status = 'Permisos denegados. No se puede escanear.'; });
      }    
  }

  void _startScan() async {
    if (isScanning) return;
    
    FlutterBluePlus.stopScan();
    
    setState(() {
      status = 'Escaneando... Súbete a la balanza.';
      isScanning = true;
    });

    FlutterBluePlus.startScan();

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.id.toString().toUpperCase().replaceAll(':', '') == deviceMacAddress.toUpperCase().replaceAll(':', '')) {
          
          final manufacturerDataMap = result.advertisementData.manufacturerData;

          if (manufacturerDataMap.isNotEmpty) {
            for (var entry in manufacturerDataMap.entries) {
              final int key = entry.key;
              final List<int> rawData = entry.value;

              // ... (El resto del código es el mismo hasta el bloque de try/catch)
              if (rawData.length >= 13) {
                
                print('Posible paquete de peso encontrado. Clave: $key. Datos: $rawData');

                try {
                    final ByteData byteData = ByteData.sublistView(Uint8List.fromList(rawData));
                    
                    // --- CAMBIO CLAVE: Leer desde el índice 0 en formato Big-Endian ---
                    final int weightRaw = byteData.getInt16(0, Endian.big);
                    
                    // El factor de conversión es 100 para centésimas de Kg
                    final double weightKg = weightRaw / 100.0;
                    
                    // Solo actualiza el peso si el valor es razonable
                    if (weightKg > 0 && weightKg < 200) { 
                        setState(() {
                          peso = '${weightKg.toStringAsFixed(2)} kg';
                          status = 'Peso recibido.';
                        });
                    }
                    
                } catch (e) {
                    print('Error al procesar los bytes: $e');
                    setState(() {
                      status = 'Error al procesar el peso. Súbete de nuevo.';
                    });
                }
              }
    // ... (El resto del código es el mismo)

            }
          }
        }
      }
    });

    FlutterBluePlus.isScanning.listen((isScanningNow) {
      if (!isScanningNow) {
        setState(() {
          status = 'Escaneo detenido.';
          isScanning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balanza Bluetooth'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Estado: $status',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'Peso Actual:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                peso,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Comenzar Escaneo'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  FlutterBluePlus.stopScan();
                  setState(() {
                    status = 'Escaneo detenido manualmente.';
                    isScanning = false;
                    peso = '0.00 kg';
                  });
                },
                child: const Text('Detener Escaneo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
