# 🆔 Thai ID Religion Field Processor

Um módulo Flutter completo para capturar e processar identidades tailandesas, ocultando automaticamente as informações de religião conforme legislação tailandesa.

![Flutter](https://img.shields.io/badge/Flutter-^3.8.1-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/Platform-Android-brightgreen.svg)

## ✨ Características Principais

- 📸 **Captura Guiada**: Interface intuitiva com overlay para posicionamento correto
- 🔍 **OCR Inteligente**: Detecção automática do campo religião em tailandês e inglês  
- 🌀 **Processamento Local**: Blur gaussiano aplicado automaticamente
- 👆 **Seleção Manual**: Fallback para seleção manual quando necessário
- 🔒 **Privacidade Total**: Processamento 100% local, sem upload de dados

## 🚀 Início Rápido

### 1. Instalação
```yaml
dependencies:
  flutter_tesseract_ocr: ^0.4.29
  camera: ^0.10.5+5
  image: ^4.1.3
  path_provider: ^2.1.1
  permission_handler: ^11.0.1
```

### 2. Uso Básico
```dart
import 'package:flutter_module_2/screens/camera_capture_screen.dart';
import 'package:flutter_module_2/screens/image_processing_screen.dart';

// Iniciar captura
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CameraCaptureScreen(
      onPhotoTaken: (imagePath) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ImageProcessingScreen(
              imagePath: imagePath,
            ),
          ),
        );
      },
    ),
  ),
);
```

## 📱 Fluxo da Aplicação

```
🏠 Home → 📸 Captura → ⚡ Processamento → ✅ Resultado
```

### Detalhado:
1. **Tela Inicial**: Apresenta funcionalidades e inicia captura
2. **Captura Guiada**: Câmera com overlay para posicionamento do ID
3. **Processamento OCR**: Detecção automática do campo religião
4. **Aplicação de Blur**: Desfoque inteligente na área detectada
5. **Seleção Manual**: Interface para correção manual se necessário
6. **Resultado Final**: Preview e opções de salvar/refazer

## 🏗️ Arquitetura

```
lib/
├── 📄 main.dart                 # App principal
├── ⚙️ config/
│   └── app_config.dart          # Configurações
├── 📊 models/  
│   └── thai_id_field.dart       # Modelos de dados
├── 🔧 services/
│   ├── camera_service.dart      # Gerenciamento de câmera
│   └── image_processing_service.dart # OCR e processamento
└── 📱 screens/
    ├── camera_capture_screen.dart     # Tela de captura
    └── image_processing_screen.dart   # Tela de processamento
```

## 🔧 Configuração

### Permissões Android
Adicione ao `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### OCR Tesseract
O módulo usa Tesseract com:
- **Idiomas**: Tailandês (`tha`) + Inglês (`eng`)
- **PSM**: 6 (blocos uniformes de texto)
- **Otimização**: Preservação de espaços entre palavras

## 🎯 Casos de Uso

### ✅ Detecção Automática
```dart
// Campo "ศาสนา" detectado automaticamente
final fields = await ImageProcessingService.detectReligionField(imagePath);
if (fields.isNotEmpty) {
  final processedImage = await ImageProcessingService.blurRegion(
    imagePath, 
    fields.first.boundingBox
  );
}
```

### 👆 Seleção Manual  
```dart
// Usuário seleciona área manualmente
final customRect = Rect(left: 0.5, top: 0.3, right: 0.95, bottom: 0.4);
final processedImage = await ImageProcessingService.blurRegion(
  imagePath, 
  customRect
);
```

## 📊 Performance

| Métrica | Valor Típico |
|---------|--------------|
| ⏱️ Tempo OCR | 2-5 segundos |
| 🌀 Tempo Blur | < 1 segundo |
| 🎯 Precisão | 80-90% |
| 📱 Compatibilidade | Android 5.0+ |

## 🔒 Privacidade e Segurança

- ✅ **Processamento Local**: Todo OCR executado no dispositivo
- ✅ **Sem Upload**: Nenhuma imagem enviada para servidores
- ✅ **Temporário**: Arquivos em cache temporário
- ✅ **Conformidade**: Atende legislação tailandesa

## 🛠️ Desenvolvimento

### Executar o Projeto
```bash
flutter pub get
flutter run
```

### Testar
```bash
flutter test
```

### Build
```bash
flutter build apk
```

## 📚 Documentação Completa

Para documentação detalhada, veja [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja [LICENSE](LICENSE) para detalhes.

## 🆘 Suporte

Para questões e suporte:
- 📧 Email: [seu-email@exemplo.com]
- 🐛 Issues: [GitHub Issues]
- 📖 Docs: [Wiki do Projeto]

---

⚡ **Desenvolvido com Flutter para proteger a privacidade de dados religiosos** ⚡
