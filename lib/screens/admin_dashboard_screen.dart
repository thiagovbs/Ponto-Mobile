import 'package:flutter/material.dart';
import 'tabs/horarios_tab.dart';    
import 'tabs/funcionarios_tab.dart';
import 'tabs/espelho_tab.dart';
import 'tabs/dashboard_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _abaAtiva = 0;

  final List<String> _titulos = [
    'Dashboard',
    'Configurar Horários',
    'Gerenciar Funcionários',
    'Espelho de Ponto'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_abaAtiva], style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sair do Painel',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1E3A8A)),
              accountName: Text('Administrador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text('Painel de Controle Geral'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _abaAtiva == 0,
              onTap: () { setState(() => _abaAtiva = 0); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Configurar Horários'),
              selected: _abaAtiva == 1,
              onTap: () { setState(() => _abaAtiva = 1); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Funcionários'),
              selected: _abaAtiva == 2,
              onTap: () { setState(() => _abaAtiva = 2); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Espelho de Ponto'),
              selected: _abaAtiva == 3,
              onTap: () { setState(() => _abaAtiva = 3); Navigator.pop(context); },
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _renderizarConteudo(_abaAtiva),
      ),
    );
  }

  // 🪛 CHAMA AS TELAS ISOLADAS DE FORMA LIMPA E ORGANIZADA
  Widget _renderizarConteudo(int index) {
    switch (index) {
      case 0:
        return const DashboardTab();
      case 1:
        return const HorariosTab(); 
      case 2:
        return const FuncionariosTab();
      case 3:
        return const EspelhoTab();
      default:
        return const HorariosTab();
    }
  }
}