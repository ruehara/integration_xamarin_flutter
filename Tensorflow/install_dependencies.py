import subprocess
import sys
import os

def install_package(package):
    """Instala um pacote usando pip"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        return True
    except subprocess.CalledProcessError as e:
        print(f"Erro ao instalar {package}: {e}")
        return False

def check_and_install_dependencies():
    """Verifica e instala dependências necessárias"""
    print("=== INSTALAÇÃO DE DEPENDÊNCIAS ===")
    
    # Lista de dependências
    dependencies = [
        "tensorflow>=2.10.0",
        "opencv-python>=4.5.0", 
        "numpy>=1.21.0",
        "matplotlib>=3.5.0",
        "scikit-learn>=1.0.0",
        "Pillow>=8.0.0"
    ]
    
    print("Verificando e instalando dependências necessárias...")
    
    for package in dependencies:
        package_name = package.split(">=")[0]
        
        try:
            # Tentar importar o pacote
            if package_name == "opencv-python":
                import cv2
                print(f"✓ {package_name} já está instalado")
            elif package_name == "tensorflow":
                import tensorflow as tf
                print(f"✓ {package_name} já está instalado - versão {tf.__version__}")
            elif package_name == "numpy":
                import numpy as np
                print(f"✓ {package_name} já está instalado")
            elif package_name == "matplotlib":
                import matplotlib
                print(f"✓ {package_name} já está instalado")
            elif package_name == "scikit-learn":
                import sklearn
                print(f"✓ {package_name} já está instalado")
            elif package_name == "Pillow":
                from PIL import Image
                print(f"✓ {package_name} já está instalado")
                
        except ImportError:
            print(f"⚠ {package_name} não encontrado. Instalando...")
            
            if install_package(package):
                print(f"✓ {package_name} instalado com sucesso")
            else:
                print(f"✗ Falha ao instalar {package_name}")
                return False
    
    print("\n✓ Todas as dependências estão instaladas!")
    return True

def create_requirements_file():
    """Cria arquivo requirements.txt"""
    requirements = [
        "tensorflow>=2.10.0",
        "opencv-python>=4.5.0",
        "numpy>=1.21.0", 
        "matplotlib>=3.5.0",
        "scikit-learn>=1.0.0",
        "Pillow>=8.0.0"
    ]
    
    with open("requirements.txt", "w") as f:
        for req in requirements:
            f.write(req + "\n")
    
    print("Arquivo requirements.txt criado!")

def main():
    """Função principal"""
    print("INSTALADOR DE DEPENDÊNCIAS - MODELO TENSORFLOW LITE")
    print("=" * 60)
    
    # Criar arquivo requirements.txt
    create_requirements_file()
    
    # Instalar dependências
    if check_and_install_dependencies():
        print("\n" + "=" * 60)
        print("INSTALAÇÃO CONCLUÍDA COM SUCESSO!")
        print("\nVocê pode agora executar:")
        print("  python main.py")
        print("\nPara treinar e criar seu modelo TensorFlow Lite.")
    else:
        print("\n" + "=" * 60)
        print("ERRO NA INSTALAÇÃO")
        print("\nTente instalar manualmente:")
        print("  pip install -r requirements.txt")

if __name__ == "__main__":
    main()
