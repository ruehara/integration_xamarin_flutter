# Modelo TensorFlow Lite para Reconhecimento de Identidades Tailandesas

Este projeto cria um modelo TensorFlow Lite otimizado para reconhecer diferentes tipos de documentos de identidade tailandeses em aplicações Android.

## 📁 Estrutura do Projeto

```
├── dataset/
│   ├── images/          # Imagens do dataset
│   ├── labels/          # Arquivos de annotation (formato YOLO)
│   ├── classes.txt      # Nome das classes
│   └── notes.json       # Metadados do dataset
├── dataset_analyzer.py  # Análise do dataset
├── data_loader.py       # Carregamento de dados
├── preprocessor.py      # Preprocessamento
├── model.py            # Definição dos modelos
├── trainer.py          # Treinamento
├── tflite_converter.py # Conversão para TFLite
├── inference.py        # Inferência com modelo TFLite
├── main.py            # Script principal
├── install_dependencies.py # Instalador de dependências
└── README.md          # Este arquivo
```

## 🚀 Instalação Rápida

### 1. Instalar Dependências

```bash
# Opção 1: Usar o script automático
python install_dependencies.py

# Opção 2: Instalar manualmente
pip install tensorflow>=2.10.0 opencv-python>=4.5.0 numpy>=1.21.0 matplotlib>=3.5.0 scikit-learn>=1.0.0 Pillow>=8.0.0
```

### 2. Executar Treinamento Completo

```bash
python main.py
```

Este comando irá:
- ✅ Analisar o dataset
- ✅ Preparar os dados
- ✅ Criar e treinar o modelo
- ✅ Fazer fine-tuning (se aplicável)
- ✅ Converter para TensorFlow Lite
- ✅ Testar o modelo final
- ✅ Gerar gráficos de treinamento

## 📊 Dataset

O projeto trabalha com um dataset que contém:
- **3 classes**: `card`, `national_id`, `religion`
- **Formato**: Imagens + annotations YOLO
- **Estrutura**:
  - `dataset/images/`: Imagens (.jpg, .png, .webp)
  - `dataset/labels/`: Arquivos de annotation (.txt)
  - `dataset/classes.txt`: Lista das classes
  - `dataset/notes.json`: Metadados

## 🔧 Uso Individual dos Módulos

### Analisar Dataset

```python
from dataset_analyzer import DatasetAnalyzer

analyzer = DatasetAnalyzer("dataset/")
classes = analyzer.analyze_dataset()
stats = analyzer.get_dataset_stats()
```

### Carregar Dados

```python
from data_loader import ThaiIDDataLoader

loader = ThaiIDDataLoader("dataset/")
X, y = loader.load_data_for_classification(img_size=(224, 224))
```

### Treinar Modelo

```python
from trainer import ModelTrainer

trainer = ModelTrainer("dataset/")
data = trainer.load_and_prepare_data()
model = trainer.create_model(model_type='mobilenetv2')
history = trainer.train(data, epochs=30)
```

### Converter para TFLite

```python
from tflite_converter import TFLiteConverter

converter = TFLiteConverter(model_path="thai_id_model.h5")
tflite_model = converter.convert_to_tflite(quantization=True)
converter.save_tflite_model(tflite_model, "thai_id_model.tflite")
```

### Fazer Inferência

```python
from inference import ThaiIDInference

inference = ThaiIDInference("thai_id_model.tflite")
result = inference.predict("path/to/image.jpg")
print(result)
```

## 🏗️ Tipos de Modelo Disponíveis

### 1. MobileNetV2 (Recomendado)
```python
model = trainer.create_model(model_type='mobilenetv2')
```
- ✅ Pré-treinado no ImageNet
- ✅ Otimizado para mobile
- ✅ Bom equilíbrio precisão/tamanho
- 📱 Tamanho: ~10-15 MB

### 2. CNN Personalizada
```python
model = trainer.create_model(model_type='custom_cnn')
```
- ✅ Arquitetura personalizada
- ✅ Controle total sobre o modelo
- 📱 Tamanho: ~5-10 MB

