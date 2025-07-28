#!/usr/bin/env python3
"""
Script para converter o modelo fine_tuned_model_extended.h5 para TFLite
"""

import os
import numpy as np
from tflite_converter import TFLiteConverter
from data_loader import ThaiIDDataLoader

def load_sample_data():
    """Carrega uma amostra dos dados para dataset representativo"""
    print("Carregando dados de amostra...")
    
    try:
        data_loader = ThaiIDDataLoader("dataset/")
        X, y, classes = data_loader.load_data()
        
        if X is not None and len(X) > 0:
            # Normalizar se necessário
            if X.dtype != np.float32:
                X = X.astype(np.float32)
            if np.max(X) > 1.0:
                X = X / 255.0
            
            print(f"Dados carregados: {X.shape}")
            return X[:20], classes  # Usar apenas 20 amostras para dataset representativo
    except Exception as e:
        print(f"Erro ao carregar dados: {e}")
    
    return None, None

def convert_model():
    """Converte o modelo fine_tuned_model_extended.h5 para TFLite"""
    
    print("=" * 60)
    print("🔄 CONVERSÃO MODELO PARA TENSORFLOW LITE")
    print("=" * 60)
    
    # Caminho do modelo treinado
    model_path = "fine_tuned_model_extended.h5"
    output_path = "thai_id_model_extended.tflite"
    
    # Verificar se o modelo existe
    if not os.path.exists(model_path):
        print(f"❌ Modelo não encontrado: {model_path}")
        return False
    
    print(f"📁 Modelo de entrada: {model_path}")
    print(f"📁 Arquivo de saída: {output_path}")
    
    # Carregar dados de amostra para quantização
    X_sample, classes = load_sample_data()
    
    # Criar conversor
    converter = TFLiteConverter(model_path=model_path)
    
    if converter.model is None:
        print("❌ Erro ao carregar modelo")
        return False
    
    # Configurar dataset representativo se dados estão disponíveis
    representative_dataset = None
    if X_sample is not None:
        representative_dataset = converter.create_representative_dataset(X_sample)
        print("✅ Dataset representativo criado")
    
    # Converter modelo
    print("\n🔄 Iniciando conversão...")
    tflite_model = converter.convert_to_tflite(
        quantization=True,
        representative_dataset=representative_dataset,
        optimize_for_size=True
    )
    
    if tflite_model is None:
        print("❌ Falha na conversão")
        return False
    
    # Salvar modelo TFLite
    print("\n💾 Salvando modelo TFLite...")
    success = converter.save_tflite_model(tflite_model, output_path)
    
    if not success:
        print("❌ Falha ao salvar modelo")
        return False
    
    # Obter informações do modelo
    print("\n📊 Informações do modelo TFLite:")
    model_info = converter.get_model_info(output_path)
    
    # Testar modelo TFLite se temos dados
    if X_sample is not None:
        print("\n🧪 Testando modelo TFLite...")
        try:
            predictions = converter.test_tflite_model(output_path, X_sample[:5])
            if predictions:
                print("✅ Teste do modelo TFLite bem-sucedido!")
        except Exception as e:
            print(f"⚠️ Erro no teste: {e}")
    
    # Comparar com modelo original se possível
    if X_sample is not None:
        print("\n🔍 Comparando modelos...")
        try:
            converter.compare_models(converter.model, output_path, X_sample[:5])
        except Exception as e:
            print(f"⚠️ Erro na comparação: {e}")
    
    print("\n" + "🎉" * 20)
    print("✅ CONVERSÃO CONCLUÍDA COM SUCESSO!")
    print(f"✅ Modelo TFLite salvo: {output_path}")
    print(f"✅ Tamanho: {model_info['file_size_mb']:.2f} MB")
    print("🎉" * 20)
    
    return True

if __name__ == "__main__":
    success = convert_model()
    if success:
        print("\n🚀 Modelo pronto para uso em produção!")
    else:
        print("\n❌ Conversão falhou!")
