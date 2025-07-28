import numpy as np
from sklearn.model_selection import train_test_split
from collections import Counter

class DataPreprocessor:
    def __init__(self, augment=True):
        self.augment = augment
    
    def create_data_splits(self, X, y, test_size=0.2, val_size=0.1, random_state=42):
        """
        Cria splits de dados balanceados para treino, validação e teste
        """
        print("=== CRIANDO SPLITS DOS DADOS ===")
        
        # Verificar distribuição das classes
        unique, counts = np.unique(y, return_counts=True)
        print("Distribuição original das classes:")
        for class_id, count in zip(unique, counts):
            print(f"  Classe {class_id}: {count} amostras")
        
        # Primeiro split: treino+val vs teste
        X_temp, X_test, y_temp, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=y
        )
        
        # Segundo split: treino vs validação
        if val_size > 0:
            val_size_adjusted = val_size / (1 - test_size)
            X_train, X_val, y_train, y_val = train_test_split(
                X_temp, y_temp, test_size=val_size_adjusted, 
                random_state=random_state, stratify=y_temp
            )
        else:
            X_train, X_val, y_train, y_val = X_temp, None, y_temp, None
        
        print(f"\nSplits criados:")
        print(f"  Treino: {len(X_train)} amostras")
        if X_val is not None:
            print(f"  Validação: {len(X_val)} amostras")
        print(f"  Teste: {len(X_test)} amostras")
        
        # Verificar distribuição nos splits
        self._print_class_distribution("Treino", y_train)
        if y_val is not None:
            self._print_class_distribution("Validação", y_val)
        self._print_class_distribution("Teste", y_test)
        
        return (X_train, y_train), (X_val, y_val), (X_test, y_test)
    
    def _print_class_distribution(self, split_name, y):
        """Imprime distribuição de classes para um split"""
        unique, counts = np.unique(y, return_counts=True)
        print(f"\n{split_name} - Distribuição:")
        for class_id, count in zip(unique, counts):
            percentage = (count / len(y)) * 100
            print(f"  Classe {class_id}: {count} ({percentage:.1f}%)")
    
    def create_data_generators(self, X_train, y_train, X_val=None, y_val=None, 
                             batch_size=32, num_classes=3):
        """
        Cria geradores de dados com data augmentation usando tf.keras
        """
        try:
            import tensorflow as tf
            from tensorflow.keras.utils import to_categorical
            from tensorflow.keras.preprocessing.image import ImageDataGenerator
        except ImportError:
            print("TensorFlow não está instalado. Instalando...")
            return None
        
        print("=== CRIANDO GERADORES DE DADOS ===")
        
        # Converter labels para categorical
        y_train_cat = to_categorical(y_train, num_classes)
        y_val_cat = to_categorical(y_val, num_classes) if y_val is not None else None
        
        print(f"Labels convertidas para categorical: {y_train_cat.shape}")
        
        if self.augment:
            # Data Augmentation para treino
            train_datagen = ImageDataGenerator(
                rotation_range=20,
                width_shift_range=0.1,
                height_shift_range=0.1,
                horizontal_flip=True,
                zoom_range=0.1,
                brightness_range=[0.8, 1.2],
                fill_mode='nearest'
            )
            print("Data augmentation ativado para treino")
        else:
            train_datagen = ImageDataGenerator()
            print("Data augmentation desativado")
        
        # Gerador para validação (sem augmentation)
        val_datagen = ImageDataGenerator()
        
        # Criar geradores
        train_generator = train_datagen.flow(
            X_train, y_train_cat, batch_size=batch_size, shuffle=True
        )
        
        val_generator = None
        if X_val is not None and y_val is not None:
            val_generator = val_datagen.flow(
                X_val, y_val_cat, batch_size=batch_size, shuffle=False
            )
        
        print(f"Geradores criados com batch_size={batch_size}")
        
        return train_generator, val_generator, (y_train_cat, y_val_cat)
    
    def balance_dataset(self, X, y, strategy='undersample'):
        """
        Balanceia o dataset usando diferentes estratégias
        """
        print("=== BALANCEAMENTO DO DATASET ===")
        
        unique, counts = np.unique(y, return_counts=True)
        print("Distribuição antes do balanceamento:")
        for class_id, count in zip(unique, counts):
            print(f"  Classe {class_id}: {count} amostras")
        
        if strategy == 'undersample':
            # Undersample: reduzir para o tamanho da menor classe
            min_count = np.min(counts)
            print(f"\nUsando undersample para {min_count} amostras por classe")
            
            balanced_X = []
            balanced_y = []
            
            for class_id in unique:
                class_indices = np.where(y == class_id)[0]
                selected_indices = np.random.choice(class_indices, min_count, replace=False)
                
                balanced_X.extend(X[selected_indices])
                balanced_y.extend(y[selected_indices])
            
            X_balanced = np.array(balanced_X)
            y_balanced = np.array(balanced_y)
            
        elif strategy == 'oversample':
            # Oversample: aumentar para o tamanho da maior classe
            max_count = np.max(counts)
            print(f"\nUsando oversample para {max_count} amostras por classe")
            
            balanced_X = []
            balanced_y = []
            
            for class_id in unique:
                class_indices = np.where(y == class_id)[0]
                selected_indices = np.random.choice(class_indices, max_count, replace=True)
                
                balanced_X.extend(X[selected_indices])
                balanced_y.extend(y[selected_indices])
            
            X_balanced = np.array(balanced_X)
            y_balanced = np.array(balanced_y)
        
        else:
            # Manter original
            X_balanced, y_balanced = X, y
        
        # Embaralhar dados balanceados
        if strategy != 'none':
            shuffle_indices = np.random.permutation(len(X_balanced))
            X_balanced = X_balanced[shuffle_indices]
            y_balanced = y_balanced[shuffle_indices]
            
            print("Distribuição após balanceamento:")
            unique_bal, counts_bal = np.unique(y_balanced, return_counts=True)
            for class_id, count in zip(unique_bal, counts_bal):
                print(f"  Classe {class_id}: {count} amostras")
        
        return X_balanced, y_balanced
    
    def normalize_images(self, X):
        """Normaliza as imagens para o range [0, 1]"""
        if X.dtype != np.float32:
            X = X.astype(np.float32)
        
        if np.max(X) > 1.0:
            X = X / 255.0
        
        print(f"Imagens normalizadas: min={X.min():.3f}, max={X.max():.3f}")
        return X
