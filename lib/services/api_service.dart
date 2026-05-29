import 'package:dio/dio.dart';

class ApiService {
  // 1. Instância global do Dio
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://ponto-api-1iz6.onrender.com/api',
      //baseUrl: 'http://localhost:3003/api',
      connectTimeout: const Duration(seconds: 60), // Lembra dos 60s do Render? Mantenha!
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // 2. Variável global na memória para guardar o Token recebido no login
  static String? token;

  // 3. Construtor estático ou método para ativar os interceptors
  static void inicializar() {
    dio.interceptors.clear(); // Limpa duplicados por segurança
    
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 🪛 SE HOUVER TOKEN SALVO, INJETA AUTOMATICAMENTE NO HEADER
          if (token != null && token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options); // Segue viagem com a requisição
        },
        onError: (DioException e, handler) {
          // Aqui você pode tratar erros globais (como token expirado) no futuro
          return handler.next(e);
        },
      ),
    );
  }
}