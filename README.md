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

```

## 🚀 Como Executar o Projeto Localmente (Ambiente de Desenvolvimento)

Pré-requisitos

Ter o Flutter SDK instalado na sua máquina (versão v3.x ou superior). Execute flutter doctor no terminal para validar o ambiente.

Um emulador Android/iOS configurado ou um dispositivo físico conectado via USB com a Depuração USB ativada (altamente recomendado para testar Câmera e GPS).

A API do Backend (Node.js + Prisma) em execução ou a URL do Render configurada no arquivo api_service.dart.

Passo a Passo

Clone este repositório no seu computador:

Bash
git clone <url-do-repositorio>
cd ponto-mobile
Baixe e sincronize todas as dependências do projeto listadas no pubspec.yaml:

Bash
flutter pub get
Execute o aplicativo em modo de desenvolvimento (Debug Mode):

Bash
flutter run
Se possuir mais de um dispositivo conectado, selecione o ID do dispositivo desejado utilizando flutter run -d <id_do_dispositivo>.

## 📦 Como Gerar Versões de Produção (Build Compilada)
Ao gerar pacotes para instalação direta em tablets ou lojas, é vital compilar em modo --release. Isso ativa o compilador AOT (Ahead-of-Time), remove ferramentas de depuração do kernel, minifica o código e otimiza drasticamente a velocidade de execução do aplicativo.

## 🤖 Compilação para Android
1. Gerar APK Único (Para instalação manual via pendrive/Rede no Tablet Totem)
Ideal para implantar diretamente em tablets físicos que ficam fixados na parede da empresa sem depender da Google Play Store:

Bash
flutter build apk --release
Onde encontrar o arquivo final: build/app/outputs/flutter-apk/app-release.apk

2. Gerar Android App Bundle (Para publicação oficial na Google Play Store)
Gera um pacote otimizado dividindo os recursos por arquitetura de processador. A loja enviará ao usuário apenas o pacote exato do hardware dele:

Bash
flutter build appbundle --release
Onde encontrar o arquivo final: build/app/outputs/bundle/release/app-release.aab

## ⚠️ Nota Importante sobre Permissões no Android:
Certifique-se de que o arquivo android/app/src/main/AndroidManifest.xml contenha as diretivas de hardware ativas:

<uses-permission android:name="android.permission.INTERNET" />

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<uses-permission android:name="android.permission.CAMERA" />

## 🍏 Compilação para iOS (Requer um computador Mac com macOS e Xcode instalado)
A arquitetura do iOS impõe regras estritas de provisionamento e sandbox de segurança de hardware.

1. Preparação das Permissões de Privacidade
Antes de iniciar a compilação, é obrigatório abrir o arquivo ios/Runner/Info.plist e certificar-se de que as chaves de justificativa de uso dos sensores de GPS e Câmera existam, caso contrário o sistema operacional irá encerrar o app imediatamente na execução:

XML
<key>NSCameraUsageDescription</key>
<string>Este aplicativo necessita de acesso à câmera frontal para capturar a foto de reconhecimento no momento da batida de ponto.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Este aplicativo necessita de acesso à sua localização geográfica para validar as coordenadas do local da batida de ponto.</string>
2. Executar a Compilação Física ou para TestFlight
Execute o comando abaixo no terminal do seu Mac para estruturar o ecossistema nativo do iOS:

Bash
flutter build ios --release
3. Assinatura e Envio via Xcode
Abra a pasta /ios do projeto utilizando o Xcode.

Vá em Runner > Signing & Capabilities.

Escolha a sua conta de desenvolvedor da Apple (Development Team).

Altere o dispositivo alvo para Any iOS Device (arm64).

No menu superior do Xcode, selecione Product > Archive.

Concluído o Archive, clique em Distribute App para enviá-lo ao TestFlight ou exportar o arquivo .ipa assinado para distribuição corporativa interna.