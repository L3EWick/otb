import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/url.dart';

class FormPage extends StatefulWidget {
  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _quantity;
  double? _latitude;
  double? _longitude;
  String? _uniqueId;
  String? _name;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _getUserDetails();
    _getLocation();
  }

  void _initializeHive() async {
    await Hive.initFlutter();
    await Hive.openBox('offline_data');
    print("Hive inicializado e caixa 'offline_data' aberta.");
  }

  Future<void> _getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _uniqueId = prefs.getString('uniqueId');
      _name = prefs.getString('name');
    });
    print("User Details - uniqueId: $_uniqueId, name: $_name");
  }

  Future<void> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      print("Permissão de localização: $permission");
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        print(
            'Localização obtida - Latitude: $_latitude, Longitude: $_longitude');
      } catch (e) {
        print('Erro ao obter localização: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter localização: $e')),
        );
      }
    } else {
      print('Permissão de localização negada');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permissão de localização negada')),
      );
    }
  }

  Future<bool> _checkApiConnection() async {
    final url = apiStatusEndpoint;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['online'] == true) {
          print('API está online');
          return true;
        }
      }
    } catch (error) {
      print('Erro ao verificar a conexão com a API: $error');
    }
    return false;
  }

  Future<void> _sendData() async {
    if (_quantity != null && _latitude != null && _longitude != null) {
      setState(() {
        _isLoading = true;
      });

      // Verifique se uniqueId e name estão presentes
      if (_uniqueId == null || _name == null) {
        print("Erro: uniqueId ou name estão nulos.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: Informações do usuário ausentes.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final body = json.encode({
        'quantity': _quantity,
        'latitude': _latitude.toString(),
        'longitude': _longitude.toString(),
        'uniqueId': _uniqueId,
        'name': _name,
      });

      print("Body enviado para a API: $body");

      try {
        final isApiOnline = await _checkApiConnection();

        if (isApiOnline) {
          final url = apiSync;
          print("Conectividade com a API verificada, enviando dados...");
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          );

          print('Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');

          if (response.statusCode >= 200 && response.statusCode < 300) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cadastro enviado com sucesso!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao enviar dados: ${response.body}')),
            );
            await _saveDataOffline(body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dados salvos offline devido ao erro.')),
            );
          }
        } else {
          print("API offline. Salvando dados offline.");
          await _saveDataOffline(body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sem conexão, cadastro salvo offline.')),
          );
        }
      } catch (error) {
        print('Erro durante a tentativa de enviar os dados: $error');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao tentar enviar: $error')),
        );
        await _saveDataOffline(body);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      print("Erro: Dados obrigatórios estão faltando.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: Dados obrigatórios estão faltando.')),
      );
    }
  }

  Future<void> _saveDataOffline(String data) async {
    final box = Hive.box('offline_data');

    final decodedData = json.decode(data);
    final existingData = box.values.map((entry) => json.decode(entry)).toList();

    if (existingData.any((entry) =>
        entry['quantity'] == decodedData['quantity'] &&
        entry['latitude'] == decodedData['latitude'] &&
        entry['longitude'] == decodedData['longitude'] &&
        entry['uniqueId'] == decodedData['uniqueId'])) {
      print("Cadastro já salvo offline!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cadastro já salvo offline!')),
      );
      return;
    }

    // Adiciona timestamp ao dado
    final timestamp = DateTime.now().toIso8601String();
    final dataWithTimestamp =
        json.encode({'data': decodedData, 'timestamp': timestamp});

    await box.add(dataWithTimestamp);
    print("Dados salvos offline: $dataWithTimestamp");
  }

  void _printOfflineData() async {
    final box = Hive.box('offline_data');
    for (var i = 0; i < box.length; i++) {
      print('Dados Offline [$i]: ${box.getAt(i)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(21, 22, 23, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(21, 22, 23, 1),
        title: Text('Cadastro', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      keyboardType: TextInputType.numberWithOptions(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira uma quantidade';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _quantity = value;
                      },
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color.fromRGBO(50, 50, 50, 1),
                        labelText: 'Quantidade',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          _sendData();
                        }
                      },
                      child: Text('Salvar Cadastro',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
