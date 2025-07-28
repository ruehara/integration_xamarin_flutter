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

def main():
    """Script principal para treinar e converter modelo"""
    
    print("=== CRIAÇÃO DE MODELO TENSORFLOW LITE PARA RECONHECIMENTO DE IDENTIDADES TAILANDESAS ===\n")
    
    # Verificar dependências
    if not check_dependencies():
        print("\nInstale as dependências necessárias antes de continuar.")
        return
    
    dataset_path = "dataset/"
    
    # Verificar se dataset existe
    if not os.path.exists(dataset_path):
        print(f"Erro: Dataset não encontrado em {dataset_path}")
        print("Certifique-se de que a pasta 'dataset' existe com as subpastas 'images' e 'labels'")
        return
    
    try:
        # 1. ANÁLISE DO DATASET
        print("\n" + "="*60)
        analyzer = DatasetAnalyzer(dataset_path)
        classes = analyzer.analyze_dataset()
        
        if classes is None:
            print("Erro na análise do dataset")
            return
        
        stats = analyzer.get_dataset_stats()
        
        if stats['num_images'] < 10:
            print(f"\nAviso: Poucas imagens no dataset ({stats['num_images']})")
            print("Para melhores resultados, use pelo menos 50 imagens por classe")
        
        # 2. CONFIGURAÇÃO DO TREINAMENTO
        print(f"\n{'='*60}")
        print("CONFIGURAÇÃO DO TREINAMENTO")
        
        # Configurações
        config = {
            'model_type': 'mobilenetv2',  # 'mobilenetv2', 'custom_cnn', 'lightweight'
            'img_size': (224, 224),
            'epochs': 30,  # Reduzido para dataset pequeno
            'batch_size': 16,  # Reduzido para dataset pequeno
            'balance_strategy': 'none',  # 'undersample', 'oversample', 'none'
            'fine_tune': True,
            'fine_tune_epochs': 10
        }
        
        print(f"Tipo de modelo: {config['model_type']}")
        print(f"Tamanho da imagem: {config['img_size']}")
        print(f"Épocas: {config['epochs']}")
        print(f"Batch size: {config['batch_size']}")
        print(f"Estratégia de balanceamento: {config['balance_strategy']}")
        
        # 3. PREPARAÇÃO DOS DADOS
        print(f"\n{'='*60}")
        trainer = ModelTrainer(dataset_path)
        data = trainer.load_and_prepare_data(
            img_size=config['img_size'],
            balance_strategy=config['balance_strategy']
        )
        
        # 4. CRIAÇÃO DO MODELO
        print(f"\n{'='*60}")
        model = trainer.create_model(
            model_type=config['model_type'],
            num_classes=data['num_classes'],
            input_shape=(*config['img_size'], 3)
        )
        
        # 5. TREINAMENTO
        print(f"\n{'='*60}")
        history = trainer.train(
            data=data,
            epochs=config['epochs'],
            batch_size=config['batch_size'],
            save_best=True
        )
        
        # 6. FINE-TUNING (se habilitado)
        if config['fine_tune'] and config['model_type'] == 'mobilenetv2':
            print(f"\n{'='*60}")
            fine_tune_history = trainer.fine_tune(
                data=data,
                epochs=config['fine_tune_epochs'],
                learning_rate=0.0001
            )
        
        # 7. PLOTAR GRÁFICOS DE TREINAMENTO
        print(f"\n{'='*60}")
        print("GRÁFICOS DE TREINAMENTO")
        try:
            trainer.plot_training_history(save_path="training_history.png")
        except:
            print("Não foi possível plotar os gráficos (matplotlib pode não estar disponível)")
        
        # 8. SALVAR MODELO KERAS
        print(f"\n{'='*60}")
        print("SALVANDO MODELO")
        
        model_path = "thai_id_model.h5"
        success = trainer.save_model(model_path)
        
        if not success:
            print("Erro ao salvar modelo Keras")
            return
        
        # 9. CONVERSÃO PARA TENSORFLOW LITE
        print(f"\n{'='*60}")
        print("CONVERSÃO PARA TENSORFLOW LITE")
        
        # Criar conversor
        converter = TFLiteConverter(model_path=model_path)
        
        # Preparar dataset representativo para quantização
        X_train, _ = data['train']
        X_sample = X_train[:50]  # Usar 50 amostras para quantização
        rep_dataset = converter.create_representative_dataset(X_sample)
        
        # Converter com quantização
        tflite_model = converter.convert_to_tflite(
            quantization=True,
            representative_dataset=rep_dataset,
            optimize_for_size=True
        )
        
        if tflite_model is None:
            print("Erro na conversão para TFLite")
            return
        
        # Salvar modelo TFLite
        tflite_path = "thai_id_model.tflite"
        success = converter.save_tflite_model(tflite_model, tflite_path)
        
        if not success:
            print("Erro ao salvar modelo TFLite")
            return
        
        # 10. TESTE DO MODELO TFLITE
        print(f"\n{'='*60}")
        print("TESTE DO MODELO TFLITE")
        
        X_test, y_test = data['test']
        converter.test_tflite_model(tflite_path, X_test, y_test)
        
        # 11. COMPARAÇÃO DE MODELOS
        print(f"\n{'='*60}")
        print("COMPARAÇÃO DE MODELOS")
        
        converter.compare_models(model, tflite_path, X_test)
        
        # 12. INFORMAÇÕES FINAIS
        print(f"\n{'='*60}")
        print("INFORMAÇÕES DO MODELO FINAL")
        
        converter.get_model_info(tflite_path)
        
        # 13. RESUMO FINAL
        print(f"\n{'='*60}")
        print("RESUMO FINAL")
        print(f"✓ Modelo treinado com {stats['num_images']} imagens")
        print(f"✓ {data['num_classes']} classes: {', '.join(classes)}")
        print(f"✓ Modelo Keras salvo em: {model_path}")
        print(f"✓ Modelo TFLite salvo em: {tflite_path}")
        print(f"✓ Gráficos salvos em: training_history.png")
        
        print(f"\n{'='*60}")
        print("PRÓXIMOS PASSOS")
        print("1. Teste o modelo TFLite com mais imagens")
        print("2. Integre o modelo no seu aplicativo Android")
        print("3. Para melhorar a precisão:")
        print("   - Adicione mais imagens ao dataset")
        print("   - Ajuste os hiperparâmetros")
        print("   - Experimente diferentes arquiteturas de modelo")
        
    except Exception as e:
        print(f"\nErro durante a execução: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
