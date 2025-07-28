import os
import sys
import numpy as np
from dataset_analyzer import DatasetAnalyzer
from trainer import ModelTrainer
from tflite_converter import TFLiteConverter

def check_dependencies():
    """Verifica se as dependências estão instaladas"""
    print("=== VERIFICAÇÃO DE DEPENDÊNCIAS ===")
    
    dependencies = {
        'tensorflow': 'tensorflow>=2.10.0',
        'opencv-python': 'opencv-python>=4.5.0',
        'numpy': 'numpy>=1.21.0',
        'matplotlib': 'matplotlib>=3.5.0',
        'scikit-learn': 'scikit-learn>=1.0.0'
    }
    
    missing = []
    
    for package, version_info in dependencies.items():
        try:
            if package == 'opencv-python':
                import cv2
                print(f"✓ OpenCV: {cv2.__version__}")
            elif package == 'tensorflow':
                import tensorflow as tf
                print(f"✓ TensorFlow: {tf.__version__}")
            elif package == 'numpy':
                import numpy as np
                print(f"✓ NumPy: {np.__version__}")
            elif package == 'matplotlib':
                import matplotlib
                print(f"✓ Matplotlib: {matplotlib.__version__}")
            elif package == 'scikit-learn':
                import sklearn
                print(f"✓ Scikit-learn: {sklearn.__version__}")
        except ImportError:
            print(f"✗ {package} não encontrado")
            missing.append(version_info)
    
    if missing:
        print(f"\nDependências faltando:")
        for dep in missing:
            print(f"  pip install {dep}")
        return False
    
    print("Todas as dependências estão instaladas!")
    return True

def test_extensive_model(tflite_path, data, classes):
    """Teste extensivo do modelo TFLite"""
    from inference import ThaiIDInference
    
    X_test, y_test = data['test']
    
    # Criar instância de inferência
    inference = ThaiIDInference(model_path=tflite_path, classes_file="dataset/classes.txt")
    
    print(f"Testando modelo com {len(X_test)} imagens...")
    
    correct_predictions = 0
    predictions_by_class = {i: {'correct': 0, 'total': 0} for i in range(len(classes))}
    confidence_scores = []
    
    for i, (image, true_label) in enumerate(zip(X_test, y_test)):
        try:
            # Fazer predição
            result = inference.predict(image)
            
            predicted_class = result['class_id']
            confidence = result['confidence']
            
            # Estatísticas
            confidence_scores.append(confidence)
            predictions_by_class[true_label]['total'] += 1
            
            if predicted_class == true_label:
                correct_predictions += 1
                predictions_by_class[true_label]['correct'] += 1
            
            # Log detalhado para primeiras 20 imagens
            if i < 20:
                status = "✓" if predicted_class == true_label else "✗"
                print(f"  Imagem {i+1:2d}: Real={classes[true_label]:12} | "
                      f"Pred={classes[predicted_class]:12} | "
                      f"Conf={confidence:.3f} {status}")
        
        except Exception as e:
            print(f"  Erro na imagem {i+1}: {e}")
    
    # Resultados finais
    overall_accuracy = correct_predictions / len(X_test)
    avg_confidence = np.mean(confidence_scores)
    
    print(f"\n=== RESULTADOS DO TESTE EXTENSIVO ===")
    print(f"Acurácia geral: {overall_accuracy:.4f} ({correct_predictions}/{len(X_test)})")
    print(f"Confiança média: {avg_confidence:.4f}")
    
    print(f"\nDesempenho por classe:")
    for class_id, stats in predictions_by_class.items():
        if stats['total'] > 0:
            class_acc = stats['correct'] / stats['total']
            print(f"  {classes[class_id]:12}: {class_acc:.3f} ({stats['correct']}/{stats['total']})")

