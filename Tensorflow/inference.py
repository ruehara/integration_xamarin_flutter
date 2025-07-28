import os
import numpy as np
import cv2

class ThaiIDInference:
    def __init__(self, model_path="thai_id_model.tflite", classes_file="dataset/classes.txt"):
        """
        Inicializa o modelo de inferência
        
        Args:
            model_path: Caminho para o modelo TFLite
            classes_file: Arquivo com nomes das classes
        """
        self.model_path = model_path
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self.classes = []
        
        # Carregar classes
        self.load_classes(classes_file)
        
        # Inicializar modelo TFLite
        self.load_tflite_model()
    
    def load_classes(self, classes_file):
        """Carrega nomes das classes"""
        if os.path.exists(classes_file):
            with open(classes_file, 'r', encoding='utf-8') as f:
                self.classes = [line.strip() for line in f.readlines() if line.strip()]
            print(f"Classes carregadas: {self.classes}")
        else:
            print(f"Arquivo de classes não encontrado: {classes_file}")
            self.classes = [f"classe_{i}" for i in range(3)]  # Default
    
    def load_tflite_model(self):
        """Carrega modelo TFLite"""
        if not os.path.exists(self.model_path):
            print(f"Modelo não encontrado: {self.model_path}")
            return False
        
        try:
            import tensorflow as tf
            
            # Carregar modelo TFLite
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            
            # Obter detalhes de input e output
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            print(f"Modelo TFLite carregado: {self.model_path}")
            print(f"Input shape: {self.input_details[0]['shape']}")
            print(f"Output shape: {self.output_details[0]['shape']}")
            
            return True
            
        except ImportError:
            print("TensorFlow não está instalado!")
            return False
        except Exception as e:
            print(f"Erro ao carregar modelo: {e}")
            return False
    
    def preprocess_image(self, image_path_or_array, target_size=(224, 224)):
        """
        Preprocessa imagem para inferência
        
        Args:
            image_path_or_array: Caminho da imagem ou array numpy
            target_size: Tamanho alvo da imagem
        """
        # Carregar imagem
        if isinstance(image_path_or_array, str):
            image = cv2.imread(image_path_or_array)
            if image is None:
                raise ValueError(f"Não foi possível carregar a imagem: {image_path_or_array}")
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            image = image_path_or_array.copy()
        
        # Redimensionar
        image = cv2.resize(image, target_size)
        
        # Normalizar
        image = image.astype(np.float32) / 255.0
        
        # Adicionar dimensão do batch
        if len(image.shape) == 3:
            image = np.expand_dims(image, axis=0)
        
        # Converter tipo se necessário
        if self.input_details[0]['dtype'] == np.uint8:
            image = (image * 255).astype(np.uint8)
        
        return image
    
    def predict(self, image_path_or_array):
        """
        Faz predição em uma imagem
        
        Args:
            image_path_or_array: Caminho da imagem ou array numpy
            
        Returns:
            dict: Resultado da predição
        """
        if self.interpreter is None:
            raise RuntimeError("Modelo não foi carregado")
        
        # Preprocessar imagem
        processed_image = self.preprocess_image(image_path_or_array)
        
        # Set input tensor
        self.interpreter.set_tensor(self.input_details[0]['index'], processed_image)
        
        # Executar inferência
        self.interpreter.invoke()
        
        # Obter resultado
        output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
        
        # Processar resultado
        probabilities = output_data[0]
        predicted_class_id = np.argmax(probabilities)
        confidence = probabilities[predicted_class_id]
        
        # Nome da classe
        if predicted_class_id < len(self.classes):
            predicted_class_name = self.classes[predicted_class_id]
        else:
            predicted_class_name = f"unknown_{predicted_class_id}"
        
        return {
            'class_id': int(predicted_class_id),
            'class_name': predicted_class_name,
            'confidence': float(confidence),
            'probabilities': probabilities.tolist(),
            'all_classes': {
                self.classes[i] if i < len(self.classes) else f"class_{i}": float(probabilities[i])
                for i in range(len(probabilities))
            }
        }
    
    def predict_batch(self, image_list):
        """
        Faz predição em múltiplas imagens
        
        Args:
            image_list: Lista de caminhos ou arrays de imagens
            
        Returns:
            list: Lista de resultados
        """
        results = []
        
        for i, image in enumerate(image_list):
            try:
                result = self.predict(image)
                result['image_index'] = i
                results.append(result)
            except Exception as e:
                print(f"Erro na imagem {i}: {e}")
                results.append({
                    'image_index': i,
                    'error': str(e)
                })
        
        return results
    
    def test_with_dataset_extended(self, test_images_path="dataset/images", max_images=50):
        """
        Testa o modelo com mais imagens do dataset
        
        Args:
            test_images_path: Pasta com imagens de teste
            max_images: Número máximo de imagens para testar
        """
        if not os.path.exists(test_images_path):
            print(f"Pasta não encontrada: {test_images_path}")
            return
        
        # Listar imagens
        image_files = [f for f in os.listdir(test_images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        
        if not image_files:
            print("Nenhuma imagem encontrada na pasta")
            return
        
        # Testar mais imagens
        test_files = image_files[:max_images]
        
        print(f"=== TESTE EXTENSIVO COM {len(test_files)} IMAGENS ===")
        
        # Estatísticas
        results = []
        class_predictions = {cls: 0 for cls in self.classes}
        confidence_scores = []
        
        for i, image_file in enumerate(test_files):
            image_path = os.path.join(test_images_path, image_file)
            
            try:
                result = self.predict(image_path)
                results.append(result)
                
                class_name = result['class_name']
                confidence = result['confidence']
                
                class_predictions[class_name] += 1
                confidence_scores.append(confidence)
                
                # Log detalhado para primeiras 10 e últimas 5
                if i < 10 or i >= len(test_files) - 5:
                    print(f"\nImagem {i+1}: {image_file}")
                    print(f"  Classe predita: {result['class_name']} (ID: {result['class_id']})")
                    print(f"  Confiança: {result['confidence']:.4f}")
                    
                    # Mostrar top 3 probabilidades
                    probs = result['all_classes']
                    sorted_probs = sorted(probs.items(), key=lambda x: x[1], reverse=True)
                    print(f"  Top 3 probabilidades:")
                    for j, (cls, prob) in enumerate(sorted_probs[:3]):
                        print(f"    {j+1}. {cls}: {prob:.4f}")
                elif i == 10:
                    print(f"\n... processando {len(test_files) - 15} imagens restantes ...")
                    
            except Exception as e:
                print(f"\nErro na imagem {image_file}: {e}")
        
        # Estatísticas finais
        print(f"\n=== ESTATÍSTICAS FINAIS ===")
        print(f"Total de imagens processadas: {len(results)}")
        
        if confidence_scores:
            print(f"Confiança média: {np.mean(confidence_scores):.4f}")
            print(f"Confiança mínima: {np.min(confidence_scores):.4f}")
            print(f"Confiança máxima: {np.max(confidence_scores):.4f}")
            print(f"Desvio padrão: {np.std(confidence_scores):.4f}")
        
        print(f"\nDistribuição de predições:")
        for class_name, count in class_predictions.items():
            percentage = (count / len(results)) * 100 if results else 0
            print(f"  {class_name}: {count} ({percentage:.1f}%)")
        
        return results
    
    def benchmark_inference_speed(self, num_iterations=100):
        """
        Testa a velocidade de inferência do modelo
        """
        import time
        
        # Usar primeira imagem do dataset como teste
        test_image_path = "dataset/images"
        if os.path.exists(test_image_path):
            image_files = [f for f in os.listdir(test_image_path) 
                          if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
            if image_files:
                test_image = os.path.join(test_image_path, image_files[0])
            else:
                print("Nenhuma imagem encontrada para teste de velocidade")
                return
        else:
            print("Pasta de imagens não encontrada")
            return
        
        print(f"=== BENCHMARK DE VELOCIDADE ===")
        print(f"Testando com {num_iterations} iterações...")
        
        # Warm-up
        for _ in range(10):
            self.predict(test_image)
        
        # Benchmark real
        times = []
        for i in range(num_iterations):
            start_time = time.time()
            result = self.predict(test_image)
            end_time = time.time()
            
            inference_time = (end_time - start_time) * 1000  # Converter para ms
            times.append(inference_time)
            
            if i % 20 == 0:
                print(f"  Iteração {i+1}/{num_iterations}: {inference_time:.2f}ms")
        
        # Estatísticas
        avg_time = np.mean(times)
        min_time = np.min(times)
        max_time = np.max(times)
        std_time = np.std(times)
        
        print(f"\n=== RESULTADOS DO BENCHMARK ===")
        print(f"Tempo médio: {avg_time:.2f}ms")
        print(f"Tempo mínimo: {min_time:.2f}ms")
        print(f"Tempo máximo: {max_time:.2f}ms")
        print(f"Desvio padrão: {std_time:.2f}ms")
        print(f"FPS estimado: {1000/avg_time:.1f}")
        
        # Análise de percentis
        percentiles = [50, 90, 95, 99]
        print(f"\nPercentis:")
        for p in percentiles:
            time_p = np.percentile(times, p)
            print(f"  P{p}: {time_p:.2f}ms")
        
        return {
            'avg_time_ms': avg_time,
            'min_time_ms': min_time,
            'max_time_ms': max_time,
            'std_time_ms': std_time,
            'fps': 1000/avg_time,
            'times': times
        }

    def test_with_dataset(self, test_images_path="dataset/images", max_images=10):
        """
        Testa o modelo com imagens do dataset
        
        Args:
            test_images_path: Pasta com imagens de teste
            max_images: Número máximo de imagens para testar
        """
        if not os.path.exists(test_images_path):
            print(f"Pasta não encontrada: {test_images_path}")
            return
        
        # Listar imagens
        image_files = [f for f in os.listdir(test_images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        
        if not image_files:
            print("Nenhuma imagem encontrada na pasta")
            return
        
        # Testar algumas imagens
        test_files = image_files[:max_images]
        
        print(f"=== TESTE COM {len(test_files)} IMAGENS ===")
        
        for i, image_file in enumerate(test_files):
            image_path = os.path.join(test_images_path, image_file)
            
            try:
                result = self.predict(image_path)
                
                print(f"\nImagem {i+1}: {image_file}")
                print(f"  Classe predita: {result['class_name']} (ID: {result['class_id']})")
                print(f"  Confiança: {result['confidence']:.4f}")
                print(f"  Todas as probabilidades:")
                for class_name, prob in result['all_classes'].items():
                    print(f"    {class_name}: {prob:.4f}")
                    
            except Exception as e:
                print(f"\nErro na imagem {image_file}: {e}")
    
    def get_model_info(self):
        """Retorna informações sobre o modelo"""
        if self.interpreter is None:
            return None
        
        info = {
            'model_path': self.model_path,
            'input_shape': self.input_details[0]['shape'].tolist(),
            'input_dtype': str(self.input_details[0]['dtype']),
            'output_shape': self.output_details[0]['shape'].tolist(),
            'output_dtype': str(self.output_details[0]['dtype']),
            'num_classes': len(self.classes),
            'classes': self.classes
        }
        
        return info

def main():
    """Exemplo de uso"""
    print("=== EXEMPLO DE INFERÊNCIA COM MODELO TFLITE ===")
    
    # Inicializar inferência
    inference = ThaiIDInference()
    
    # Mostrar informações do modelo
    info = inference.get_model_info()
    if info:
        print(f"\nInformações do modelo:")
        print(f"  Input shape: {info['input_shape']}")
        print(f"  Número de classes: {info['num_classes']}")
        print(f"  Classes: {info['classes']}")
    
    # Testar com imagens do dataset
    inference.test_with_dataset(max_images=5)
    
    # Exemplo de uso com imagem específica
    test_image = "dataset/images/9cc4d6cc-01.jpg"
    if os.path.exists(test_image):
        print(f"\n=== TESTE COM IMAGEM ESPECÍFICA ===")
        result = inference.predict(test_image)
        print(f"Resultado: {result}")

if __name__ == "__main__":
    main()
