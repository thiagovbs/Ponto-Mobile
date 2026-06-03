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

  // 🟢 COMPONENTES DE GRÁFICO REATIVO: Mapeamento de dados estruturados vindo do backend
  List<String> _graficoLabels = [];
  List<int> _graficoDados = [];
  int _maiorValorGrafico = 0;

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

          // 🟢 ADAPTAÇÃO INTEGRADA: Resgata a estrutura do gráfico semanal enviado pela API
          if (response.data['graficoSemanal'] != null) {
            final graficoJson = response.data['graficoSemanal'];
            _graficoLabels = List<String>.from(graficoJson['labels'] ?? []);
            
            final dadosBrutos = graficoJson['dados'] ?? [];
            _graficoDados = List<int>.from(dadosBrutos.map((d) => int.tryParse(d.toString()) ?? 0));
            
            // Calcula o maior valor do topo para criar a proporção de altura ideal das barras
            _maiorValorGrafico = _graficoDados.isEmpty ? 0 : _graficoDados.reduce((curr, next) => curr > next ? curr : next);
          }

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

              // 🟢 GRÁFICO SEMANAL NATIVO: Alinhado em perfeita conformidade técnica com o Chart.js da Web
              if (_graficoLabels.isNotEmpty) ...[
                const Text(
                  '📊 Frequência Semanal (Total de Batidas)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(_graficoDados.length, (index) {
                            final dado = _graficoDados[index];
                            final label = _graficoLabels[index];
                            
                            // Calcula a altura percentual proporcional baseando-se no maior elemento
                            double percentualAltura = _maiorValorGrafico == 0 ? 0.0 : (dado / _maiorValorGrafico);
                            // Limita um tamanho mínimo para visualização sutil em colunas vazias
                            double alturaFinalCalculada = (150 * percentualAltura).clamp(6.0, 150.0);

                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    dado.toString(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Tooltip(
                                    message: '$dado batidas',
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      height: alturaFinalCalculada,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6), // Azul padrão idêntico ao Chart.js web
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

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
                                child: () {
                                  if (fotoRaw == null || fotoRaw.trim().isEmpty) {
                                    return const Icon(Icons.person, color: Color(0xFF1E3A8A));
                                  }

                                  try {

                                    String textoCru = fotoRaw.trim();  

                                    // 1. 🛡️ EXTRAÇÃO VIA REGEXP (Ignora qualquer tipo de cabeçalho "data:image...")
                                    // Procura pelo início real de um bloco Base64 válido.
                                    // Se houver uma vírgula ou ponto e vírgula, captura tudo o que vem DEPOIS.
                                    if (textoCru.startsWith('data:')) {
                                      final RegExp regexCabecalho = RegExp(r'data:image\/[a-zA-Z]+;base64,|data:image\/[a-zA-Z]+;');
                                      textoCru = textoCru.replaceAll(regexCabecalho, '');
                                    }

                                    // 2. Remove qualquer resquício de sujeira, espaços, quebras de linha ou "=" perdidos no início
                                    String base64Limpo = textoCru
                                        .replaceAll('\n', '')
                                        .replaceAll('\r', '')
                                        .replaceAll(' ', '')
                                        .replaceAll(RegExp(r'^=+'), ''); // Remove símbolos de "=" se estiverem no COMEÇO da string

                                    // 3. Garante o preenchimento (padding) correto apenas no FINAL da string pura
                                    int mod = base64Limpo.length % 4;
                                    if (mod > 0) {
                                      base64Limpo += '=' * (4 - mod);
                                    }

                                    // 4. Executa a decodificação dos bytes purificados
                                    final bytesImagem = base64Decode(base64Limpo);

                                    if (bytesImagem.isEmpty) {
                                      return const Icon(Icons.person, color: Color(0xFF1E3A8A));
                                    }

                                    return Image.memory(
                                      base64Decode(base64Limpo),
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => 
                                          const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                                    );
                                  } catch (e) {
                                    // Se mesmo limpando der erro de parse, evita o crash da tela e põe um fallback amigável
                                    debugPrint("Erro ao decodificar Base64 da foto: $e");
                                    return const Icon(Icons.person, color: Color(0xFF1E3A8A));
                                  }
                                }(), // Executa a função anônima imediatamente
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