import 'package:flutter/material.dart';
import 'package:otb/screens/homePage.dart';
import '../helpers/url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String uniqueId = '';
  bool isLoading = false;
  String responseMessage = '';

  @override
  void initState() {
    super.initState();
    _getUniqueId();
  }

  Future<void> _getUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('uniqueId');

    if (storedId != null) {
      setState(() {
        uniqueId = storedId;
      });
      _loginWithUniqueId();
    } else {
      uniqueId = '';
    }
  }

  Future<void> _loginWithUniqueId() async {
    setState(() {
      isLoading = true;
    });

    String apiUrl = apiLogin;
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uniqueId': uniqueId.isEmpty ? '' : uniqueId}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newUniqueId = responseData['uniqueId'];
        final isRegistered = responseData['registered'];
        final name = responseData['nome'];

        if (newUniqueId != null && newUniqueId is String) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('uniqueId', newUniqueId);

          if (isRegistered == true) {
            await prefs.setString('name', name);
          }

          setState(() {
            uniqueId = newUniqueId;
            responseMessage = '${responseData['message']} Token: $uniqueId';
          });

          if (isRegistered == true) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomePage(),
              ),
            );
          } else {
            _showAlertDialog('Sucesso', responseMessage);
          }
        } else {
          _showAlertDialog('Erro', 'Contate a administração');
        }
      } else if (response.statusCode == 404) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];

        if (token != null && token is String) {
          _showNotRegisteredAlert(token);
        } else {
          _showAlertDialog(
              'Erro', '${responseData['message']} Token: $uniqueId');
        }
      } else {
        _showAlertDialog(
            'Erro', 'Erro: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (error) {
      _showAlertDialog('Erro', 'Erro na requisição: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(
            message,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showNotRegisteredAlert(String token) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Telefone não cadastrado'),
          content: Text(
            'Seu telefone não está cadastrado. Por favor, entre em contato com o administrador para registrar seu dispositivo.\n\nToken: $token',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(21, 22, 23, 1),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/img/onde.png',
                width: 250,
                height: 250,
              ),
              SizedBox(height: 200),
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _loginWithUniqueId,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Color.fromARGB(255, 0, 48, 37),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: Text(
                        'ENTRAR',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
