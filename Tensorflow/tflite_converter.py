import os
import numpy as np

class TFLiteConverter:
    def __init__(self, model_path=None, model=None):
        """
        Inicializa o conversor TFLite
        
        Args:
            model_path: Caminho para o modelo salvo (.h5)
            model: Modelo TensorFlow/Keras diretamente
        """
        self.model_path = model_path
        self.model = model
        
        if model_path and os.path.exists(model_path):
            self.load_model(model_path)
        elif model is not None:
            self.model = model
        else:
            print("Aviso: Nenhum modelo fornecido")
    
    def load_model(self, model_path):
        """Carrega modelo do arquivo"""
        try:
            import tensorflow as tf
            self.model = tf.keras.models.load_model(model_path)
            print(f"Modelo carregado de: {model_path}")
            return True
        except Exception as e:
            print(f"Erro ao carregar modelo: {e}")
            return False
    
    def convert_to_tflite(self, quantization=True, representative_dataset=None, 
                         optimize_for_size=True):
        """
        Converte modelo para TensorFlow Lite
        
        Args:
            quantization: Se deve aplicar quantização
            representative_dataset: Dataset representativo para quantização int8
            optimize_for_size: Se deve otimizar para tamanho
        """
        if self.model is None:
            print("Erro: Nenhum modelo carregado")
            return None
        
        try:
            import tensorflow as tf
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        print("=== CONVERSÃO PARA TENSORFLOW LITE ===")
        
        # Criar conversor
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        
        if quantization:
            print("Aplicando quantização...")
            
            # Quantização básica (float16)
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            
            if representative_dataset is not None:
                print("Usando quantização int8 com dataset representativo...")
                
                # Quantização int8 com dataset representativo
                converter.representative_dataset = representative_dataset
                converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
                converter.inference_input_type = tf.uint8
                converter.inference_output_type = tf.uint8
            
            if optimize_for_size:
                # Otimizações adicionais para tamanho
                converter.optimizations = [tf.lite.Optimize.OPTIMIZE_FOR_SIZE]
        
        # Converter
        print("Convertendo modelo...")
        try:
            tflite_model = converter.convert()
            
            # Calcular tamanho do modelo
            model_size = len(tflite_model) / (1024 * 1024)  # MB
            print(f"Modelo TFLite criado com sucesso!")
            print(f"Tamanho: {model_size:.2f} MB")
            
            return tflite_model
            
        except Exception as e:
            print(f"Erro na conversão: {e}")
            return None
    
    def save_tflite_model(self, tflite_model, output_path="thai_id_model.tflite"):
        """
        Salva modelo TFLite em arquivo
        """
        if tflite_model is None:
            print("Erro: Modelo TFLite é None")
            return False
        
        try:
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            # Verificar tamanho do arquivo
            file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
            print(f"Modelo TFLite salvo em: {output_path}")
            print(f"Tamanho do arquivo: {file_size:.2f} MB")
            
            return True
            
        except Exception as e:
            print(f"Erro ao salvar: {e}")
            return False
    
    def create_representative_dataset(self, X_sample, batch_size=1):
        """
        Cria dataset representativo para quantização int8
        
        Args:
            X_sample: Amostra dos dados de treino (numpy array)
            batch_size: Tamanho do batch para cada sample
        """
        print(f"Criando dataset representativo com {len(X_sample)} amostras...")
        
        def representative_data_gen():
            for i in range(min(100, len(X_sample))):
                # Pegar uma amostra
                sample = X_sample[i:i+batch_size]
                
                # Garantir que está no formato correto
                if sample.dtype != np.float32:
                    sample = sample.astype(np.float32)
                
                # Normalizar se necessário
                if np.max(sample) > 1.0:
                    sample = sample / 255.0
                
                yield [sample]
        
        return representative_data_gen
    
    def test_tflite_model(self, tflite_model_path, test_images, test_labels=None):
        """
        Testa o modelo TFLite com imagens de teste
        """
        try:
            import tensorflow as tf
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        # Carregar modelo TFLite
        interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
        interpreter.allocate_tensors()
        
        # Obter detalhes de input e output
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("=== TESTE DO MODELO TFLITE ===")
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Input type: {input_details[0]['dtype']}")
        print(f"Output shape: {output_details[0]['shape']}")
        print(f"Output type: {output_details[0]['dtype']}")
        
        predictions = []
        
        # Testar com algumas imagens
        num_test = min(5, len(test_images))
        print(f"\nTestando com {num_test} imagens...")
        
        for i in range(num_test):
            # Preparar imagem
            image = test_images[i]
            if len(image.shape) == 3:
                image = np.expand_dims(image, axis=0)
            
            # Converter tipo se necessário
            if input_details[0]['dtype'] == np.uint8:
                image = (image * 255).astype(np.uint8)
            else:
                image = image.astype(np.float32)
            
            # Set input tensor
            interpreter.set_tensor(input_details[0]['index'], image)
            
            # Executar inferência
            interpreter.invoke()
            
            # Obter resultado
            output_data = interpreter.get_tensor(output_details[0]['index'])
            predicted_class = np.argmax(output_data[0])
            confidence = output_data[0][predicted_class]
            
            predictions.append({
                'predicted_class': predicted_class,
                'confidence': confidence,
                'probabilities': output_data[0]
            })
            
            print(f"Imagem {i+1}:")
            print(f"  Classe predita: {predicted_class}")
            print(f"  Confiança: {confidence:.4f}")
            
            if test_labels is not None:
                actual_class = test_labels[i]
                correct = "✓" if predicted_class == actual_class else "✗"
                print(f"  Classe real: {actual_class} {correct}")
        
        return predictions
    
    def compare_models(self, original_model, tflite_model_path, test_images):
        """
        Compara precisão entre modelo original e TFLite
        """
        if original_model is None:
            print("Modelo original não fornecido")
            return
        
        try:
            import tensorflow as tf
        except ImportError:
            print("TensorFlow não está instalado!")
            return
        
        print("=== COMPARAÇÃO DE MODELOS ===")
        
        # Predições do modelo original
        original_preds = original_model.predict(test_images[:5])
        original_classes = np.argmax(original_preds, axis=1)
        
        print("Modelo Original:")
        for i, (pred_class, confidence) in enumerate(zip(original_classes, np.max(original_preds, axis=1))):
            print(f"  Imagem {i+1}: Classe {pred_class}, Confiança: {confidence:.4f}")
        
        # Predições do modelo TFLite
        tflite_preds = self.test_tflite_model(tflite_model_path, test_images[:5])
        
        print("\nComparação:")
        for i in range(len(original_classes)):
            orig_class = original_classes[i]
            tflite_class = tflite_preds[i]['predicted_class']
            match = "✓" if orig_class == tflite_class else "✗"
            print(f"  Imagem {i+1}: Original={orig_class}, TFLite={tflite_class} {match}")
    
    def get_model_info(self, tflite_model_path):
        """
        Obtém informações sobre o modelo TFLite
        """
        try:
            import tensorflow as tf
        except ImportError:
            print("TensorFlow não está instalado!")
            return None
        
        interpreter = tf.lite.Interpreter(model_path=tflite_model_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        # Tamanho do arquivo
        file_size = os.path.getsize(tflite_model_path) / (1024 * 1024)  # MB
        
        info = {
            'file_size_mb': file_size,
            'input_shape': input_details[0]['shape'],
            'input_dtype': str(input_details[0]['dtype']),
            'output_shape': output_details[0]['shape'],
            'output_dtype': str(output_details[0]['dtype']),
            'num_tensors': len(interpreter.get_tensor_details())
        }
        
        print("=== INFORMAÇÕES DO MODELO TFLITE ===")
        print(f"Tamanho do arquivo: {info['file_size_mb']:.2f} MB")
        print(f"Input shape: {info['input_shape']}")
        print(f"Input type: {info['input_dtype']}")
        print(f"Output shape: {info['output_shape']}")
        print(f"Output type: {info['output_dtype']}")
        print(f"Número de tensors: {info['num_tensors']}")
        
        return info
