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
  Map<String, dynamic>? _resumoDashboard; 
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
                        initialValue: _funcionarioSelecionadoId,
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
                    color: corStatus.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              // 🎯 RENDERIZAÇÃO DAS BADGES COM RECONHECIMENTO DE HISTÓRICO DE AUDITORIA
              DataCell(
                batidas.isEmpty
                    ? const Text('-', style: TextStyle(color: Colors.grey))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: batidas.map<Widget>((b) {
                          final horaBatida = b['hora'] ?? '--:--';
                          final bool foiAlterada = b['foiAlterada'] ?? false; // 👈 Flag de auditoria mapeada da API
                          final String? justificativa = b['justificativa'];
                          final String? horaOriginal = b['horaOriginal'];

                          final double? lat = b['latitude'] != null ? double.tryParse(b['latitude'].toString()) : null;
                          final double? lng = b['longitude'] != null ? double.tryParse(b['longitude'].toString()) : null;
                          final bool possuiGps = lat != null && lng != null;

                          // Define as cores dinâmicas da badge imitando o CSS do Vue (.alterada vs .normal)
                          final Color corBadgeFundo = foiAlterada ? const Color(0xFFFFF7ED) : (possuiGps ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6));
                          final Color corBadgeBorda = foiAlterada ? const Color(0xFFFFEDD5) : (possuiGps ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB));
                          final Color corTexto = foiAlterada ? const Color(0xFFC2410C) : (possuiGps ? const Color(0xFF1E40AF) : const Color(0xFF374151));

                          return InkWell(
                            onTap: () {
                              // 🔥 SE O PONTO FOI ALTERADO: Abre um diálogo explicativo contendo a trilha do MTE
                              if (foiAlterada) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.history_toggle_off, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text('Auditoria de Marcação', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Horário Efetivo: $horaBatida', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('Horário Original de Fábrica: ${horaOriginal ?? '--:--'}', style: const TextStyle(color: Colors.grey)),
                                        const Divider(height: 24),
                                        const Text('Justificativa Legal Informada:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '"${justificativa ?? 'Sem justificativa informada.'}"',
                                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      // Se além de ver os logs, o administrador quiser ver o GPS dessa batida:
                                      if (possuiGps)
                                        TextButton.icon(
                                          icon: const Icon(Icons.map, size: 16),
                                          label: const Text('Ver GPS'),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            launchUrl(Uri.parse('http://googleusercontent.com/maps.google.com/maps?q=$lat,$lng'), mode: LaunchMode.externalApplication);
                                          },
                                        ),
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                                    ],
                                  ),
                                );
                              } else if (possuiGps) {
                                // Se for um ponto normal com GPS, apenas abre o mapa direto
                                launchUrl(Uri.parse('http://googleusercontent.com/maps.google.com/maps?q=$lat,$lng'), mode: LaunchMode.externalApplication);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: corBadgeFundo,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: corBadgeBorda),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    horaBatida, 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTexto),
                                  ),
                                  const SizedBox(width: 4),
                                  if (foiAlterada)
                                    const Icon(Icons.edit, color: Colors.orange, size: 12)
                                  else if (possuiGps)
                                    const Icon(Icons.location_on, color: Colors.redAccent, size: 12),
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