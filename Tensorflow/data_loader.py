import os
import json
import cv2
import numpy as np
from tensorflow.keras.utils import to_categorical
import glob
from pathlib import Path

class ThaiIDDataLoader:
    def __init__(self, dataset_path="dataset/"):
        self.dataset_path = dataset_path
        self.images_path = os.path.join(dataset_path, 'images')
        self.labels_path = os.path.join(dataset_path, 'labels')
        self.classes_file = os.path.join(dataset_path, 'classes.txt')
        self.notes_file = os.path.join(dataset_path, 'notes.json')
        
        # Carregar classes
        self.classes = self._load_classes()
        self.num_classes = len(self.classes)
        
        # Carregar notas/metadados
        if os.path.exists(self.notes_file):
            with open(self.notes_file, 'r', encoding='utf-8') as f:
                self.notes = json.load(f)
        else:
            self.notes = {}
    
    def _load_classes(self):
        """Carrega as classes do arquivo classes.txt"""
        if os.path.exists(self.classes_file):
            with open(self.classes_file, 'r', encoding='utf-8') as f:
                classes = [line.strip() for line in f.readlines() if line.strip()]
            return classes
        else:
            raise FileNotFoundError(f"Arquivo {self.classes_file} não encontrado")
    
    def _parse_yolo_label(self, label_path):
        """Parse do arquivo label no formato YOLO"""
        boxes = []
        classes = []
        
        if os.path.exists(label_path):
            with open(label_path, 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 5:
                        class_id = int(parts[0])
                        x_center = float(parts[1])
                        y_center = float(parts[2])
                        width = float(parts[3])
                        height = float(parts[4])
                        
                        boxes.append([x_center, y_center, width, height])
                        classes.append(class_id)
        
        return np.array(boxes), np.array(classes)
    
    def load_data_for_classification(self, img_size=(224, 224), max_samples_per_class=None):
        """
        Carrega dados para classificação de imagem.
        Para cada imagem, usa a classe mais frequente nas bounding boxes.
        """
        images = []
        labels = []
        
        # Listar arquivos de imagem
        image_files = [f for f in os.listdir(self.images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        
        print(f"Processando {len(image_files)} imagens...")
        
        class_counts = {i: 0 for i in range(self.num_classes)}
        
        for img_file in image_files:
            # Carregar imagem
            img_path = os.path.join(self.images_path, img_file)
            image = cv2.imread(img_path)
            if image is None:
                continue
                
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            image = cv2.resize(image, img_size)
            image = image.astype('float32') / 255.0
            
            # Carregar label correspondente
            label_file = os.path.splitext(img_file)[0] + '.txt'
            label_path = os.path.join(self.labels_path, label_file)
            
            boxes, box_classes = self._parse_yolo_label(label_path)
            
            if len(box_classes) > 0:
                # Usar a classe mais frequente na imagem
                unique, counts = np.unique(box_classes, return_counts=True)
                most_frequent_class = unique[np.argmax(counts)]
                
                # Verificar limite de amostras por classe
                if max_samples_per_class is None or class_counts[most_frequent_class] < max_samples_per_class:
                    images.append(image)
                    labels.append(most_frequent_class)
                    class_counts[most_frequent_class] += 1
        
        print(f"Dados carregados: {len(images)} imagens")
        print("Distribuição por classe:")
        for i, class_name in enumerate(self.classes):
            print(f"  {class_name}: {class_counts[i]} imagens")
        
        return np.array(images), np.array(labels)
    
    def load_data_for_detection(self, img_size=(416, 416)):
        """
        Carrega dados para detecção de objetos (formato YOLO).
        Retorna imagens e bounding boxes.
        """
        images = []
        all_boxes = []
        all_classes = []
        
        image_files = [f for f in os.listdir(self.images_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))]
        
        for img_file in image_files:
            img_path = os.path.join(self.images_path, img_file)
            image = cv2.imread(img_path)
            if image is None:
                continue
            
            original_h, original_w = image.shape[:2]
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            image = cv2.resize(image, img_size)
            image = image.astype('float32') / 255.0
            
            # Carregar annotations
            label_file = os.path.splitext(img_file)[0] + '.txt'
            label_path = os.path.join(self.labels_path, label_file)
            
            boxes, box_classes = self._parse_yolo_label(label_path)
            
            if len(boxes) > 0:
                # Converter coordenadas YOLO para formato absoluto
                boxes[:, 0] *= img_size[1]  # x_center
                boxes[:, 1] *= img_size[0]  # y_center
                boxes[:, 2] *= img_size[1]  # width
                boxes[:, 3] *= img_size[0]  # height
                
                images.append(image)
                all_boxes.append(boxes)
                all_classes.append(box_classes)
        
        return np.array(images), all_boxes, all_classes
    
    def get_class_names(self):
        """Retorna lista de nomes das classes"""
        return self.classes
    
    def get_num_classes(self):
        """Retorna número de classes"""
        return self.num_classes
