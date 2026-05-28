import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EspelhoTab extends StatefulWidget {
  const EspelhoTab({super.key});

  @override
  State<EspelhoTab> createState() => _EspelhoTabState();
}

class _EspelhoTabState extends State<EspelhoTab> {
  List<dynamic> _funcionarios = [];
  String? _funcionarioSelecionadoId;
  DateTime _mesSelecionado = DateTime.now();
  
  List<dynamic> _linhasEspelho = [];
  Map<String, dynamic>? _resumoDashboard; // Para capturar saldo e faltas
  bool _carregandoFuncionarios = false;
  bool _carregandoEspelho = false;

  @override
  void initState() {
    super.initState();
    _buscarFuncionarios();
  }

  Future<void> _buscarFuncionarios() async {
    if (!mounted) return;
    setState(() => _carregandoFuncionarios = true);
    try {
      final response = await ApiService.dio.get('/usuarios');
      final List<dynamic> todosUsuarios = response.data;
      final funcionariosFiltrados = todosUsuarios.where((usr) => usr['perfil'] == 'FUNCIONARIO').toList();

      if (mounted) {
        setState(() {
          _funcionarios = funcionariosFiltrados;
          if (_funcionarios.isNotEmpty) {
            _funcionarioSelecionadoId = _funcionarios[0]['id'];
            _buscarDadosEspelho();
          }
        });
      }
    } catch (e) {
      _mostrarSnackbar('Erro ao carregar lista de funcionários.', esErro: true);
    } finally {
      if (mounted) setState(() => _carregandoFuncionarios = false);
    }
  }

  Future<void> _buscarDadosEspelho() async {
    if (_funcionarioSelecionadoId == null) return;

    if (!mounted) return;
    setState(() => _carregandoEspelho = true);
    try {
      // 🪛 Ajustado para enviar números inteiros puros (1 em vez de 01), como o Vue espera
      final int mesQuery = _mesSelecionado.month;
      final int anoQuery = _mesSelecionado.year;

      final response = await ApiService.dio.get(
        '/relatorios/funcionario/$_funcionarioSelecionadoId', 
        queryParameters: {
          'mes': mesQuery,
          'ano': anoQuery,
        },
      );

      if (mounted) {
        setState(() {
          // 🎯 MAPEAMENTO CORRIGIDO: Vinculado às chaves reais do back-end
          _linhasEspelho = response.data['relatorioMensal'] ?? [];
          _resumoDashboard = response.data['resumoDashboard'];
        });
      }
    } catch (e) {
      String mensagemErro = "Erro ao carregar relatório de ponto.";
      if (e is DioException) {
        mensagemErro = "A API do Render rejeitou a busca do espelho de ponto.";
      }
      _mostrarSnackbar(mensagemErro, esErro: true);
      if (mounted) {
        setState(() {
          _linhasEspelho = [];
          _resumoDashboard = null;
        });
      }
    } finally {
      if (mounted) setState(() => _carregandoEspelho = false);
    }
  }

