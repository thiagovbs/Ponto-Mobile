import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _carregando = false;
  
  int _totalFuncionarios = 0;
  int _batidasHoje = 0;
  List<dynamic> _feedAtividades = [];

  // 🪛 Nova variável calculada localmente
  int _presentesNoPredio = 0;

  @override
  void initState() {
    super.initState();
    _buscarDadosDashboard();
  }

  Future<void> _buscarDadosDashboard() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final response = await ApiService.dio.get('/relatorios/dashboard');
      
      if (mounted) {
        setState(() {
          _totalFuncionarios = response.data['totalFuncionarios'] ?? 0;
          _batidasHoje = response.data['batidasHoje'] ?? 0;
          _feedAtividades = response.data['feedAtividades'] ?? [];

          // 🎯 CÁLCULO DINÂMICO DE PRESENÇA:
          // Extrai os nomes únicos do feed de atividades do dia para saber
          // quantos funcionários únicos registraram ponto e estão no prédio.
          final nomesUnicos = _feedAtividades
              .map((item) => item['nome']?.toString().trim().toLowerCase())
              .where((nome) => nome != null)
              .toSet(); // O Set elimina duplicatas automaticamente
          
          _presentesNoPredio = nomesUnicos.length;
        });
      }
    } catch (e) {
      String mensagemErro = "Não foi possível carregar os dados do Dashboard.";
      String detalheTecnico = e.toString();

      if (e is DioException) {
        final dioError = e;
        mensagemErro = "A API do Render recusou a sincronização dos relatórios.";
        detalheTecnico = "Tipo: ${dioError.type}\n"
                         "Status Code: ${dioError.response?.statusCode}\n"
                         "Resposta do Servidor: ${dioError.response?.data}";
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.red),
              SizedBox(width: 8),
              Text('Erro de Indicadores', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensagemErro, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Detalhes capturados:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  detalheTecnico,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.redAccent),
                ),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

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
              // 📊 GRID REORGANIZADO PARA 3 CARDS INDICADORES
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.5 : 3.5,
                children: [
                  _buildCardIndicador(
                    titulo: 'Presentes no Prédio', // 🔥 O Card desejado recuperado e funcional!
                    valor: _presentesNoPredio.toString(),
                    icone: Icons.gpp_good,
                    cor: Colors.green,
                  ),
                  _buildCardIndicador(
                    titulo: 'Registros de Hoje',
                    valor: _batidasHoje.toString(),
                    icone: Icons.access_time_filled,
                    cor: Colors.amber.shade900,
                  ),
                  _buildCardIndicador(
                    titulo: 'Total Colaboradores',
                    valor: _totalFuncionarios.toString(),
                    icone: Icons.people,
                    cor: const Color(0xFF1E3A8A),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                '⏱️ Atividades Recentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _feedAtividades.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('Nenhuma atividade registrada recentemente.')),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _feedAtividades.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _feedAtividades[index];
                          final nome = item['nome'] ?? 'Funcionário';
                          final hora = item['hora'] ?? '--:--';
                          
                          // Captura a imagem em Base64
                          final String? fotoRaw = item['foto'] ?? item['fotoBase64'];

                          // Captura e trata as coordenadas geográficas de forma segura
                          final double? latitude = item['latitude'] != null ? double.tryParse(item['latitude'].toString()) : null;
                          final double? longitude = item['longitude'] != null ? double.tryParse(item['longitude'].toString()) : null;

                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                width: 42,
                                height: 42,
                                color: const Color(0xFFF1F5F9),
                                child: (fotoRaw != null && fotoRaw.contains('base64,'))
                                    ? Image.memory(
                                        base64Decode(fotoRaw.split('base64,')[1]),
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                                      )
                                    : const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Marcação de Ponto Realizada'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔥 ÍCONE DO MAPA (Só aparece se a API enviar latitude e longitude válidas)
                                if (latitude != null && longitude != null) ...[
                                  IconButton(
                                    icon: const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
                                    tooltip: 'Visualizar no Mapa',
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Abrindo localização de $nome no mapa...'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      // Se você usa o url_launcher, pode descomentar a linha abaixo:
                                      launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'), mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                // HORÁRIO DA BATIDA
                                Text(
                                  hora,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16, 
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
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