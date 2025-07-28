import os
import numpy as np

class ThaiIDModel:
    def __init__(self, num_classes=3, input_shape=(224, 224, 3)):
        self.num_classes = num_classes
        self.input_shape = input_shape
        self.model = None
    
    def create_mobilenetv2_model(self, alpha=1.0):
        """
        Cria modelo baseado em MobileNetV2 (otimizado para mobile)
        
        Args:
            alpha: Controla a largura da rede (0.5, 0.75, 1.0, 1.25, 1.4)
        """
        try:
            import tensorflow as tf
            from tensorflow.keras import layers, models
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        print(f"=== CRIANDO MODELO MOBILENETV2 ===")
        print(f"Classes: {self.num_classes}")
        print(f"Input shape: {self.input_shape}")
        print(f"Alpha: {alpha}")
        
        # Base model pré-treinada
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=self.input_shape,
            include_top=False,
            weights='imagenet',
            alpha=alpha
        )
        
        # Congela as camadas iniciais para transfer learning
        base_model.trainable = False
        
        print(f"Base model criado com {len(base_model.layers)} camadas")
        print(f"Parâmetros treináveis: {base_model.count_params()}")
        
        # Adiciona camadas personalizadas
        self.model = models.Sequential([
            base_model,
            layers.GlobalAveragePooling2D(),
            layers.Dropout(0.2),
            layers.Dense(128, activation='relu', name='feature_layer'),
            layers.Dropout(0.2),
            layers.Dense(self.num_classes, activation='softmax', name='predictions')
        ])
        
        print("Camadas personalizadas adicionadas")
        print(f"Total de parâmetros: {self.model.count_params()}")
        
        return self.model
    
    def create_custom_cnn(self):
        """
        Cria CNN personalizada e leve para dispositivos móveis
        """
        try:
            import tensorflow as tf
            from tensorflow.keras import layers, models
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        print("=== CRIANDO MODELO CNN PERSONALIZADO ===")
        
        self.model = models.Sequential([
            # Primeira camada conv
            layers.Conv2D(32, (3, 3), activation='relu', input_shape=self.input_shape),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Segunda camada conv
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Terceira camada conv
            layers.Conv2D(128, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Quarta camada conv (opcional para mais profundidade)
            layers.Conv2D(128, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Flatten e Dense layers
            layers.Flatten(),
            layers.Dropout(0.5),
            layers.Dense(512, activation='relu'),
            layers.Dropout(0.3),
            layers.Dense(self.num_classes, activation='softmax')
        ])
        
        print(f"Modelo CNN criado com {len(self.model.layers)} camadas")
        print(f"Parâmetros: {self.model.count_params()}")
        
        return self.model
    
    def create_lightweight_model(self):
        """
        Cria um modelo ultra-leve para dispositivos com recursos limitados
        """
        try:
            import tensorflow as tf
            from tensorflow.keras import layers, models
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        print("=== CRIANDO MODELO ULTRA-LEVE ===")
        
        self.model = models.Sequential([
            # Primeira camada com filtros pequenos
            layers.Conv2D(16, (3, 3), activation='relu', input_shape=self.input_shape),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Segunda camada
            layers.Conv2D(32, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Terceira camada
            layers.Conv2D(64, (3, 3), activation='relu'),
            layers.BatchNormalization(),
            layers.MaxPooling2D((2, 2)),
            
            # Global Average Pooling para reduzir parâmetros
            layers.GlobalAveragePooling2D(),
            layers.Dropout(0.3),
            layers.Dense(64, activation='relu'),
            layers.Dropout(0.2),
            layers.Dense(self.num_classes, activation='softmax')
        ])
        
        print(f"Modelo ultra-leve criado com {self.model.count_params()} parâmetros")
        
        return self.model
    
    def compile_model(self, learning_rate=0.001, metrics=['accuracy']):
        """
        Compila o modelo com otimizador e loss function
        """
        if self.model is None:
            print("Erro: Modelo não foi criado ainda!")
            return False
        
        try:
            import tensorflow as tf
        except ImportError:
            print("TensorFlow não está instalado!")
            return False
        
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
            loss='categorical_crossentropy',
            metrics=metrics
        )
        
        print(f"Modelo compilado com learning_rate={learning_rate}")
        return True
    
    def get_model_summary(self):
        """Retorna resumo do modelo"""
        if self.model is None:
            return "Modelo não foi criado ainda!"
        
        try:
            # Capturar o summary em string
            import io
            import sys
            
            old_stdout = sys.stdout
            sys.stdout = buffer = io.StringIO()
            
            self.model.summary()
            
            sys.stdout = old_stdout
            summary_string = buffer.getvalue()
            
            return summary_string
        except:
            return "Erro ao gerar summary do modelo"
    
    def save_model(self, filepath):
        """Salva o modelo treinado"""
        if self.model is None:
            print("Erro: Modelo não foi criado ainda!")
            return False
        
        try:
            self.model.save(filepath)
            print(f"Modelo salvo em: {filepath}")
            return True
        except Exception as e:
            print(f"Erro ao salvar modelo: {e}")
            return False
    
    def load_model(self, filepath):
        """Carrega um modelo salvo"""
        try:
            import tensorflow as tf
            self.model = tf.keras.models.load_model(filepath)
            print(f"Modelo carregado de: {filepath}")
            return True
        except Exception as e:
            print(f"Erro ao carregar modelo: {e}")
            return False
    
    def enable_fine_tuning(self, layers_to_unfreeze=20):
        """
        Habilita fine-tuning descongelando camadas do modelo base
        """
        if self.model is None:
            print("Erro: Modelo não foi criado ainda!")
            return False
        
        try:
            import tensorflow as tf
            
            # Verificar se o modelo tem uma base pré-treinada
            if len(self.model.layers) > 0 and hasattr(self.model.layers[0], 'layers'):
                base_model = self.model.layers[0]
                base_model.trainable = True
                
                # Congelar camadas iniciais, treinar apenas as finais
                for layer in base_model.layers[:-layers_to_unfreeze]:
                    layer.trainable = False
                
                print(f"Fine-tuning habilitado. Últimas {layers_to_unfreeze} camadas descongeladas.")
                return True
            else:
                print("Modelo não possui base pré-treinada para fine-tuning")
                return False
                
        except Exception as e:
            print(f"Erro ao habilitar fine-tuning: {e}")
            return False
