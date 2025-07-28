import tensorflow as tf

# Carregar seu modelo
model = tf.keras.models.load_model('fine_tuned_model_extended.h5')

# Converter com configurações de compatibilidade
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,  # Enable TensorFlow Lite ops
]

# Converter
tflite_model = converter.convert()

# Salvar
with open('model2.tflite', 'wb') as f:
    f.write(tflite_model)