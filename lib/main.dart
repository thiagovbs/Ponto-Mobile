import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'services/api_service.dart';
import 'screens/admin_login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/funcionario_totem.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart'; 

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.inicializar();
  await initializeDateFormatting('pt_BR', null);

  await Hive.initFlutter();
  Hive.registerAdapter(FuncionarioTotemAdapter());

  await Hive.openBox<FuncionarioTotem>('funcionarios_box');
  await Hive.openBox<Map>('pontos_offline_box'); // Fila de sincronização ativa
  await Hive.openBox<String>('configuracao_box'); // Caixa permanente para salvar o Token do Totem da Empresa

  try {
    _cameras = await availableCameras();
  } catch (e) {
    _cameras = [];
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ponto Eletrônico',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RegistrarPontoScreen(),
    );
  }
}

class RegistrarPontoScreen extends StatefulWidget {
  const RegistrarPontoScreen({super.key});

  @override
  State<RegistrarPontoScreen> createState() => _RegistrarPontoScreenState();
}

class _RegistrarPontoScreenState extends State<RegistrarPontoScreen> {
  final TextEditingController _pesquisaController = TextEditingController();
  final Box<FuncionarioTotem> _funcsBox = Hive.box<FuncionarioTotem>('funcionarios_box');
  
  // Acessando a caixa da fila offline
  final Box<Map> _pontosOfflineBox = Hive.box<Map>('pontos_offline_box');
  
  // Acessando a caixa de configurações do dispositivo
  final Box<String> _configBox = Hive.box<String>('configuracao_box');
  final _tokenTotemController = TextEditingController();

  List<FuncionarioTotem> _funcionariosFiltrados = [];
  FuncionarioTotem? _funcionarioSelecionado;
  bool _carregando = false;
  bool _focoInput = false;

  CameraController? _cameraController;
  bool _mostrarCamera = false;
  String? _fotoBase64;

  // Declarar o objeto do Timer para controle de ciclo
  Timer? _timerSincronizacao;

  @override
  void initState() {
    super.initState();
    _recuperarTokenTotemSalvo(); // Recupera o token do Hive na inicialização
    _sincronizarECarregarFuncionarios();
    _pedirPermissoesGps();
    _escutarMudancasDeRede(); // Ativa monitoramento de conectividade para o upload automático
    _timerSincronizacao = Timer.periodic(const Duration(minutes: 1), (timer) {
      debugPrint("🔄 Timer acionado: Atualizando banco de dados local do Totem...");
      _sincronizarECarregarFuncionarios(); 
      _processarFilaOffline();             
    });
  }

  // Resgata o token guardado no armazenamento local e injeta na propriedade estática do ApiService
  void _recuperarTokenTotemSalvo() {
    final tokenSalvo = _configBox.get('token_totem');
    if (tokenSalvo != null && tokenSalvo.isNotEmpty) {
      ApiService.tokenTotem = tokenSalvo;
      debugPrint("🔑 Token do Totem sincronizado no interceptor global: $tokenSalvo");
    }
  }