### 3. Modelo Ultra-Leve
```python
model = trainer.create_model(model_type='lightweight')
```
- ✅ Mínimo de parâmetros
- ✅ Ideal para dispositivos limitados
- 📱 Tamanho: ~2-5 MB

## ⚙️ Configurações

Edite o arquivo `main.py` para ajustar:

```python
config = {
    'model_type': 'mobilenetv2',     # Tipo do modelo
    'img_size': (224, 224),          # Tamanho da imagem
    'epochs': 30,                    # Número de épocas
    'batch_size': 16,                # Tamanho do batch
    'balance_strategy': 'none',      # Estratégia de balanceamento
    'fine_tune': True,               # Habilitar fine-tuning
    'fine_tune_epochs': 10           # Épocas de fine-tuning
}
```

## 📱 Integração Android

### 1. Adicionar Dependências (build.gradle)

```gradle
implementation 'org.tensorflow:tensorflow-lite:2.10.0'
implementation 'org.tensorflow:tensorflow-lite-support:0.4.2'
```

### 2. Exemplo de Uso (Kotlin)

```kotlin
class ThaiIDClassifier(private val context: Context) {
    private var interpreter: Interpreter? = null
    
    fun initialize() {
        val model = loadModelFile("thai_id_model.tflite")
        interpreter = Interpreter(model)
    }
    
    fun classify(bitmap: Bitmap): String {
        // Preprocessar imagem
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 224, 224, true)
        val inputArray = bitmapToFloatArray(resizedBitmap)
        
        // Executar inferência
        val outputArray = Array(1) { FloatArray(3) }
        interpreter?.run(inputArray, outputArray)
        
        // Retornar resultado
        val predictedClass = outputArray[0].indexOfMax()
        val classes = arrayOf("card", "national_id", "religion")
        
        return classes[predictedClass]
    }
}
```

## 📈 Resultados Esperados

### Métricas do Modelo
- **Acurácia**: 85-95% (dependendo do dataset)
- **Tamanho do modelo TFLite**: 2-15 MB
- **Tempo de inferência**: 10-50ms em dispositivos móveis
- **Classes suportadas**: 3 (card, national_id, religion)

### Arquivos Gerados
- `thai_id_model.h5`: Modelo Keras original
- `thai_id_model.tflite`: Modelo TensorFlow Lite otimizado
- `best_model.h5`: Melhor modelo durante o treinamento
- `training_history.png`: Gráficos de treinamento
- `requirements.txt`: Lista de dependências

## 🔍 Solução de Problemas

### Erro: TensorFlow não instalado
```bash
pip install tensorflow>=2.10.0
```

### Erro: OpenCV não encontrado
```bash
pip install opencv-python>=4.5.0
```

### Dataset muito pequeno
- Adicione mais imagens (mínimo 50 por classe)
- Use data augmentation mais agressivo
- Reduza o número de épocas

### Modelo muito grande
- Use `model_type='lightweight'`
- Aumente a quantização
- Reduza o tamanho da imagem de entrada

### Baixa acurácia
- Aumente o número de épocas
- Ajuste o learning rate
- Verifique a qualidade das annotations
- Use transfer learning (MobileNetV2)

## 🤝 Melhorias Futuras

- [ ] Detecção de objetos (YOLO/SSD)
- [ ] Reconhecimento de texto (OCR)
- [ ] Modelo ensemble
- [ ] Quantização mais agressiva
- [ ] Suporte a mais classes
- [ ] Interface gráfica para treinamento

## 📄 Licença

Este projeto é fornecido como exemplo educacional. Adapte conforme necessário para seu uso específico.

## 🆘 Suporte

Se encontrar problemas:

1. Verifique se todas as dependências estão instaladas
2. Confirme que o dataset está na estrutura correta
3. Execute `python install_dependencies.py` para verificar dependências
4. Verifique os logs de erro para problemas específicos

---

**Desenvolvido para reconhecimento de identidades tailandesas** 🇹🇭
