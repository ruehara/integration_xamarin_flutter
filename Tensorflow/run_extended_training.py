#!/usr/bin/env python3
"""
Script principal para executar o treinamento estendido com 100 épocas
"""

import os
import sys
import time
import argparse
from pathlib import Path

# Adicionar o diretório atual ao path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main_extended import main_extended_training
from inference import ThaiIDInference

def main():
    """Função principal para execução do treinamento estendido"""
    
    print("=" * 70)
    print("🚀 TREINAMENTO ESTENDIDO - MODELO THAI ID")
    print("=" * 70)
    
    # Configuração
    config = {
        'epochs': 100,
        'batch_size': 8,
        'learning_rate': 0.0001,
        'patience': 20,
        'oversampling_factor': 10,
        'validation_split': 0.2,
        'use_mixed_precision': True,
        'save_best_model': True
    }
    
    print(f"📊 Configuração do treinamento:")
    for key, value in config.items():
        print(f"   {key}: {value}")
    print()
    
    # Verificar dataset
    dataset_path = "dataset"
    if not os.path.exists(dataset_path):
        print(f"❌ Erro: Dataset não encontrado em {dataset_path}")
        return False
    
    images_path = os.path.join(dataset_path, "images")
    labels_path = os.path.join(dataset_path, "labels")
    
    if not os.path.exists(images_path) or not os.path.exists(labels_path):
        print("❌ Erro: Pastas 'images' ou 'labels' não encontradas no dataset")
        return False
    
    # Contar arquivos
    image_files = [f for f in os.listdir(images_path) 
                   if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
    label_files = [f for f in os.listdir(labels_path) 
                   if f.endswith('.txt')]
    
    print(f"📁 Dataset encontrado:")
    print(f"   Imagens: {len(image_files)}")
    print(f"   Labels: {len(label_files)}")
    print()
    
    if len(image_files) == 0:
        print("❌ Erro: Nenhuma imagem encontrada no dataset")
        return False
    
    # Verificar modelo anterior
    previous_models = []
    for model_file in ['thai_id_model.h5', 'best_model.h5', 'fine_tuned_model.h5']:
        if os.path.exists(model_file):
            previous_models.append(model_file)
    
    if previous_models:
        print(f"📋 Modelos anteriores encontrados: {', '.join(previous_models)}")
        print()
    
    # Executar treinamento
    try:
        print("🎯 Iniciando treinamento estendido...")
        start_time = time.time()
        
        # Chamar função principal de treinamento
        result = main_extended_training()
        
        end_time = time.time()
        training_time = end_time - start_time
        
        print(f"⏱️ Tempo total de treinamento: {training_time/60:.1f} minutos")
        
        if result:
            print("✅ Treinamento concluído com sucesso!")
            
            # Teste rápido do modelo
            print("\n🧪 Testando modelo treinado...")
            test_model_quickly()
            
            # Benchmark de velocidade
            print("\n⚡ Benchmark de velocidade...")
            benchmark_model_speed()
            
            return True
        else:
            print("❌ Erro durante o treinamento")
            return False
            
    except KeyboardInterrupt:
        print("\n⏹️ Treinamento interrompido pelo usuário")
        return False
    except Exception as e:
        print(f"❌ Erro durante o treinamento: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_model_quickly():
    """Teste rápido do modelo treinado"""
    try:
        # Verificar qual modelo usar
        model_path = None
        for candidate in ['thai_id_model_extended.tflite', 'thai_id_model.tflite']:
            if os.path.exists(candidate):
                model_path = candidate
                break
        
        if not model_path:
            print("   ⚠️ Modelo TFLite não encontrado para teste")
            return
        
        print(f"   📱 Testando modelo: {model_path}")
        
        # Carregar modelo
        inference = ThaiIDInference(model_path)
        
        # Teste com algumas imagens
        inference.test_with_dataset(max_images=5)
        
    except Exception as e:
        print(f"   ❌ Erro no teste: {e}")

def benchmark_model_speed():
    """Benchmark de velocidade do modelo"""
    try:
        # Verificar qual modelo usar
        model_path = None
        for candidate in ['thai_id_model_extended.tflite', 'thai_id_model.tflite']:
            if os.path.exists(candidate):
                model_path = candidate
                break
        
        if not model_path:
            print("   ⚠️ Modelo TFLite não encontrado para benchmark")
            return
        
        print(f"   ⚡ Benchmark do modelo: {model_path}")
        
        # Carregar modelo
        inference = ThaiIDInference(model_path)
        
        # Benchmark
        results = inference.benchmark_inference_speed(num_iterations=50)
        
        if results:
            print(f"   📊 Resumo do benchmark:")
            print(f"      Tempo médio: {results['avg_time_ms']:.2f}ms")
            print(f"      FPS: {results['fps']:.1f}")
        
    except Exception as e:
        print(f"   ❌ Erro no benchmark: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Treinamento estendido do modelo Thai ID")
    parser.add_argument("--quick-test", action="store_true", 
                       help="Executar apenas teste rápido do modelo existente")
    parser.add_argument("--benchmark", action="store_true", 
                       help="Executar apenas benchmark de velocidade")
    
    args = parser.parse_args()
    
    if args.quick_test:
        print("🧪 Executando teste rápido...")
        test_model_quickly()
    elif args.benchmark:
        print("⚡ Executando benchmark...")
        benchmark_model_speed()
    else:
        success = main()
        if success:
            print("\n🎉 Processo concluído com sucesso!")
        else:
            print("\n💥 Processo falhou!")
            sys.exit(1)
