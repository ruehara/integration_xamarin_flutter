import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from data_loader import ThaiIDDataLoader
from preprocessor import DataPreprocessor
from model import ThaiIDModel

class ModelTrainer:
    def __init__(self, dataset_path="dataset/"):
        self.dataset_path = dataset_path
        self.model_builder = None
        self.model = None
        self.history = None
        self.classes = None
        
    def load_and_prepare_data(self, img_size=(224, 224), balance_strategy='none'):
        """
        Carrega e prepara os dados para treinamento
        """
        print("=== CARREGAMENTO E PREPARAÇÃO DOS DADOS ===")
        
        # 1. Carregar dados
        loader = ThaiIDDataLoader(self.dataset_path)
        self.classes = loader.get_class_names()
        num_classes = loader.get_num_classes()
        
        print(f"Dataset: {self.dataset_path}")
        print(f"Classes: {self.classes}")
        print(f"Número de classes: {num_classes}")
        
        # Carregar imagens e labels
        X, y = loader.load_data_for_classification(img_size=img_size)
        
        if len(X) == 0:
            raise ValueError("Nenhuma imagem foi carregada. Verifique o dataset.")
        
        print(f"Dados carregados: {len(X)} imagens")
        
        # 2. Preprocessar dados
        preprocessor = DataPreprocessor(augment=True)
        
        # Normalizar imagens
        X = preprocessor.normalize_images(X)
        
        # Balancear dataset se necessário
        if balance_strategy != 'none':
            X, y = preprocessor.balance_dataset(X, y, strategy=balance_strategy)
        
        # Criar splits
        (X_train, y_train), (X_val, y_val), (X_test, y_test) = preprocessor.create_data_splits(
            X, y, test_size=0.2, val_size=0.1
        )
        
        return {
            'train': (X_train, y_train),
            'val': (X_val, y_val),
            'test': (X_test, y_test),
            'num_classes': num_classes,
            'img_size': img_size
        }
    
    def create_model(self, model_type='mobilenetv2', num_classes=3, input_shape=(224, 224, 3)):
        """
        Cria o modelo especificado
        """
        print(f"=== CRIAÇÃO DO MODELO: {model_type.upper()} ===")
        
        self.model_builder = ThaiIDModel(num_classes=num_classes, input_shape=input_shape)
        
        if model_type == 'mobilenetv2':
            self.model = self.model_builder.create_mobilenetv2_model()
        elif model_type == 'custom_cnn':
            self.model = self.model_builder.create_custom_cnn()
        elif model_type == 'lightweight':
            self.model = self.model_builder.create_lightweight_model()
        else:
            raise ValueError(f"Tipo de modelo não suportado: {model_type}")
        
        if self.model is None:
            raise RuntimeError("Falha ao criar o modelo. Verifique se o TensorFlow está instalado.")
        
        # Compilar modelo
        success = self.model_builder.compile_model(learning_rate=0.001)
        if not success:
            raise RuntimeError("Falha ao compilar o modelo")
        
        # Mostrar resumo
        print("\nResumo do modelo:")
        print(self.model_builder.get_model_summary())
        
        return self.model
    
    def train(self, data, epochs=50, batch_size=32, save_best=True):
        """
        Treina o modelo
        """
        if self.model is None:
            raise ValueError("Modelo não foi criado. Chame create_model() primeiro.")
        
        try:
            import tensorflow as tf
        except ImportError:
            raise ImportError("TensorFlow não está instalado!")
        
        print("=== INÍCIO DO TREINAMENTO ===")
        
        X_train, y_train = data['train']
        X_val, y_val = data['val']
        X_test, y_test = data['test']
        num_classes = data['num_classes']
        
        # Criar geradores de dados
        preprocessor = DataPreprocessor(augment=True)
        train_gen, val_gen, (y_train_cat, y_val_cat) = preprocessor.create_data_generators(
            X_train, y_train, X_val, y_val, batch_size=batch_size, num_classes=num_classes
        )
        
        # Calcular steps por época
        steps_per_epoch = len(X_train) // batch_size
        validation_steps = len(X_val) // batch_size if X_val is not None else None
        
        print(f"Steps por época: {steps_per_epoch}")
        if validation_steps:
            print(f"Validation steps: {validation_steps}")
        
        # Callbacks
        callbacks = []
        
        # Early Stopping
        early_stopping = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss' if X_val is not None else 'loss',
            patience=10,
            restore_best_weights=True,
            verbose=1
        )
        callbacks.append(early_stopping)
        
        # Reduce Learning Rate
        reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss' if X_val is not None else 'loss',
            factor=0.2,
            patience=5,
            min_lr=1e-7,
            verbose=1
        )
        callbacks.append(reduce_lr)
        
        # Model Checkpoint
        if save_best:
            checkpoint = tf.keras.callbacks.ModelCheckpoint(
                'best_model.h5',
                save_best_only=True,
                monitor='val_accuracy' if X_val is not None else 'accuracy',
                mode='max',
                verbose=1
            )
            callbacks.append(checkpoint)
        
        # Treinamento
        print(f"Iniciando treinamento por {epochs} épocas...")
        
        if val_gen is not None:
            self.history = self.model.fit(
                train_gen,
                epochs=epochs,
                steps_per_epoch=steps_per_epoch,
                validation_data=val_gen,
                validation_steps=validation_steps,
                callbacks=callbacks,
                verbose=1
            )
        else:
            self.history = self.model.fit(
                train_gen,
                epochs=epochs,
                steps_per_epoch=steps_per_epoch,
                callbacks=callbacks,
                verbose=1
            )
        
        # Avaliação final no conjunto de teste
        print("\n=== AVALIAÇÃO FINAL ===")
        y_test_cat = tf.keras.utils.to_categorical(y_test, num_classes)
        test_loss, test_acc = self.model.evaluate(X_test, y_test_cat, verbose=0)
        
        print(f"Acurácia no conjunto de teste: {test_acc:.4f}")
        print(f"Loss no conjunto de teste: {test_loss:.4f}")
        
        return self.history
    
    def fine_tune(self, data, epochs=10, learning_rate=0.0001):
        """
        Executa fine-tuning do modelo
        """
        if self.model is None:
            raise ValueError("Modelo não foi treinado ainda!")
        
        try:
            import tensorflow as tf
        except ImportError:
            raise ImportError("TensorFlow não está instalado!")
        
        print("=== FINE-TUNING ===")
        
        # Habilitar fine-tuning
        success = self.model_builder.enable_fine_tuning(layers_to_unfreeze=20)
        if not success:
            print("Fine-tuning não disponível para este modelo")
            return None
        
        # Recompilar com learning rate menor
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )
        
        X_train, y_train = data['train']
        X_val, y_val = data['val']
        num_classes = data['num_classes']
        
        # Preparar dados
        preprocessor = DataPreprocessor(augment=False)  # Menos augmentation no fine-tuning
        train_gen, val_gen, _ = preprocessor.create_data_generators(
            X_train, y_train, X_val, y_val, batch_size=16, num_classes=num_classes
        )
        
        # Callbacks para fine-tuning
        callbacks = [
            tf.keras.callbacks.EarlyStopping(
                monitor='val_loss' if X_val is not None else 'loss',
                patience=5,
                restore_best_weights=True
            ),
            tf.keras.callbacks.ModelCheckpoint(
                'fine_tuned_model.h5',
                save_best_only=True,
                monitor='val_accuracy' if X_val is not None else 'accuracy'
            )
        ]
        
        # Fine-tuning
        print(f"Iniciando fine-tuning por {epochs} épocas...")
        fine_tune_history = self.model.fit(
            train_gen,
            epochs=epochs,
            validation_data=val_gen if val_gen else None,
            callbacks=callbacks,
            verbose=1
        )
        
        return fine_tune_history
    
    def plot_training_history(self, save_path=None):
        """
        Plota gráficos do histórico de treinamento
        """
        if self.history is None:
            print("Nenhum histórico de treinamento disponível")
            return
        
        try:
            import matplotlib.pyplot as plt
        except ImportError:
            print("Matplotlib não está disponível para plotar gráficos")
            return
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))
        
        # Acurácia
        ax1.plot(self.history.history['accuracy'], label='Treino')
        if 'val_accuracy' in self.history.history:
            ax1.plot(self.history.history['val_accuracy'], label='Validação')
        ax1.set_title('Acurácia do Modelo')
        ax1.set_xlabel('Época')
        ax1.set_ylabel('Acurácia')
        ax1.legend()
        ax1.grid(True)
        
        # Loss
        ax2.plot(self.history.history['loss'], label='Treino')
        if 'val_loss' in self.history.history:
            ax2.plot(self.history.history['val_loss'], label='Validação')
        ax2.set_title('Loss do Modelo')
        ax2.set_xlabel('Época')
        ax2.set_ylabel('Loss')
        ax2.legend()
        ax2.grid(True)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Gráfico salvo em: {save_path}")
        
        plt.show()
    
    def train_extended(self, data, epochs=100, batch_size=8, learning_rate=0.0005, 
                      patience=15, save_best=True):
        """
        Treinamento estendido com monitoramento avançado
        """
        if self.model is None:
            raise ValueError("Modelo não foi criado. Chame create_model() primeiro.")
        
        try:
            import tensorflow as tf
        except ImportError:
            raise ImportError("TensorFlow não está instalado!")
        
        print("=== TREINAMENTO ESTENDIDO ===")
        print(f"Épocas: {epochs}")
        print(f"Batch size: {batch_size}")
        print(f"Learning rate: {learning_rate}")
        print(f"Paciência: {patience}")
        
        X_train, y_train = data['train']
        X_val, y_val = data['val']
        X_test, y_test = data['test']
        num_classes = data['num_classes']
        
        # Recompilar com learning rate personalizado
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )
        
        # Criar geradores de dados
        preprocessor = DataPreprocessor(augment=True)
        train_gen, val_gen, _ = preprocessor.create_data_generators(
            X_train, y_train, X_val, y_val, batch_size=batch_size, num_classes=num_classes
        )
        
        # Callbacks avançados
        callbacks = self._create_advanced_callbacks(patience, save_best, learning_rate)
        
        # Treinamento
        steps_per_epoch = max(1, len(X_train) // batch_size)
        validation_steps = max(1, len(X_val) // batch_size) if X_val is not None else None
        
        print(f"Steps por época: {steps_per_epoch}")
        if validation_steps:
            print(f"Validation steps: {validation_steps}")
        
        self.history = self.model.fit(
            train_gen,
            epochs=epochs,
            steps_per_epoch=steps_per_epoch,
            validation_data=val_gen,
            validation_steps=validation_steps,
            callbacks=callbacks,
            verbose=1
        )
        
        # Avaliação final detalhada
        self._evaluate_final_performance(data)
        
        return self.history
    
    def _create_advanced_callbacks(self, patience, save_best, learning_rate):
        """Cria callbacks avançados para treinamento"""
        try:
            import tensorflow as tf
        except ImportError:
            return []
        
        callbacks = []
        
        # Early Stopping com paciência maior
        early_stopping = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=patience,
            restore_best_weights=True,
            verbose=1,
            min_delta=0.001
        )
        callbacks.append(early_stopping)
        
        # Reduce Learning Rate com schedule mais agressivo
        reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=patience // 3,
            min_lr=learning_rate / 1000,
            verbose=1,
            cooldown=2
        )
        callbacks.append(reduce_lr)
        
        # Model Checkpoint para melhor modelo
        if save_best:
            checkpoint = tf.keras.callbacks.ModelCheckpoint(
                'best_model_extended.h5',
                save_best_only=True,
                monitor='val_accuracy',
                mode='max',
                verbose=1,
                save_weights_only=False
            )
            callbacks.append(checkpoint)
        
        # Learning Rate Scheduler customizado
        def lr_schedule(epoch, lr):
            if epoch > 60:
                return lr * 0.95
            elif epoch > 30:
                return lr * 0.98
            return lr
        
        lr_scheduler = tf.keras.callbacks.LearningRateScheduler(lr_schedule, verbose=0)
        callbacks.append(lr_scheduler)
        
        return callbacks
    
    def fine_tune_extended(self, data, epochs=30, learning_rate=0.00005):
        """Fine-tuning estendido com mais épocas"""
        if self.model is None:
            raise ValueError("Modelo não foi treinado ainda!")
        
        try:
            import tensorflow as tf
        except ImportError:
            raise ImportError("TensorFlow não está instalado!")
        
        print("=== FINE-TUNING ESTENDIDO ===")
        
        # Habilitar fine-tuning
        success = self.model_builder.enable_fine_tuning(layers_to_unfreeze=30)
        if not success:
            print("Fine-tuning não disponível para este modelo")
            return None
        
        # Recompilar com learning rate muito baixo
        self.model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )
        
        X_train, y_train = data['train']
        X_val, y_val = data['val']
        num_classes = data['num_classes']
        
        # Dados sem augmentation para fine-tuning
        preprocessor = DataPreprocessor(augment=False)
        train_gen, val_gen, _ = preprocessor.create_data_generators(
            X_train, y_train, X_val, y_val, batch_size=4, num_classes=num_classes
        )
        
        # Callbacks para fine-tuning
        callbacks = [
            tf.keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=10,
                restore_best_weights=True,
                min_delta=0.0001
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=learning_rate / 100
            ),
            tf.keras.callbacks.ModelCheckpoint(
                'fine_tuned_model_extended.h5',
                save_best_only=True,
                monitor='val_accuracy'
            )
        ]
        
        print(f"Iniciando fine-tuning estendido por {epochs} épocas...")
        fine_tune_history = self.model.fit(
            train_gen,
            epochs=epochs,
            validation_data=val_gen,
            callbacks=callbacks,
            verbose=1
        )
        
        return fine_tune_history
    
    def evaluate_model_detailed(self, data):
        """Avaliação detalhada do modelo"""
        try:
            import tensorflow as tf
            from sklearn.metrics import classification_report, confusion_matrix
        except ImportError:
            print("Bibliotecas necessárias não estão disponíveis")
            return
        
        print("=== AVALIAÇÃO DETALHADA ===")
        
        X_test, y_test = data['test']
        num_classes = data['num_classes']
        
        # Converter labels para categorical
        y_test_cat = tf.keras.utils.to_categorical(y_test, num_classes)
        
        # Avaliação básica
        test_loss, test_acc = self.model.evaluate(X_test, y_test_cat, verbose=0)
        print(f"Acurácia no teste: {test_acc:.4f}")
        print(f"Loss no teste: {test_loss:.4f}")
        
        # Predições
        predictions = self.model.predict(X_test, verbose=0)
        predicted_classes = np.argmax(predictions, axis=1)
        
        # Relatório de classificação
        if self.classes and len(self.classes) > 0:
            print("\nRelatório de Classificação:")
            print(classification_report(y_test, predicted_classes, target_names=self.classes))
        
        # Matriz de confusão
        cm = confusion_matrix(y_test, predicted_classes)
        print(f"\nMatriz de Confusão:")
        print(cm)
        
        # Análise de confiança
        confidences = np.max(predictions, axis=1)
        print(f"\nEstatísticas de Confiança:")
        print(f"  Confiança média: {np.mean(confidences):.4f}")
        print(f"  Confiança mínima: {np.min(confidences):.4f}")
        print(f"  Confiança máxima: {np.max(confidences):.4f}")
        print(f"  Desvio padrão: {np.std(confidences):.4f}")
    
    def _evaluate_final_performance(self, data):
        """Avaliação final de performance"""
        X_test, y_test = data['test']
        num_classes = data['num_classes']
        
        try:
            import tensorflow as tf
        except ImportError:
            return
        
        y_test_cat = tf.keras.utils.to_categorical(y_test, num_classes)
        
        # Avaliação final
        final_metrics = self.model.evaluate(X_test, y_test_cat, verbose=0)
        
        print(f"\n=== PERFORMANCE FINAL ===")
        metric_names = self.model.metrics_names
        for name, value in zip(metric_names, final_metrics):
            print(f"{name}: {value:.4f}")
        
        # Predições para análise adicional
        predictions = self.model.predict(X_test, verbose=0)
        predicted_classes = np.argmax(predictions, axis=1)
        correct = np.sum(predicted_classes == y_test)
        
        print(f"Predições corretas: {correct}/{len(y_test)}")
        print(f"Acurácia calculada: {correct/len(y_test):.4f}")
    
    def plot_extended_history(self, save_path=None):
        """Plota gráficos estendidos do treinamento"""
        if self.history is None:
            print("Nenhum histórico de treinamento disponível")
            return
        
        try:
            import matplotlib.pyplot as plt
        except ImportError:
            print("Matplotlib não está disponível")
            return
        
        # Criar figura com múltiplos subplots
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        
        # Acurácia
        axes[0, 0].plot(self.history.history['accuracy'], label='Treino', linewidth=2)
        if 'val_accuracy' in self.history.history:
            axes[0, 0].plot(self.history.history['val_accuracy'], label='Validação', linewidth=2)
        axes[0, 0].set_title('Acurácia do Modelo', fontsize=14, fontweight='bold')
        axes[0, 0].set_xlabel('Época')
        axes[0, 0].set_ylabel('Acurácia')
        axes[0, 0].legend()
        axes[0, 0].grid(True, alpha=0.3)
        
        # Loss
        axes[0, 1].plot(self.history.history['loss'], label='Treino', linewidth=2)
        if 'val_loss' in self.history.history:
            axes[0, 1].plot(self.history.history['val_loss'], label='Validação', linewidth=2)
        axes[0, 1].set_title('Loss do Modelo', fontsize=14, fontweight='bold')
        axes[0, 1].set_xlabel('Época')
        axes[0, 1].set_ylabel('Loss')
        axes[0, 1].legend()
        axes[0, 1].grid(True, alpha=0.3)
        
        # Learning Rate (se disponível)
        if 'lr' in self.history.history:
            axes[1, 0].plot(self.history.history['lr'], linewidth=2, color='red')
            axes[1, 0].set_title('Learning Rate', fontsize=14, fontweight='bold')
            axes[1, 0].set_xlabel('Época')
            axes[1, 0].set_ylabel('Learning Rate')
            axes[1, 0].set_yscale('log')
            axes[1, 0].grid(True, alpha=0.3)
        else:
            axes[1, 0].text(0.5, 0.5, 'Learning Rate\nnão disponível', 
                           ha='center', va='center', transform=axes[1, 0].transAxes)
        
        # Gráfico de diferença entre treino e validação
        if 'val_accuracy' in self.history.history:
            diff = np.array(self.history.history['accuracy']) - np.array(self.history.history['val_accuracy'])
            axes[1, 1].plot(diff, linewidth=2, color='purple')
            axes[1, 1].axhline(y=0, color='black', linestyle='--', alpha=0.5)
            axes[1, 1].set_title('Diferença Treino-Validação', fontsize=14, fontweight='bold')
            axes[1, 1].set_xlabel('Época')
            axes[1, 1].set_ylabel('Diferença de Acurácia')
            axes[1, 1].grid(True, alpha=0.3)
        else:
            axes[1, 1].text(0.5, 0.5, 'Validação\nnão disponível', 
                           ha='center', va='center', transform=axes[1, 1].transAxes)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Gráfico estendido salvo em: {save_path}")
        
        plt.show()

    def save_model(self, filepath="thai_id_model.h5"):
        """
        Salva o modelo treinado
        """
        if self.model is None:
            print("Nenhum modelo para salvar")
            return False
        
        success = self.model_builder.save_model(filepath)
        return success