  // FORMULÁRIO MODAL DE VÍNCULO CORPORATIVO DO TABLET COM A EMPRESA
  void _abrirModalConfiguracaoToken() {
    _tokenTotemController.text = _configBox.get('token_totem') ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.vignette_rounded, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text('Vincular Empresa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insira o Token de Identificação do Totem gerado no painel web da sua empresa para sincronizar a base local de colaboradores.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenTotemController,
              decoration: const InputDecoration(
                labelText: 'Token do Totem da Empresa',
                hintText: 'Digite ou cole o UUID do token...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              final tokenDigitado = _tokenTotemController.text.replaceAll(RegExp(r'[\n\r\t ]'), '').trim();
              if (tokenDigitado.isEmpty) {
                _mostrarSnackbar('O token não pode ser vazio.');
                return;
              }
              
              // SEQUÊNCIA ASSÍNCRONA GARANTIDA: Aguarda a persistência física antes de prosseguir
              await _configBox.put('token_totem', tokenDigitado);
              
              setState(() {
                ApiService.tokenTotem = tokenDigitado; // Atualiza a variável em memória global
              });
              
              if (ctx.mounted) Navigator.pop(ctx);
              _mostrarSnackbar('Empresa vinculada com sucesso ao dispositivo!');
              
              // Pequeno delay para garantir que o interceptor do Dio monte os cabeçalhos
              await Future.delayed(const Duration(milliseconds: 100));
              _sincronizarECarregarFuncionarios(); 
            },
            child: const Text('Salvar Token', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // iOS
  /*oid _escutarMudancasDeRede() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _processarFilaOffline();
      }
    });
  }*/
  

  // Android
  void _escutarMudancasDeRede() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _processarFilaOffline();
      }
    });
  }

  // PROCESSADOR DA FILA OFFLINE: Varre o Hive e esvazia os pontos represados
  Future<void> _processarFilaOffline() async {
    if (_pontosOfflineBox.isEmpty) return;

    debugPrint("🔄 [Fila Offline] Detectada tentativa de sincronização automática...");
    final chavesCopia = List.from(_pontosOfflineBox.keys);

    for (var chave in chavesCopia) {
      final payload = _pontosOfflineBox.get(chave);
      if (payload == null) continue;

      try {
        debugPrint("⏳ Enviando registro da chave [$chave] para o ID de Usuário: ${payload['usuarioId']}");
        
        if (payload['fotoBase64'] != null) {
          payload['fotoBase64'] = payload['fotoBase64'].toString().replaceAll('\n', '').replaceAll('\r', '');
        }

        await ApiService.dio.post('/ponto/bater', data: payload);
        await _pontosOfflineBox.delete(chave); 
        debugPrint("✅ Registro da chave [$chave] sincronizado e limpo da fila local.");
      } catch (e) {
        debugPrint("=========================================================");
        debugPrint("🚨 ERRO CRÍTICO NA SINCRONIZAÇÃO DA CHAVE DE PONTO [$chave]");
        debugPrint("📦 Payload enviado pelo Flutter: ${json.encode(payload)}");
        
        if (e is DioException) {
          debugPrint("➔ Causa: Falha de resposta na requisição HTTP (DioException)");
          debugPrint("➔ Status Code Recebido: ${e.response?.statusCode}");
          debugPrint("➔ Tipo do Erro: ${e.type}");
          debugPrint("➔ Resposta do Servidor Render: ${e.response?.data}");
          debugPrint("➔ Mensagem de Erro Nativa: ${e.message}");
        } else {
          debugPrint("➔ Causa: Falha desconhecida no runtime do Dart/Flutter");
          debugPrint("➔ Detalhe Técnico: $e");
        }
        debugPrint("=========================================================");
        break; 
      }
    }
  }

  // MÉTODO DE SINCRONIZAÇÃO OTIMIZADO: Garante a persistência resiliente e força re-renderização
  Future<void> _sincronizarECarregarFuncionarios() async {
    try {
      debugPrint("📡 [Totem Sync] Solicitando lista atualizada de colaboradores para a API...");
      final response = await ApiService.dio.get('/usuarios');
      
      if (response.data is List) {
        final listaBruta = response.data as List<dynamic>;
        debugPrint("📦 [Totem Sync] Backend retornou ${listaBruta.length} registros.");

        // Limpa o cache antigo do Hive de forma atômica para evitar duplicados ou dados órfãos
        await _funcsBox.clear();
        
        int contagemInseridos = 0;
        for (var item in listaBruta) {
          try {
            final novoFunc = FuncionarioTotem.fromJson(item as Map<String, dynamic>);
            await _funcsBox.add(novoFunc);
            contagemInseridos++;
          } catch (parseError) {
            debugPrint("⚠️ [Totem Sync] Falha ao mapear registro individual (Campos ausentes no JSON): $parseError");
          }
        }
        
        debugPrint("✅ [Totem Sync] Hive atualizado com sucesso: $contagemInseridos colaboradores salvos localmente.");
      }
    } catch (e) {
      debugPrint("🚨 [Totem Sync] Erro Crítico ao sincronizar usuários. Operando com cache local. Detalhe: $e");
    }
    
    // Força o Flutter a atualizar as variáveis de estado e repovoar os filtros de busca imediatamente
    if (mounted) {
      setState(() {
        if (_pesquisaController.text.isNotEmpty) {
          _aoDigitarNome(_pesquisaController.text);
        }
      });
    }
  }

  Future<void> _pedirPermissoesGps() async {
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    }
  }

  // 🟢 MÉTODO DE BUSCA BLINDADO CONTRA DIRETIVAS REGEX: Sanitiza entrada e cache simultaneamente
  void _aoDigitarNome(String texto) {
    setState(() {
      _funcionarioSelecionado = null;
      final buscaLimpa = texto.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      if (buscaLimpa.isEmpty) {
        _funcionariosFiltrados = [];
      } else {
        _funcionariosFiltrados = _funcsBox.values.where((f) {
          final nomeCompleto = f.nome.toLowerCase();
          
          // Higieniza completamente o CPF salvo no Hive para evitar desencontros de pontuação do input
          final cpfLimpoHive = f.cpf.replaceAll(RegExp(r'[^0-9]'), '');
          
          return nomeCompleto.contains(buscaLimpa) || cpfLimpoHive.contains(buscaLimpa);
        }).toList();
      }
      debugPrint("🔍 [Busca Totem] Digitado: '$texto' | Filtrados Encontrados no Hive: ${_funcionariosFiltrados.length}");
    });
  }

  Future<void> _abrirCamera() async {
    if (_cameras.isEmpty) {
      _mostrarSnackbar('Nenhuma câmera encontrada.');
      return;
    }

    final frontal = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(frontal, ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    setState(() => _mostrarCamera = true);
  }

  Future<void> _tirarFoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      setState(() => _carregando = true);
      final XFile foto = await _cameraController!.takePicture();
      final bytes = await foto.readAsBytes();
      
      final base64Limpo = base64Encode(bytes).replaceAll('\n', '').replaceAll('\r', '');  

      setState(() {
        _fotoBase64 = 'data:image/jpeg;base64,$base64Limpo';
        _mostrarCamera = false;
      });
    } catch (e) {
      _mostrarSnackbar('Erro ao capturar foto: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _enviarPonto() async {
    if (_funcionarioSelecionado == null || _fotoBase64 == null) return;

    setState(() => _carregando = true);

    double latitude = 0.0;
    double longitude = 0.0;

    try {
      debugPrint("🛰️ Solicitando sinal de GPS do dispositivo...");
      Position posicao = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      latitude = posicao.latitude;
      longitude = posicao.longitude;
      debugPrint("🛰️ GPS capturado com sucesso: ($latitude, $longitude)");
    } catch (gpsErro) {
      latitude = 0.0;
      longitude = 0.0;
      debugPrint("⚠️ Sinal GPS não detectado a tempo ou desativado. Prosseguindo com coordenadas 0.0 para envio.");
    }

    final String usuarioIdLimpo = _funcionarioSelecionado!.id.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
    final String fotoLimpa = _fotoBase64!.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
    final String dataHoraLimpa = DateTime.now().toIso8601String().replaceAll(RegExp(r'[\n\r\t]'), '').trim();

    final payload = {
      'usuarioId': usuarioIdLimpo,
      'empresaId': ApiService.empresaId ?? _funcionarioSelecionado!.id, 
      'filialId': ApiService.filialId,
      'setorId': ApiService.setorId,
      'latitude': latitude,
      'longitude': longitude,
      'fotoBase64': fotoLimpa,
      'dataHora': dataHoraLimpa
    };

    try {
      debugPrint("🖥️ Tentando enviar ponto online para a API...");
      await ApiService.dio.post('/ponto/bater', data: payload);
      
      _mostrarDialogSucesso('Ponto registrado com sucesso online para ${_funcionarioSelecionado!.nome}!');
      _limparCampos();
    } catch (networkError) {
      debugPrint("❌ Falha de conectividade detectada. Salvando registro na fila offline local.");
      await _pontosOfflineBox.add(payload); 
      
      _mostrarDialogSucesso(
        'Modo Offline Ativado!\n\nO ponto de ${_funcionarioSelecionado!.nome} foi guardado na memória do Totem e será enviado assim que a internet retornar.'
      );
      _limparCampos();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _limparCampos() {
    setState(() {
      _fotoBase64 = null;
      _funcionarioSelecionado = null;
      _pesquisaController.clear();
    });
  }

  void _mostrarSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarDialogSucesso(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batida Concluída! 📍'),
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarCamera && _cameraController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: CameraPreview(_cameraController!)),
              Container(
                padding: const EdgeInsets.all(24),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, size: 48, color: Colors.white),
                  onPressed: _carregando ? null : _tirarFoto,
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Color(0xFF64748B), size: 24),
          tooltip: 'Configurar Vínculo da Empresa',
          onPressed: _abrirModalConfiguracaoToken,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF1E3A8A), size: 28),
            tooltip: 'Área do Administrador',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('⏱️ Registro de Ponto - Totem',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                ),
                const SizedBox(height: 24),
                const Text('Quem está registrando o ponto?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                
                TextField(
                  controller: _pesquisaController,
                  onChanged: _aoDigitarNome,
                  onTap: () => setState(() => _focoInput = true),
                  decoration: InputDecoration(
                    hintText: 'Digite seu nome ou CPF...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                if (_focoInput && _funcionariosFiltrados.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _funcionariosFiltrados.length,
                      itemBuilder: (context, index) {
                        final func = _funcionariosFiltrados[index];
                        return ListTile(
                          title: Text(func.nome),
                          subtitle: Text('CPF: ${func.cpf}'),
                          onTap: () {
                            setState(() {
                              _funcionarioSelecionado = func;
                              _pesquisaController.text = func.nome;
                              _funcionariosFiltrados = [];
                              _focoInput = false;
                            });
                          },
                        );
                      },
                    ),
                  ),

                if (_funcionarioSelecionado != null) ...[
                  const SizedBox(height: 24),
                  if (_fotoBase64 != null) ...[
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_fotoBase64!.split(',')[1]),
                          width: 160,
                          height: 210,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _abrirCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tirar Outra Foto'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: _carregando ? null : _enviarPonto,
                        child: _carregando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Confirmar Batida 📍', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ] else ...[
                    Text('Olá, ${_funcionarioSelecionado!.nome}! Tire uma foto para confirmar sua identidade.',
                        textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        onPressed: _abrirCamera,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text('Abrir Câmera', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    )
                  ]
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}