import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart'; //
import '../../services/api_service.dart'; //
import 'package:url_launcher/url_launcher.dart'; //

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

  // CONTROLADORES GLOBAIS DO MODAL DE AJUSTE
  final _horaController = TextEditingController();
  final _justificativaController = TextEditingController();
  bool _modalCarregando = false;
  String _modalErro = "";

  @override
  void initState() {
    super.initState();
    _buscarFuncionarios();
  }

  @override
  void dispose() {
    _horaController.dispose();
    _justificativaController.dispose();
    super.dispose();
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
          } else {
            _funcionarioSelecionadoId = '';
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
    if (_funcionarioSelecionadoId == null || _funcionarioSelecionadoId!.isEmpty) return;

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

  // FLUXO DE GRAVAÇÃO DO AJUSTE (EDITAR VS INCLUIR MANUAL)
  Future<void> _salvarAjustePonto({
    required String modo,
    String? batidaId,
    required String dataDia,
    required StateSetter setModalState,
    required BuildContext modalContext,
  }) async {
    final justificativa = _justificativaController.text.trim();
    if (justificativa.isEmpty || justificativa.length < 10) {
      setModalState(() {
        _modalErro = 'Por favor, insira uma justificativa detalhada (mínimo 10 caracteres).';
      });
      return;
    }

    setModalState(() {
      _modalCarregando = true;
      _modalErro = '';
    });

    try {
      if (modo == 'EDITAR') {
        await ApiService.dio.put('/ponto/ajustar/$batidaId', data: {
          'novaHora': _horaController.text.trim(),
          'novaData': dataDia,
          'justificativa': justificativa
        });
      } else {
        await ApiService.dio.post('/ponto/incluir-manual', data: {
          'usuarioId': _funcionarioSelecionadoId,
          'dataDia': dataDia,
          'hora': _horaController.text.trim(),
          'justificativa': justificativa
        });
      }

      Navigator.pop(modalContext);
      _buscarDadosEspelho();
      _mostrarSnackbar(modo == 'EDITAR' ? 'Ajuste gravado com sucesso!' : 'Marcação manual incluída!');
    } catch (error) {
      String msg = 'Erro ao processar alteração de ponto.';
      if (error is DioException) {
        msg = error.response?.data?['erro'] ?? msg;
      }
      setModalState(() {
        _modalErro = msg;
      });
    } finally {
      setModalState(() {
        _modalCarregando = false;
      });
    }
  }

  // AMORTIZAÇÃO LÓGICA DE MARCAÇÃO FISCAL PORTARIA 671 MTE
  Future<void> _apagarPonto({
    required String batidaId,
    required StateSetter setModalState,
    required BuildContext modalContext,
  }) async {
    final justificativa = _justificativaController.text.trim();
    if (justificativa.isEmpty || justificativa.length < 10) {
      setModalState(() {
        _modalErro = 'Para apagar ou desconsiderar uma marcação, uma justificativa de no mínimo 10 caracteres é obrigatória.';
      });
      return;
    }

    setModalState(() {
      _modalCarregando = true;
      _modalErro = '';
    });

    try {
      await ApiService.dio.post('/ponto/desconsiderar/$batidaId', data: {
        'justificativa': justificativa
      });

      Navigator.pop(modalContext);
      _buscarDadosEspelho();
      _mostrarSnackbar('Marcação desconsiderada com sucesso do banco de horas!');
    } catch (error) {
      String msg = 'Erro ao desconsiderar ponto.';
      if (error is DioException) {
        msg = error.response?.data?['erro'] ?? msg;
      }
      setModalState(() {
        _modalErro = msg;
      });
    } finally {
      setModalState(() {
        _modalCarregando = false;
      });
    }
  }

  // 🟢 RECONSTRUÇÃO TOTAL: Transmutado de AlertDialog para showModalBottomSheet para expurgar de vez o quadrado cinza físico
  void _abrirModalAjuste({
    required String modo,
    String? batidaId,
    required String dataDoDia,
    String? horaInicial,
    String? justificativaInicial,
    double? latitude,
    double? longitude,
  }) {
    _horaController.text = horaInicial ?? "08:00";
    _justificativaController.text = justificativaInicial ?? "";
    _modalErro = "";
    _modalCarregando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o painel suba além da metade da tela
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<String> partesData = dataDoDia.split('-');
            final String dataFormatadaExibicao = partesData.length == 3 ? '${partesData[2]}/${partesData[1]}/${partesData[0]}' : dataDoDia;

            return Padding(
              // 🟢 EVITA TECLADO COBRINDO CAMPOS: Adiciona padding dinâmico baseado na subida do teclado nativo
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.80, // Limita a ocupação total a 80% da viewport
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pequena barra superior indicando arrasto (Padrão de UX Mobile)
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      Text(
                        modo == 'EDITAR' ? '📝 Ajustar Registro de Ponto' : '➕ Incluir Marcação Manual',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Atenção: De acordo com a Portaria 671 do MTE, qualquer alteração ou inclusão manual de ponto fica registrada permanentemente na folha de auditoria para fins fiscais.',
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      
                      // Painel de Geolocalização por satélite
                      if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) ...[
                        const Text('Localização do Registro (GPS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFBFDBFE))),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lat: ${latitude.toStringAsFixed(5)}\nLong: ${longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
                                  if (await canLaunchUrl(googleMapsUrl)) {
                                    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                                  }else {
                                    _mostrarSnackbar('Não foi possível abrir o aplicativo de mapas.', esErro: true);
                                  }
                                },  
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text('Ver Mapa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Text('Data da Ocorrência', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: TextEditingController(text: dataFormatadaExibicao),
                        enabled: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Horário Efetivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _horaController,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          hintText: 'Ex: 08:00',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Justificativa Legal / Motivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _justificativaController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Colaborador esqueceu de bater o ponto na entrada do plantão...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Mínimo de 10 caracteres. Forneça o motivo detalhado.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      if (_modalErro.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
                          child: Text(_modalErro, style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // Seção de botões reposicionados de forma linear confortável para o dedão
                      Row(
                        children: [
                          if (modo == 'EDITAR' && batidaId != null)
                            TextButton(
                              onPressed: _modalCarregando
                                  ? null
                                  : () => _apagarPonto(batidaId: batidaId, setModalState: setModalState, modalContext: ctx),
                              style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
                              child: const Text('❌ Desconsiderar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _modalCarregando ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _modalCarregando
                                ? null
                                : () => _salvarAjustePonto(modo: modo, batidaId: batidaId, dataDia: dataDoDia, setModalState: setModalState, modalContext: ctx),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                            child: _modalCarregando
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(modo == 'EDITAR' ? 'Gravar Ajuste' : 'Salvar Registro', style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                    const SizedBox(width: 12),
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
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Batidas Registradas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Horas Trabalhadas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Saldo do Dia', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _linhasEspelho.map<DataRow>((linha) {
            final String dataCrua = inlineData(linha['data'] ?? '');
            String dataExibicao = dataCrua;
            if (dataCrua.contains('-') && dataCrua.split('-').length == 3) {
              final partes = dataCrua.split('-');
              dataExibicao = '${partes[2]}/${partes[1]}/${partes[0]}';
            }

            final status = linha['status'] ?? 'Regular';
            final horasTrabalhadas = mergeHoras(linha['horasTrabalhadas'] ?? '00:00');
            final saldoDoDia = linha['saldoDoDia'] ?? '00:00';
            final List<dynamic> batidas = mergeBatidas(linha['batidas'] ?? []);
            final String? observacaoAfastamento = linha['observacao'];

            final bool ehAfastado = status.toString().toUpperCase() == 'AFASTADO';

            Color corStatus = Colors.green.shade700;
            String statusLower = status.toString().toLowerCase();
            if (statusLower.contains('falta')) corStatus = Colors.red.shade700;
            if (statusLower.contains('atraso')) corStatus = Colors.amber.shade900;
            if (statusLower.contains('folga')) corStatus = Colors.grey.shade600;
            if (ehAfastado) corStatus = const Color(0xFF166534);

            return DataRow(
              color: ehAfastado 
                  ? MaterialStateProperty.all(const Color(0xFFF0FDF4)) 
                  : null,
              cells: [
                DataCell(Text(dataExibicao, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ehAfastado ? const Color(0xFFDCFCE7) : corStatus.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ehAfastado ? 'AFASTAMENTO' : status, 
                      style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                
                DataCell(
                  ehAfastado
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🏝️ ${observacaoAfastamento ?? "Colaborador sob Regime de Afastamento Legal / Férias"}'.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...batidas.map<Widget>((b) {
                              final horaBatida = b['hora'] ?? '--:--';
                              final bool foiAlterada = b['foiAlterada'] ?? false;
                              final bool foiDesconsiderada = b['foiDesconsiderada'] ?? false;
                              final String? justificativa = b['justificativa'];
                              final String? horaOriginal = b['horaOriginal'];
                              final String? batidaId = b['id']?.toString();
                              
                              final double? latPonto = b['latitude'] != null ? double.tryParse(b['latitude'].toString()) : null;
                              final double? lngPonto = b['longitude'] != null ? double.tryParse(b['longitude'].toString()) : null;

                              Color corBadgeFundo = const Color(0xFFF3F4F6);
                              Color corBadgeBorda = const Color(0xFFE5E7EB);
                              Color corTexto = const Color(0xFF374151);
                              TextDecoration decoracaoTexto = TextDecoration.none;

                              if (foiDesconsiderada) {
                                corBadgeFundo = const Color(0xFFFEF2F2);
                                corBadgeBorda = const Color(0xFFFCA5A5);
                                corTexto = const Color(0xFF991B1B);
                                decoracaoTexto = TextDecoration.lineThrough;
                              } else if (foiAlterada) {
                                corBadgeFundo = const Color(0xFFFFF7ED);
                                corBadgeBorda = const Color(0xFFFFEDD5);
                                corTexto = const Color(0xFFC2410C);
                              }

                              return Tooltip(
                                message: foiDesconsiderada 
                                    ? 'Marcação Inválida/Desconsiderada\nOriginal: $horaOriginal\nMotivo: "$justificativa"'
                                    : (foiAlterada ? 'Ponto Modificado\nOriginal: $horaOriginal\nMotivo: "$justificativa"' : 'Ponto Válido'),
                                child: InkWell(
                                  onTap: () {
                                    _abrirModalAjuste(
                                      modo: 'EDITAR',
                                      batidaId: batidaId,
                                      dataDoDia: dataCrua,
                                      horaInicial: foiDesconsiderada ? horaOriginal : horaBatida,
                                      justificativaInicial: justificativa,
                                      latitude: latPonto,
                                      longitude: lngPonto,
                                    );
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
                                          foiDesconsiderada ? (horaOriginal ?? '--:--') : horaBatida, 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 12, 
                                            color: corTexto,
                                            decoration: decoracaoTexto,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (foiDesconsiderada)
                                          const Icon(Icons.block, color: Colors.red, size: 12)
                                        else if (foiAlterada)
                                          const Icon(Icons.edit, color: Colors.orange, size: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Incluir marcação extra',
                              onPressed: () {
                                _abrirModalAjuste(modo: 'INCLUIR', dataDoDia: dataCrua);
                              },
                            ),
                          ],
                        ),
                ),
                DataCell(Text(horasTrabalhadas)),
                DataCell(
                  Text(
                    saldoDoDia, 
                    style: TextStyle(
                      fontWeight: ehAfastado ? FontWeight.bold : FontWeight.normal,
                      color: saldoDoDia.startsWith('-') ? Colors.red.shade600 : Colors.green.shade600,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String mergeHoras(String s) => s;
  List<dynamic> mergeBatidas(List<dynamic> l) => l;
  String inlineData(String s) => s;
}