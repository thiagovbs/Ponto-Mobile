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
  
  // 🟢 Acessando a caixa da fila offline
  final Box<Map> _pontosOfflineBox = Hive.box<Map>('pontos_offline_box');
  
  List<FuncionarioTotem> _funcionariosFiltrados = [];
  FuncionarioTotem? _funcionarioSelecionado;
  bool _carregando = false;
  bool _focoInput = false;

  CameraController? _cameraController;
  bool _mostrarCamera = false;
  String? _fotoBase64;

  // 🟢 Declarar o objeto do Timer para controle de ciclo
  Timer? _timerSincronizacao;

  @override
  void initState() {
    super.initState();
    _sincronizarECarregarFuncionarios();
    _pedirPermissoesGps();
    _escutarMudancasDeRede(); // 🟢 Ativa monitoramento de conectividade para o upload automático
    _timerSincronizacao = Timer.periodic(const Duration(minutes: 1), (timer) {
      debugPrint("🔄 Timer acionado: Atualizando banco de dados local do Totem...");
      _sincronizarECarregarFuncionarios(); 
      _processarFilaOffline();             
    });
  }

  // 🟢 ESCUTADOR AUTOMÁTICO DE INTERNET: Sempre que a rede voltar, despacha os pontos locais pro Render
  void _escutarMudancasDeRede() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _processarFilaOffline();
      }
    });
  }

  // 🟢 PROCESSADOR DA FILA OFFLINE: Varre o Hive e esvazia os pontos represados
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

      // Executa o envio para a API
      await ApiService.dio.post('/ponto/bater', data: payload);
      
      // Se a API aceitar, remove com segurança da fila local
      await _pontosOfflineBox.delete(chave); 
      debugPrint("✅ Registro da chave [$chave] sincronizado e limpo da fila local.");
    } catch (e) {
      // 2) 🔴 GERAÇÃO DE LOGS DE ERRO ESPECÍFICOS DA ADUANA DE REDE
      debugPrint("=========================================================");
      debugPrint("🚨 ERRO CRÍTICO NA SINCRONIZAÇÃO DA CHAVE DE PONTO [$chave]");

      // 🟢 DETALHE CRUCIAL: Imprime o que o Flutter tentou mandar para você comparar com o backend
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

      // Interrompe o loop para não ficar bombardeando o servidor se o Render estiver fora do ar
      break; 
    }
  }
}

  Future<void> _sincronizarECarregarFuncionarios() async {
    try {
      final response = await ApiService.dio.get('/usuarios');
      if (response.data is List) {
        final listaBruta = response.data as List<dynamic>;
        final funcionariosBackend = listaBruta.where((u) => u['perfil'] == 'FUNCIONARIO').toList();

        await _funcsBox.clear();
        for (var item in funcionariosBackend) {
          final novoFunc = FuncionarioTotem.fromJson(item as Map<String, dynamic>);
          await _funcsBox.add(novoFunc);
        }
        debugPrint("Hive sincronizado com sucesso: ${_funcsBox.length} colaboradores salvos localmente.");
      }
    } catch (e) {
      debugPrint("Aviso de Rede: Falha ao sincronizar usuários. Operando com cache. Erro: $e");
    }
    setState(() {});
  }

  Future<void> _pedirPermissoesGps() async {
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    }
  }

  void _aoDigitarNome(String texto) {
    setState(() {
      _funcionarioSelecionado = null;
      if (texto.trim().isEmpty) {
        _funcionariosFiltrados = [];
      } else {
        _funcionariosFiltrados = _funcsBox.values.where((f) {
          final nome = f.nome.toLowerCase();
          final cpf = f.cpf.replaceAll(RegExp(r'[^0-9]'), '');
          final busca = texto.toLowerCase();
          return nome.contains(busca) || cpf.contains(busca);
        }).toList();
      }
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
      
      // 🟢 COMDANDO CRUCIAL: Codifica em Base64 e remove todas as quebras de linha (\n, \r) da string
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

  // 🟢 TOTALMENTE MODIFICADO: Fluxo Híbrido Completo (Online com contingência Automática Offline)
  Future<void> _enviarPonto() async {
    if (_funcionarioSelecionado == null || _fotoBase64 == null) return;

    setState(() => _carregando = true);

    double latitude = 0.0;
    double longitude = 0.0;

    // 1) 🌍 TENTATIVA DE CAPTURA DO GPS (Com isolamento de erro)
    try {
      debugPrint("🛰️ Solicitando sinal de GPS do dispositivo...");
      Position posicao = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Tempo otimizado para não travar o funcionário na tela
      );
      latitude = posicao.latitude;
      longitude = posicao.longitude;
      debugPrint("🛰️ GPS capturado com sucesso: ($latitude, $longitude)");
    } catch (gpsErro) {
      // Se o sinal não for detectado a tempo ou o GPS estiver desligado, mantemos 0.0
      latitude = 0.0;
      longitude = 0.0;
      debugPrint("⚠️ Sinal GPS não detectado a tempo ou desativado. Prosseguindo com coordenadas 0.0 para envio.");
    }

    // 🟢 HIGIENIZAÇÃO COMPLETA: Remove caracteres de controle (\n, \r, \t) de strings do payload
    final String usuarioIdLimpo = _funcionarioSelecionado!.id.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
    final String fotoLimpa = _fotoBase64!.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
    final String dataHoraLimpa = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[\n\r\t]'), '').trim();

    // Montagem do payload padronizado
    final payload = {
      'usuarioId': usuarioIdLimpo,
      'latitude': latitude,
      'longitude': longitude,
      'fotoBase64': fotoLimpa,
      'dataHora': dataHoraLimpa
    };

    // 2) 🌐 TENTATIVA DE ENVIO ONLINE DIRETO
    try {
      debugPrint("🖥️ Tentando enviar ponto online para a API...");
      await ApiService.dio.post('/ponto/bater', data: payload);
      
      _mostrarDialogSucesso('Ponto registrado com sucesso online para ${_funcionarioSelecionado!.nome}!');
      _limparCampos();
    } catch (networkError) {
      // 🚨 SÓ GRAVA LOCALMENTE SE NÃO TIVER CONECTIVIDADE
      debugPrint("❌ Falha de conectividade detectada. Salvando registro na fila offline local.");
      
      await _pontosOfflineBox.add(payload); // Salva na caixa NoSQL do Hive
      
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
  void dispose() {
    _timerSincronizacao?.cancel();
    _cameraController?.dispose();
    _pesquisaController.dispose();
    super.dispose();
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
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