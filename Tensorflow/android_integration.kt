// Exemplo de integração do modelo TensorFlow Lite no Android
// Arquivo: ThaiIDClassifier.kt

package com.example.thaiidrecognition

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class ThaiIDClassifier(private val context: Context) {
    
    companion object {
        private const val TAG = "ThaiIDClassifier"
        private const val MODEL_FILE = "thai_id_model.tflite"
        private const val INPUT_SIZE = 224
        private const val PIXEL_SIZE = 3
        private const val NUM_CLASSES = 3
        private const val BATCH_SIZE = 1
        
        // Nomes das classes (devem corresponder ao arquivo classes.txt)
        private val CLASS_NAMES = arrayOf("card", "national_id", "religion")
    }
    
    private var interpreter: Interpreter? = null
    private var inputImageBuffer: ByteBuffer? = null
    private var outputProbabilityBuffer: Array<ByteArray>? = null
    
    fun initialize(): Boolean {
        try {
            val model = loadModelFile()
            interpreter = Interpreter(model)
            
            // Configurar buffers de entrada e saída
            setupBuffers()
            
            Log.d(TAG, "Modelo TensorFlow Lite inicializado com sucesso")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao inicializar modelo: ${e.message}")
            return false
        }
    }
    
    private fun loadModelFile(): MappedByteBuffer {
        val assetFileDescriptor = context.assets.openFd(MODEL_FILE)
        val fileInputStream = FileInputStream(assetFileDescriptor.fileDescriptor)
        val fileChannel = fileInputStream.channel
        val startOffset = assetFileDescriptor.startOffset
        val declaredLength = assetFileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }
    
    private fun setupBuffers() {
        // Buffer de entrada: 1 x 224 x 224 x 3 (UINT8)
        val inputSize = BATCH_SIZE * INPUT_SIZE * INPUT_SIZE * PIXEL_SIZE
        inputImageBuffer = ByteBuffer.allocateDirect(inputSize)
        inputImageBuffer?.order(ByteOrder.nativeOrder())
        
        // Buffer de saída: 1 x 3 (UINT8)
        outputProbabilityBuffer = Array(BATCH_SIZE) { ByteArray(NUM_CLASSES) }
    }
    
    fun classify(bitmap: Bitmap): ClassificationResult? {
        if (interpreter == null) {
            Log.e(TAG, "Modelo não foi inicializado")
            return null
        }
        
        try {
            // Preprocessar imagem
            val resizedBitmap = Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, true)
            convertBitmapToByteBuffer(resizedBitmap)
            
            // Executar inferência
            interpreter?.run(inputImageBuffer, outputProbabilityBuffer)
            
            // Processar resultado
            return processOutput()
            
        } catch (e: Exception) {
            Log.e(TAG, "Erro durante classificação: ${e.message}")
            return null
        }
    }
    
    private fun convertBitmapToByteBuffer(bitmap: Bitmap) {
        inputImageBuffer?.rewind()
        
        val intValues = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        
        var pixel = 0
        for (i in 0 until INPUT_SIZE) {
            for (j in 0 until INPUT_SIZE) {
                val value = intValues[pixel++]
                
                // Extrair valores RGB e converter para UINT8
                val r = ((value shr 16) and 0xFF).toByte()
                val g = ((value shr 8) and 0xFF).toByte()
                val b = (value and 0xFF).toByte()
                
                inputImageBuffer?.put(r)
                inputImageBuffer?.put(g)
                inputImageBuffer?.put(b)
            }
        }
    }
    
    private fun processOutput(): ClassificationResult {
        val probabilities = outputProbabilityBuffer!![0]
        
        // Encontrar classe com maior probabilidade
        var maxIndex = 0
        var maxValue = probabilities[0].toInt() and 0xFF
        
        for (i in 1 until NUM_CLASSES) {
            val value = probabilities[i].toInt() and 0xFF
            if (value > maxValue) {
                maxValue = value
                maxIndex = i
            }
        }
        
        val className = if (maxIndex < CLASS_NAMES.size) {
            CLASS_NAMES[maxIndex]
        } else {
            "unknown"
        }
        
        // Converter UINT8 para probabilidade normalizada (0-1)
        val confidence = maxValue / 255.0f
        
        // Criar array de todas as probabilidades
        val allProbabilities = FloatArray(NUM_CLASSES) { i ->
            (probabilities[i].toInt() and 0xFF) / 255.0f
        }
        
        return ClassificationResult(
            classId = maxIndex,
            className = className,
            confidence = confidence,
            probabilities = allProbabilities
        )
    }
    
    fun close() {
        interpreter?.close()
        interpreter = null
        Log.d(TAG, "Modelo TensorFlow Lite fechado")
    }
}

// Classe para resultado da classificação
data class ClassificationResult(
    val classId: Int,
    val className: String,
    val confidence: Float,
    val probabilities: FloatArray
) {
    override fun toString(): String {
        return "Classe: $className (ID: $classId), Confiança: %.2f%%".format(confidence * 100)
    }
}

// Exemplo de uso em uma Activity
/*
class MainActivity : AppCompatActivity() {
    private lateinit var classifier: ThaiIDClassifier
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Inicializar classificador
        classifier = ThaiIDClassifier(this)
        if (!classifier.initialize()) {
            Log.e("MainActivity", "Falha ao inicializar classificador")
            return
        }
        
        // Exemplo de classificação
        // val bitmap = ... // sua imagem
        // val result = classifier.classify(bitmap)
        // result?.let {
        //     Log.d("MainActivity", "Resultado: $it")
        // }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        classifier.close()
    }
}
*/
