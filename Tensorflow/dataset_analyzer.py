import os
import json
import cv2
import numpy as np
from collections import Counter
import matplotlib.pyplot as plt

class DatasetAnalyzer:
    def __init__(self, dataset_path="dataset/"):
        self.dataset_path = dataset_path
        self.images_path = os.path.join(dataset_path, 'images')
        self.labels_path = os.path.join(dataset_path, 'labels')
        self.classes_file = os.path.join(dataset_path, 'classes.txt')
        self.notes_file = os.path.join(dataset_path, 'notes.json')
    
    def analyze_dataset(self):
        """Analisa a estrutura do dataset"""
        print("=== ANÁLISE DO DATASET ===")
        
        # Verificar arquivos principais
        if os.path.exists(self.classes_file):
            with open(self.classes_file, 'r', encoding='utf-8') as f:
                classes = [line.strip() for line in f.readlines() if line.strip()]
            print(f"Classes encontradas: {len(classes)}")
            for i, class_name in enumerate(classes):
                print(f"  {i}: {class_name}")
        else:
            print("Arquivo classes.txt não encontrado")
            return None
        
        # Verificar notas
        if os.path.exists(self.notes_file):
            with open(self.notes_file, 'r', encoding='utf-8') as f:
                notes = json.load(f)
            print(f"\nNotas do dataset:")
            print(f"  Versão: {notes.get('info', {}).get('version', 'N/A')}")
            print(f"  Ano: {notes.get('info', {}).get('year', 'N/A')}")
            print(f"  Contribuidor: {notes.get('info', {}).get('contributor', 'N/A')}")
        
        # Analisar imagens
        image_files = [f for f in os.listdir(self.images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        print(f"\nTotal de imagens: {len(image_files)}")
        
        # Analisar labels
        if os.path.exists(self.labels_path):
            label_files = [f for f in os.listdir(self.labels_path) 
                          if f.endswith('.txt')]
            print(f"Total de labels: {len(label_files)}")
            
            # Analisar distribuição de classes
            class_counts = Counter()
            for label_file in label_files[:10]:  # Amostra dos primeiros 10
                label_path = os.path.join(self.labels_path, label_file)
                with open(label_path, 'r') as f:
                    for line in f:
                        parts = line.strip().split()
                        if parts:
                            class_id = int(parts[0])
                            class_counts[class_id] += 1
            
            print(f"\nDistribuição de classes (amostra):")
            for class_id, count in class_counts.items():
                class_name = classes[class_id] if class_id < len(classes) else f"unknown_{class_id}"
                print(f"  {class_name} (id: {class_id}): {count}")
        
        # Analisar dimensões das imagens
        sample_images = image_files[:5]
        dimensions = []
        
        for img_file in sample_images:
            img_path = os.path.join(self.images_path, img_file)
            img = cv2.imread(img_path)
            if img is not None:
                dimensions.append(img.shape)
        
        if dimensions:
            print(f"\nDimensões das imagens (amostra):")
            for i, dim in enumerate(dimensions):
                print(f"  {sample_images[i]}: {dim}")
        
        return classes
    
    def get_dataset_stats(self):
        """Retorna estatísticas do dataset"""
        image_files = [f for f in os.listdir(self.images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        
        # Carregar classes
        with open(self.classes_file, 'r', encoding='utf-8') as f:
            classes = [line.strip() for line in f.readlines() if line.strip()]
        
        return {
            'num_images': len(image_files),
            'num_classes': len(classes),
            'classes': classes,
            'image_files': image_files
        }

if __name__ == "__main__":
    analyzer = DatasetAnalyzer()
    classes = analyzer.analyze_dataset()
