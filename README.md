# 📱 Ponto Mobile - Controle de Ponto Eletrônico

Este é o aplicativo móvel do sistema **Controle de Horas**, desenvolvido para permitir que colaboradores registrem suas batidas de ponto (com suporte a geolocalização e captura de fotos) e que administradores gerenciem jornadas e visualizem relatórios diretamente de dispositivos móveis.

---

## 🛠️ Tecnologias e Linguagem

* **Linguagem:** [Dart](https://dart.dev/) (versão 3.x)
* **Framework:** [Flutter](https://flutter.dev/) (versão 3.x)
* **Cliente HTTP:** [Dio](https://pub.dev/packages/dio) (para consumo da API REST)
* **Gerenciamento de Estado:** `StatefulWidget` / `setState` (reatividade nativa focada em performance e simplicidade)

---

## 📐 Arquitetura do Projeto

O projeto segue uma estrutura de pastas baseada em **Features/Camadas**, separando as responsabilidades de telas, componentes visuais e comunicação com o servidor:

```text
lib/
├── components/        # Widgets compartilhados e reaproveitáveis (ex: Sidebar, CustomInputs)
├── models/            # Classes de modelagem de dados (Usuario, Batida, Horario)
├── screens/           # Telas principais do aplicativo
│   ├── auth/          # Telas de Login e Recuperação de Senha
│   ├── tabs/          # Abas do Dashboard (HorariosTab, EspelhoTab, etc.)
│   └── admin_dashboard_screen.dart
├── services/          # Camada de comunicação com serviços externos
│   └── api_service.dart  # Configuração centralizada do Dio interceptor e BaseURL
└── main.dart          # Ponto de entrada do aplicativo (Configuração de rotas e tema global)