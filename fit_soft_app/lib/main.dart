
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
