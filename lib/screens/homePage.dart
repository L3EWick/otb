import 'package:flutter/material.dart';
import 'formPage.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../helpers/url.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isLoading = false; // Variável para controlar o estado de carregamento

  // Adicione uma lista de páginas
  final List<Widget> _pages = [
    HomeScreen(),
    FormPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _checkForSyncData();
    }
  }

  Future<void> _checkForSyncData() async {
    final box = Hive.box('offline_data');

    if (box.isNotEmpty) {
      final isApiOnline = await _checkApiConnection();
      if (isApiOnline) {
        _showSyncDialog();
      }
    }
  }

  Future<bool> _checkApiConnection() async {
    try {
      final response = await http
          .get(Uri.parse(apiStatusEndpoint)); // URL de verificação de status
      return response.statusCode == 200;
    } catch (error) {
      print('Erro ao verificar conexão com a API: $error');
      return false;
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sincronização de Dados'),
          content: Text(
              'Há informações a serem sincronizadas. Deseja sincronizar agora?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context)
                    .pop(); // Fecha o diálogo antes de iniciar a sincronização
                await _syncData();
              },
              child: Text('Sim'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Não'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncData() async {
    final box = Hive.box('offline_data');
    final List<dynamic> offlineData =
        box.values.map((entry) => json.decode(entry)).toList();

    setState(() {
      _isLoading = true; // Inicia o carregamento
    });

    for (var data in offlineData) {
      // Enviar dados para a API
      final response = await http.post(
        Uri.parse(syncjsondecode),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data['data']),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await box.deleteAt(0);
      } else {
        print('Erro ao sincronizar dados: ${response.body}');
      }
    }

    setState(() {
      _isLoading = false; // Finaliza o carregamento
    });

    // Exibe um diálogo de sucesso
    _showSuccessDialog(offlineData.length);
    print('Dados restantes no Hive: ${box.values}');
  }

  void _showSuccessDialog(int syncedCount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sincronização Completa'),
          content:
              Text('$syncedCount cadastro(s) sincronizado(s) com sucesso!'),
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
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(21, 22, 23, 1),
        title: Text(
          'Onde tem Bandeirete',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _pages[_selectedIndex], // Mostra a página selecionada
          if (_isLoading) // Mostra a barra de carregamento
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Novo Cadastro',
          ),
          // Adicione mais itens se necessário
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Color.fromRGBO(21, 22, 23, 1),
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/img/onde.png',
              width: 250,
              height: 250,
            ),
          ],
        ),
      ),
    );
  }
}