  void _mostrarSnackbar(String msg, {bool esErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: esErro ? Colors.red : Colors.green),
    );
  }

  Future<void> _selecionarMesAno() async {
    final DateTime? mudou = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECIONE O MÊS DO ESPELHO',
    );

    if (mudou != null && mudou != _mesSelecionado) {
      setState(() {
        _mesSelecionado = DateTime(mudou.year, mudou.month);
      });
      _buscarDadosEspelho();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoFuncionarios) {
      return const Center(child: CircularProgressIndicator());
    }

    final textoMes = DateFormat("MMMM 'de' yyyy", "pt_BR").format(_mesSelecionado);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔎 FILTROS SUPERIORES (FUNCIONÁRIO E MÊS)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _funcionarioSelecionadoId,
                        decoration: const InputDecoration(
                          labelText: 'Funcionário',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _funcionarios.map<DropdownMenuItem<String>>((func) {
                          return DropdownMenuItem<String>(
                            value: func['id'],
                            child: Text(func['nome']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _funcionarioSelecionadoId = val);
                          _buscarDadosEspelho();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        icon: const Icon(Icons.calendar_month, color: Color(0xFF1E3A8A)),
                        label: Text(
                          textoMes.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        onPressed: _selecionarMesAno,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 📊 MINI DASHBOARD DE RESUMO MENSAL
            if (_resumoDashboard != null) ...[
              Row(
                children: [
                  _buildCardResumo(
                    titulo: 'Faltas no Mês',
                    valor: _resumoDashboard!['totalFaltas'].toString(),
                    cor: Colors.red.shade700,
                  ),
                  const SizedBox(width: 16),
                  _buildCardResumo(
                    titulo: 'Saldo Banco de Horas',
                    valor: _resumoDashboard!['saldoBancoHorasFormatado'] ?? '00:00',
                    cor: (_resumoDashboard!['saldoBancoHorasMinutos'] ?? 0) >= 0 
                        ? Colors.green.shade700 
                        : Colors.red.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // 📊 TABELA DO ESPELHO DE PONTO
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: _carregandoEspelho
                    ? const Center(child: CircularProgressIndicator())
                    : _linhasEspelho.isEmpty
                        ? const Center(child: Text('Nenhum registro de ponto encontrado para este período.'))
                        : _buildTabelaEspelho(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardResumo({required String titulo, required String valor, required Color cor}) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(valor, style: TextStyle(color: cor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabelaEspelho() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Batidas Registradas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Horas Trabalhadas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Saldo do Dia', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _linhasEspelho.map<DataRow>((linha) {
            // Tratamento da Data (Converte YYYY-MM-DD para DD/MM/YYYY)
            final String dataCrua = linha['data'] ?? '';
            String dataExibicao = dataCrua;
            if (dataCrua.contains('-') && dataCrua.split('-').length == 3) {
              final partes = dataCrua.split('-');
              dataExibicao = '${partes[2]}/${partes[1]}/${partes[0]}';
            }

            final status = linha['status'] ?? 'Regular';
            final horasTrabalhadas = linha['horasTrabalhadas'] ?? '00:00';
            final saldoDoDia = linha['saldoDoDia'] ?? '00:00';
            final List<dynamic> batidas = linha['batidas'] ?? [];

            // Define as cores com base no status igual ao CSS do Vue
            Color corStatus = Colors.green.shade700;
            String statusLower = status.toString().toLowerCase();
            if (statusLower.contains('falta')) corStatus = Colors.red.shade700;
            if (statusLower.contains('atraso')) corStatus = Colors.amber.shade900;
            if (statusLower.contains('folga')) corStatus = Colors.grey.shade600;

            return DataRow(cells: [
              DataCell(Text(dataExibicao, style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: corStatus.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              // 🎯 RENDERIZAÇÃO DAS BADGES DE BATIDAS CLICÁVEIS COM LINK DE MAPA
              DataCell(
                batidas.isEmpty
                    ? const Text('-', style: TextStyle(color: Colors.grey))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: batidas.map<Widget>((b) {
                          final horaBatida = b['hora'] ?? '--:--';
                          final double? lat = b['latitude'] != null ? double.tryParse(b['latitude'].toString()) : null;
                          final double? lng = b['longitude'] != null ? double.tryParse(b['longitude'].toString()) : null;
                          final bool possuiGps = lat != null && lng != null;

                          // Envolvemos a badge em um InkWell para torná-la clicável se houver GPS
                          return InkWell(
                            onTap: possuiGps 
                                ? () {
                                    // Feedback visual rápido para o administrador
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Abrindo localização das $horaBatida no mapa...'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    
                                    // 🌐 URL de busca do Google Maps baseada nas coordenadas da batida
                                    final String urlMapa = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                    
                                    // Se você estiver utilizando o pacote url_launcher, remova o comentário abaixo:
                                    launchUrl(Uri.parse(urlMapa), mode: LaunchMode.externalApplication);
                                  }
                                : null, // Desabilita o clique caso a batida não possua coordenadas
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: possuiGps ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6), // Azul claro se tiver GPS, cinza se não
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: possuiGps ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB)
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    horaBatida, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12, 
                                      color: possuiGps ? const Color(0xFF1E40AF) : const Color(0xFF374151)
                                    ),
                                  ),
                                  if (possuiGps) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.location_on, color: Colors.redAccent, size: 13),
                                  ]
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              DataCell(Text(horasTrabalhadas)),
              DataCell(
                Text(
                  saldoDoDia, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: saldoDoDia.startsWith('-') ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}