def main_extended_training():
    """Script principal para treinamento estendido com 100 épocas"""
    
    print("=== CRIAÇÃO DE MODELO TENSORFLOW LITE - TREINAMENTO ESTENDIDO ===\n")
    
    # Verificar dependências
    if not check_dependencies():
        print("\nInstale as dependências necessárias antes de continuar.")
        return
    
    dataset_path = "dataset/"
    
    # Verificar se dataset existe
    if not os.path.exists(dataset_path):
        print(f"Erro: Dataset não encontrado em {dataset_path}")
        return
    
    try:
        # 1. ANÁLISE DETALHADA DO DATASET
        print(f"\n{'='*60}")
        print("ANÁLISE DETALHADA DO DATASET")
        
        analyzer = DatasetAnalyzer(dataset_path)
        classes = analyzer.analyze_dataset()
        stats = analyzer.get_dataset_stats()
        
        if classes is None:
            print("Erro na análise do dataset")
            return
        
        print(f"Total de imagens: {stats['num_images']}")
        print(f"Classes encontradas: {len(classes)}")
        
        if stats['num_images'] < 30:
            print(f"\n⚠️  AVISO: Dataset pequeno ({stats['num_images']} imagens)")
            print("Para melhores resultados com 100 épocas, recomenda-se pelo menos 100 imagens por classe")
        
        # 2. CONFIGURAÇÃO ESTENDIDA
        print(f"\n{'='*60}")
        print("CONFIGURAÇÃO DE TREINAMENTO ESTENDIDO")
        
        config = {
            'model_type': 'mobilenetv2',     # Modelo robusto para treinamento longo
            'img_size': (224, 224),
            'epochs': 100,                   # Treinamento estendido
            'batch_size': 8,                 # Batch menor para melhor convergência
            'balance_strategy': 'oversample', # Balancear dados
            'fine_tune': True,
            'fine_tune_epochs': 30,          # Fine-tuning mais longo
            'learning_rate': 0.0005,         # Learning rate mais conservador
            'patience': 15,                  # Paciência maior para early stopping
        }
        
        print(f"Configuração:")
        for key, value in config.items():
            print(f"  {key}: {value}")
        
        # 3. PREPARAÇÃO DOS DADOS COM BALANCEAMENTO
        print(f"\n{'='*60}")
        print("PREPARAÇÃO DOS DADOS")
        
        trainer = ModelTrainer(dataset_path)
        data = trainer.load_and_prepare_data(
            img_size=config['img_size'],
            balance_strategy=config['balance_strategy']
        )
        
        # Estatísticas dos dados preparados
        X_train, y_train = data['train']
        X_val, y_val = data['val']
        X_test, y_test = data['test']
        
        print(f"Dados de treinamento: {len(X_train)} imagens")
        print(f"Dados de validação: {len(X_val)} imagens")
        print(f"Dados de teste: {len(X_test)} imagens")
        
        # 4. CRIAÇÃO DO MODELO OTIMIZADO
        print(f"\n{'='*60}")
        print("CRIAÇÃO DO MODELO")
        
        model = trainer.create_model(
            model_type=config['model_type'],
            num_classes=data['num_classes'],
            input_shape=(*config['img_size'], 3)
        )
        
        # 5. TREINAMENTO ESTENDIDO COM MONITORAMENTO
        print(f"\n{'='*60}")
        print("TREINAMENTO ESTENDIDO (100 ÉPOCAS)")
        
        history = trainer.train_extended(
            data=data,
            epochs=config['epochs'],
            batch_size=config['batch_size'],
            learning_rate=config['learning_rate'],
            patience=config['patience'],
            save_best=True
        )
        
        # 6. FINE-TUNING ESTENDIDO
        if config['fine_tune'] and config['model_type'] == 'mobilenetv2':
            print(f"\n{'='*60}")
            print("FINE-TUNING ESTENDIDO (30 ÉPOCAS)")
            
            fine_tune_history = trainer.fine_tune_extended(
                data=data,
                epochs=config['fine_tune_epochs'],
                learning_rate=config['learning_rate'] / 10
            )
        
        # 7. AVALIAÇÃO DETALHADA
        print(f"\n{'='*60}")
        print("AVALIAÇÃO DETALHADA DO MODELO")
        
        trainer.evaluate_model_detailed(data)
        
        # 8. PLOTAR GRÁFICOS DETALHADOS
        print(f"\n{'='*60}")
        print("GRÁFICOS DE TREINAMENTO")
        
        try:
            trainer.plot_extended_history(save_path="training_history_extended.png")
        except Exception as e:
            print(f"Erro ao plotar gráficos: {e}")
        
        # 9. SALVAR MODELO
        print(f"\n{'='*60}")
        print("SALVANDO MODELO")
        
        model_path = "thai_id_model_extended.h5"
        success = trainer.save_model(model_path)
        
        if not success:
            print("Erro ao salvar modelo")
            return
        
        # 10. CONVERSÃO PARA TFLITE COM OTIMIZAÇÕES
        print(f"\n{'='*60}")
        print("CONVERSÃO PARA TENSORFLOW LITE")
        
        converter = TFLiteConverter(model_path=model_path)
        
        # Dataset representativo maior para melhor quantização
        X_sample = X_train[:200] if len(X_train) >= 200 else X_train
        rep_dataset = converter.create_representative_dataset(X_sample)
        
        tflite_model = converter.convert_to_tflite(
            quantization=True,
            representative_dataset=rep_dataset,
            optimize_for_size=True
        )
        
        tflite_path = "thai_id_model_extended.tflite"
        converter.save_tflite_model(tflite_model, tflite_path)
        
        # 11. TESTE EXTENSIVO DO MODELO TFLITE
        print(f"\n{'='*60}")
        print("TESTE EXTENSIVO DO MODELO TFLITE")
        
        test_extensive_model(tflite_path, data, classes)
        
        # 12. COMPARAÇÃO DETALHADA
        print(f"\n{'='*60}")
        print("COMPARAÇÃO DETALHADA DOS MODELOS")
        
        converter.compare_models(model, tflite_path, X_test)
        
        # 13. INFORMAÇÕES FINAIS
        print(f"\n{'='*60}")
        print("INFORMAÇÕES DO MODELO FINAL")
        
        converter.get_model_info(tflite_path)
        
        print(f"\n{'='*60}")
        print("TREINAMENTO ESTENDIDO CONCLUÍDO!")
        print(f"✓ Modelo Keras: {model_path}")
        print(f"✓ Modelo TFLite: {tflite_path}")
        print(f"✓ Gráficos: training_history_extended.png")
        
        print(f"\n{'='*60}")
        print("RESUMO FINAL")
        print(f"✓ Modelo treinado com {stats['num_images']} imagens")
        print(f"✓ {data['num_classes']} classes: {', '.join(classes)}")
        print(f"✓ 100 épocas de treinamento + 30 épocas de fine-tuning")
        print(f"✓ Teste extensivo com todas as imagens do conjunto de teste")
        
        print(f"\n{'='*60}")
        print("PRÓXIMOS PASSOS")
        print("1. Teste o modelo TFLite com mais imagens")
        print("2. Integre o modelo no seu aplicativo Android")
        print("3. Para melhorar ainda mais a precisão:")
        print("   - Adicione mais imagens ao dataset")
        print("   - Balanceie melhor as classes")
        print("   - Experimente diferentes arquiteturas")
        
    except Exception as e:
        print(f"\nErro durante a execução: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main_extended_training()
