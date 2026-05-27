import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _carregando = false;
  Map<String, dynamic> _dadosDashboard = {
    'presentes': 0,
    'ausentes': 0,
    'atrasos': 0,
    'totalFuncionarios': 0,
    'ultimasBatidas': []
  };

  @override
  void initState() {
    super.initState();
    _buscarDadosDashboard();
  }

  Future<void> _buscarDadosDashboard() async {
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/relatorios/dashboard');
      setState(() {
        _dadosDashboard = {
          'presentes': response.data['presentes'] ?? 0,
          'ausentes': response.data['ausentes'] ?? 0,
          'atrasos': response.data['atrasos'] ?? 0,
          'totalFuncionarios': response.data['totalFuncionarios'] ?? 0,
          'ultimasBatidas': response.data['ultimasBatidas'] ?? []
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar indicadores do dashboard.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final ultimasBatidas = _dadosDashboard['ultimasBatidas'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _buscarDadosDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📊 GRID DE CARDS INDICADORES (Ajustado para Telas de Tablet)
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildCardIndicador(
                    titulo: 'Presentes Agora',
                    valor: _dadosDashboard['presentes'].toString(),
                    icone: Icons.gpp_good,
                    cor: Colors.green,
                  ),
                  _buildCardIndicador(
                    titulo: 'Ausentes Hoje',
                    valor: _dadosDashboard['ausentes'].toString(),
                    icone: Icons.person_off,
                    cor: Colors.red,
                  ),
                  _buildCardIndicador(
                    titulo: 'Atrasos do Dia',
                    valor: _dadosDashboard['atrasos'].toString(),
                    icone: Icons.running_with_errors,
                    cor: Colors.amber.shade900,
                  ),
                  _buildCardIndicador(
                    titulo: 'Colaboradores',
                    valor: _dadosDashboard['totalFuncionarios'].toString(),
                    icone: Icons.people,
                    cor: const Color(0xFF1E3A8A),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ⏱️ SEÇÃO: ÚLTIMAS ATIVIDADES EM TEMPO REAL
              const Text(
                '⏱️ Últimas Batidas Registradas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ultimasBatidas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('Nenhuma batida registrada hoje até o momento.')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ultimasBatidas.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final batida = ultimasBatidas[index];
                          final nome = batida['usuario']?['nome'] ?? 'Funcionário';
                          final hora = batida['horaFormatada'] ?? batida['horario'] ?? '--:--';
                          final tipo = batida['tipo'] ?? 'Registro'; 

                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF1F5F9),
                              child: Icon(Icons.history, color: Color(0xFF64748B)),
                            ),
                            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Operação: $tipo'),
                            trailing: Text(
                              hora,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para gerar os Cards superiores
  Widget _buildCardIndicador({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14)),
                Icon(icone, color: cor, size: 28),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}