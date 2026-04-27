package com.vibesbox.dj

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Base64
import android.util.Log
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.shazam.shazamkit.AudioSampleRateInHz
import com.shazam.shazamkit.DeveloperToken
import com.shazam.shazamkit.DeveloperTokenProvider
import com.shazam.shazamkit.MatchResult
import com.shazam.shazamkit.ShazamKit
import com.shazam.shazamkit.ShazamKitResult
import com.shazam.shazamkit.SignatureGenerator
import com.shazam.shazamkit.StreamingSession
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity: FlutterFragmentActivity() {
    companion object {
        const val ACTION_OPEN_APP = "com.vibesbox.dj.OPEN_APP"
        const val ACTION_OPEN_HISTORY = "com.vibesbox.dj.OPEN_HISTORY"
        const val EXTRA_NAV_TARGET = "nav_target"
        private const val NAV_TARGET_HISTORY = "history"
        private const val METHOD_NOTIFICATION_NAV_TARGET = "onNotificationNavigationTarget"
    }

    private val BATTERY_CHANNEL = "dj_og_app/battery_optimization"
    private val SHAZAM_CHANNEL = "shazam_channel"
    private val RMS_CHANNEL = "dj_og_app/rms_stream"
    private val AUTO_ADJUST_CHANNEL = "com.vibesbox.dj/auto_adjust" // AUTOMATIC GAIN & THRESHOLD MAPPING
    
    // Shazam-Variablen
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var matchFound = false
    private var session: StreamingSession? = null
    private var currentResult: MethodChannel.Result? = null
    private var currentToken: String? = null
    private var micSensitivity: Double = 1.0 // Standard: 1.0 (0.5 bis 2.0)
    private var recognitionThreshold: Double = 0.3 // Standard: 0.3 (0.0 bis 1.0) - Schwellenwert für Scan
    private var smartThresholdEnabled: Boolean = false // Standard: false (manuell)
    private var manualThreshold: Double = 0.3 // Manueller Schwellenwert (wird bei Smart-Threshold gespeichert)
    private var rmsEventSink: EventChannel.EventSink? = null
    private var autoAdjustEventSink: EventChannel.EventSink? = null // AUTOMATIC GAIN & THRESHOLD MAPPING
    private var autoAdjustSent = false // Verhindert Mehrfachsenden pro Scan
    private var lastOptimizedSensitivity: Double = 1.0 // Letzte berechnete Sensitivity (für Senden bei Match/NoMatch)
    private var lastCalculatedThreshold: Double = 0.3 // Letzter berechneter Threshold (für Senden bei Match/NoMatch)
    private var autoGainCalculated = false // Wird auf true gesetzt, nachdem Gain angepasst wurde
    private var optimizedSensitivity: Double = 1.0 // Optimierte Sensitivity nach Berechnung
    private var pendingNotificationNavTarget: String? = null
    private var shazamMethodChannel: MethodChannel? = null
    
    // Kontinuierlicher RMS-Stream (unabhängig von Shazam-Scans)
    private var rmsAudioRecord: AudioRecord? = null
    private var isRmsRecording = false
    private var rmsRecordingThread: Thread? = null
    private val sampleRate = 44100
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    // 10000 war für reale Club-Pegel zu konservativ und führte oft zu ~0.005 Mittelwerten.
    // Mit 2500 bleibt die Normierung stabil, aber ausreichend sensitiv für leise Umgebungen.
    private val rmsNormalizationDivisor = 2500.0
    // Fester Wert für Shazam: 1792 Shorts = 3584 Bytes (exakt was Shazam erwartet)
    private val bufferSize = 1792
    // AudioRecord benötigt einen größeren Buffer für die Initialisierung
    private val audioRecordBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
    private val REQUEST_RECORD_AUDIO_PERMISSION = 200
    private lateinit var appPrefs: SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        pendingNotificationNavTarget = extractNavigationTarget(intent)
        clearNavigationIntentState(intent)
    }

    override fun onResume() {
        super.onResume()
        // Lifecycle-Wächter: Nach langer Background-Zeit harte Konsistenzprüfung.
        val showStatusNotification = appPrefs.getBoolean("flutter.show_status_notification", false)
        if (!showStatusNotification && isShazamForegroundServiceRunning()) {
            Log.w("Shazam", "Lifecycle-Guard: Service läuft trotz AUS-Schalter -> harter Stop")
            stopForegroundService()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val target = extractNavigationTarget(intent)
        // Wichtig: Notification-Intent sofort "entwaffnen", damit er bei Resume/Neuaufbau nicht erneut greift.
        clearNavigationIntentState(intent)
        setIntent(intent)
        if (target == null) return
        pendingNotificationNavTarget = target
        shazamMethodChannel?.invokeMethod(
            METHOD_NOTIFICATION_NAV_TARGET,
            mapOf("target" to target)
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Battery Optimization Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val isIgnoring = isIgnoringBatteryOptimizations()
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Shazam Channel
        val shazamChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAZAM_CHANNEL)
        shazamMethodChannel = shazamChannel
        shazamChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "recognize" -> {
                    currentResult = result
                    // Extrahiere optionales Token und mic_sensitivity aus den Argumenten
                    val args = call.arguments as? Map<*, *>
                    var token = args?.get("token") as? String

                    // Token ist optional. Für den neuen Proxy-Flow wird er normalerweise nicht gesetzt.
                    if (!token.isNullOrEmpty()) {
                        token = token.trim()
                        currentToken = token
                    } else {
                        currentToken = null
                        Log.d("Shazam", "Proxy-Flow aktiv: kein lokaler Apple-Token im recognize-Call.")
                    }
                    
                    // Extrahiere mic_sensitivity (optional, Standard: 1.0)
                    val sensitivity = args?.get("mic_sensitivity") as? Number
                    if (sensitivity != null) {
                        val sensitivityValue = sensitivity.toDouble()
                        if (sensitivityValue >= 0.5 && sensitivityValue <= 2.0) {
                            micSensitivity = sensitivityValue
                        }
                    }
                    
                    // Extrahiere smart_threshold_enabled (optional, Standard: false)
                    val smartThreshold = args?.get("smart_threshold_enabled") as? Boolean
                    if (smartThreshold != null) {
                        smartThresholdEnabled = smartThreshold
                        Log.d("Shazam", "Smart-Threshold: ${if (smartThresholdEnabled) "aktiviert" else "deaktiviert"}")
                    }

                    // Extrahiere recognition_threshold (optional, Standard: 0.3)
                    // Wichtig: Bei aktivem Smart-Threshold NICHT direkt auf recognitionThreshold schreiben,
                    // sonst überschreibt der manuelle Wert die Auto-Berechnung.
                    val threshold = args?.get("recognition_threshold") as? Number
                    if (threshold != null) {
                        val thresholdValue = threshold.toDouble()
                        if (thresholdValue >= 0.0 && thresholdValue <= 1.0) {
                            manualThreshold = thresholdValue
                            if (!smartThresholdEnabled) {
                                recognitionThreshold = thresholdValue
                                Log.d("Shazam", "Manueller Schwellenwert gesetzt: $manualThreshold")
                            } else {
                                Log.d("Shazam", "Smart-Threshold aktiv: manueller Basiswert gespeichert ($manualThreshold), Auto-Wert bleibt aktiv")
                            }
                        }
                    }
                    
                    Log.d("Shazam", "recognize aufgerufen (Token lokal nicht erforderlich), Threshold=$recognitionThreshold")
                    if (checkAudioPermission()) {
                        startShazamRecognition()
                    } else {
                        requestAudioPermission()
                    }
                }
                "setMicSensitivity" -> {
                    // Empfange Mikrofon-Empfindlichkeit sofort (ohne Scan-Unterbrechung)
                    // Die Sensitivity wird direkt auf den laufenden Audio-Buffer angewendet
                    val args = call.arguments as? Map<*, *>
                    val sensitivity = args?.get("sensitivity") as? Number
                    if (sensitivity != null) {
                        val sensitivityValue = sensitivity.toDouble()
                        if (sensitivityValue >= 0.5 && sensitivityValue <= 2.0) {
                            // Thread-sichere Aktualisierung (wird sofort in Audio-Loop verwendet)
                            micSensitivity = sensitivityValue
                            Log.d("Shazam", "✅ Mikrofon-Empfindlichkeit live aktualisiert: $micSensitivity (Stream läuft weiter)")
                        } else {
                            Log.w("Shazam", "⚠️ Ungültige Sensitivity: $sensitivityValue (muss zwischen 0.5 und 2.0 liegen)")
                        }
                    }
                    result.success(true)
                }
                "setSmartThresholdEnabled" -> {
                    // Intelligente Anpassung: Status sofort übernehmen (auch während Scan)
                    val args = call.arguments as? Map<*, *>
                    val enabled = args?.get("enabled") as? Boolean
                    if (enabled != null) {
                        smartThresholdEnabled = enabled
                        Log.d("Shazam", "Smart-Threshold live: ${if (smartThresholdEnabled) "aktiviert" else "deaktiviert"}")
                    }
                    result.success(true)
                }
                "startScanning" -> {
                    val args = call.arguments as? Map<*, *>
                    val showStatusNotification = args?.get("showStatusNotification") as? Boolean
                    if (showStatusNotification == null) {
                        result.error(
                            "MISSING_ARG",
                            "showStatusNotification ist ein Pflicht-Parameter für startScanning",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    val notificationTitle = args?.get("notificationTitle") as? String
                    val notificationListening = args?.get("notificationListening") as? String
                    val started = startForegroundService(showStatusNotification, notificationTitle, notificationListening)
                    result.success(started)
                }
                "stopScanning" -> {
                    stopForegroundService()
                    result.success(true)
                }
                "stopCurrentScan" -> {
                    try {
                        stopRecordingSafely()
                        Log.d("Shazam", "Hard-Stop: Scan gestoppt")
                    } catch (e: Exception) {
                        Log.e("Shazam", "Fehler beim Hard-Stop: ${e.message}", e)
                    }
                    result.success(true)
                }
                "updateRecognitionNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val notificationTitle = args?.get("notificationTitle") as? String
                    val contentText = args?.get("contentText") as? String
                    val navigationTarget = args?.get("navigationTarget") as? String
                    ShazamForegroundService.updateNotification(this, notificationTitle, contentText, navigationTarget)
                    result.success(true)
                }
                "updateNotificationContent" -> {
                    val args = call.arguments as? Map<*, *>
                    val notificationTitle = args?.get("notificationTitle") as? String
                    val contentText = args?.get("contentText") as? String
                    ShazamForegroundService.updateNotificationContent(this, notificationTitle, contentText)
                    result.success(true)
                }
                "updateNotificationVisibility" -> {
                    val args = call.arguments as? Map<*, *>
                    val visible = args?.get("visible") as? Boolean
                    if (visible == null) {
                        result.error(
                            "MISSING_ARG",
                            "visible ist ein Pflicht-Parameter für updateNotificationVisibility",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    val notificationTitle = args?.get("notificationTitle") as? String
                    val notificationListening = args?.get("notificationListening") as? String
                    ShazamForegroundService.applyNotificationVisibilityNow(
                        this,
                        visible,
                        notificationTitle,
                        notificationListening
                    )
                    result.success(true)
                }
                "consumePendingNavigationTarget" -> {
                    val target = pendingNotificationNavTarget
                    pendingNotificationNavTarget = null
                    clearNavigationIntentState(intent)
                    result.success(target)
                }
                "clearPendingNavigationTarget" -> {
                    pendingNotificationNavTarget = null
                    clearNavigationIntentState(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // RMS Stream EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RMS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    rmsEventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    rmsEventSink = null
                }
            }
        )
        
        // AUTOMATIC GAIN & THRESHOLD MAPPING: EventChannel für automatische Werte-Updates
        // WICHTIG: EventChannel wird permanent in configureFlutterEngine registriert, nicht erst beim Scan-Start
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_ADJUST_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    autoAdjustEventSink = events
                    Log.i("VIBESBOX_CHANNEL", "✅ Flutter hört jetzt zu! Leitung ist AKTIV.")
                    
                    // Sofortiger Test-Ping beim Verbinden
                    Handler(Looper.getMainLooper()).post {
                        autoAdjustEventSink?.success(mapOf("status" to "connected"))
                    }
                }

                override fun onCancel(arguments: Any?) {
                    Log.i("VIBESBOX_CHANNEL", "❌ Flutter hat aufgelegt. Leitung DEAKTIVIERT.")
                    autoAdjustEventSink = null
                }
            }
        )
    }

    private fun extractNavigationTarget(intent: Intent?): String? {
        if (intent == null) return null
        val fromExtra = intent.getStringExtra(EXTRA_NAV_TARGET)
        if (!fromExtra.isNullOrBlank()) return fromExtra
        return if (intent.action == ACTION_OPEN_HISTORY) NAV_TARGET_HISTORY else null
    }

    private fun clearNavigationIntentState(intent: Intent?) {
        if (intent == null) return
        intent.removeExtra(EXTRA_NAV_TARGET)
        if (intent.action == ACTION_OPEN_HISTORY || intent.action == ACTION_OPEN_APP) {
            intent.action = Intent.ACTION_MAIN
            intent.data = null
        }
    }
    
    private fun checkAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestAudioPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_RECORD_AUDIO_PERMISSION
        )
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_RECORD_AUDIO_PERMISSION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startShazamRecognition()
            } else {
                currentResult?.error("PERMISSION_DENIED", "Mikrofon-Berechtigung wurde verweigert", null)
                currentResult = null
            }
        }
    }
    
    private fun startShazamRecognition() {
        // Prüfe ob alte Session noch existiert und beende sie sauber
        val oldSession = session
        if (oldSession != null) {
            Log.d("Shazam", "Alte Session gefunden, beende sie vor neuem Scan")
            try {
                stopRecording()
                // Warte kurz, damit alte Session vollständig freigegeben wird
                Thread.sleep(100)
            } catch (e: Exception) {
                Log.e("Shazam", "Fehler beim Beenden alter Session: ${e.message}", e)
            }
        }
        
        if (audioRecordBufferSize == AudioRecord.ERROR_BAD_VALUE || audioRecordBufferSize == AudioRecord.ERROR) {
            Log.e("Shazam", "AudioRecord Buffer Size Error")
            currentResult?.error("AUDIO_ERROR", "AudioRecord Buffer Size Error", null)
            currentResult = null
            return
        }

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            channelConfig,
            audioFormat,
            audioRecordBufferSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e("Shazam", "AudioRecord Initialization Failed")
            currentResult?.error("AUDIO_ERROR", "AudioRecord Initialization Failed", null)
            currentResult = null
            return
        }

        // Neuer Proxy-Flow: Native Seite erzeugt nur Signatur und gibt sie an Flutter zurück.
        if (currentToken.isNullOrEmpty()) {
            captureAudioSignatureOnly()
            return
        }

        // Legacy-Fallback: StreamingSession mit Token (falls explizit gesetzt)
        CoroutineScope(Dispatchers.Main).launch {
            try {
                // TokenProvider mit explizit gesetztem Token
                var token = currentToken ?: ""
                
                // Token nochmal bereinigen (sicherheitshalber)
                token = token.trim()
                
                if (token.isNotEmpty()) {
                    Log.d("Shazam", "Apple DeveloperToken gesetzt (kein Inhalt geloggt).")
                }
                
                val tokenProvider = object : DeveloperTokenProvider {
                    override fun provideDeveloperToken(): DeveloperToken {
                        return DeveloperToken(token)
                    }
                }
                
                val catalog = ShazamKit.createShazamCatalog(tokenProvider)
                // Shazam erwartet 3584 Bytes (1792 Shorts * 2)
                val sessionResult = ShazamKit.createStreamingSession(
                    catalog,
                    AudioSampleRateInHz.SAMPLE_RATE_44100,
                    bufferSize * 2 // 3584 Bytes
                )

                when (sessionResult) {
                    is ShazamKitResult.Success<*> -> {
                        // Prüfe nochmal ob Session bereits existiert (Race Condition Schutz)
                        if (session != null) {
                            Log.w("Shazam", "Session existiert bereits, überspringe neue Initialisierung")
                            // Alte Session sauber freigeben
                            try {
                                stopRecordingSafely()
                            } catch (e: Exception) {
                                Log.e("Shazam", "Fehler beim Freigeben alter Session: ${e.message}", e)
                            }
                            currentResult?.success(mapOf("title" to "", "artist" to ""))
                            currentResult = null
                            return@launch
                        }
                        
                        val createdSession = sessionResult.data as StreamingSession
                        session = createdSession
                        isRecording = true
                        matchFound = false
                        autoAdjustSent = false // Reset für neuen Scan
                        autoGainCalculated = false // Reset für neuen Scan - Berechnung startet neu
                        optimizedSensitivity = micSensitivity // Initialisiere mit aktueller Sensitivity
                        
                        try {
                            audioRecord?.startRecording()
                        } catch (e: Exception) {
                            Log.e("Shazam", "Fehler beim Starten der Audio-Aufnahme: ${e.message}", e)
                            session = null
                            currentResult?.error("AUDIO_ERROR", "Fehler beim Starten der Audio-Aufnahme: ${e.message}", null)
                            currentResult = null
                            return@launch
                        }

                        // Flow für Recognition-Ergebnisse abonnieren - MIT Crash-Vermeidung
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                createdSession.recognitionResults().collect { matchResult ->
                                    try {
                                        when (matchResult) {
                                            is MatchResult.Match -> {
                                                val firstMatch = matchResult.matchedMediaItems.firstOrNull()
                                                if (firstMatch != null && !matchFound) {
                                                    matchFound = true
                                                    
                                                    // AUTOMATIC GAIN & THRESHOLD MAPPING: Sende Werte vor dem Stoppen
                                                    if (smartThresholdEnabled && autoGainCalculated && !autoAdjustSent) {
                                                        autoAdjustSent = true
                                                        _sendAutoAdjustValuesWithRetry(lastOptimizedSensitivity, lastCalculatedThreshold)
                                                    }
                                                    
                                                    val resultData = mapOf(
                                                        "title" to (firstMatch.title ?: ""),
                                                        "artist" to (firstMatch.artist ?: "")
                                                    )
                                                    Log.d("Shazam", "GEFUNDEN: ${firstMatch.title} - ${firstMatch.artist}")
                                                    val resultToSend = currentResult
                                                    currentResult = null
                                                    resultToSend?.success(resultData)
                                                    stopRecording()
                                                }
                                            }
                                            is MatchResult.NoMatch -> {
                                                // NoMatch - keine Aktion, einfach weitermachen
                                                // Sende leere Antwort an Flutter, damit UI stabil bleibt
                                                Log.d("Shazam", "NoMatch - Kein Treffer, warte auf nächstes Scan-Intervall")
                                                
                                                // AUTOMATIC GAIN & THRESHOLD MAPPING: Sende Werte vor dem Stoppen
                                                if (smartThresholdEnabled && autoGainCalculated && !autoAdjustSent) {
                                                    autoAdjustSent = true
                                                    _sendAutoAdjustValuesWithRetry(lastOptimizedSensitivity, lastCalculatedThreshold)
                                                }
                                                
                                                val resultToSend = currentResult
                                                currentResult = null
                                                // Sende leere Daten statt Error, damit App weiterläuft
                                                resultToSend?.success(mapOf("title" to "", "artist" to ""))
                                                // Saubere Freigabe der Session bei NoMatch
                                                stopRecordingSafely()
                                            }
                                            is MatchResult.Error -> {
                                                // Fehler - prüfe spezifisch auf INVALID_SIGNATURE
                                                val errorMessage = matchResult.exception?.message ?: "Unbekannter Fehler"
                                                val ex = matchResult.exception
                                                Log.e(
                                                    "Shazam",
                                                    "MatchResult.Error (Apple/ShazamKit): message=$errorMessage cause=${ex?.cause?.message} type=${ex?.javaClass?.simpleName}",
                                                    ex,
                                                )
                                                
                                                // Prüfe ob es ein Token-Problem ist (inkl. ShazamKit UNAUTHORIZED / HTTP 401)
                                                val causeMsg = ex?.cause?.message ?: ""
                                                val isTokenError = errorMessage.contains("INVALID_SIGNATURE", ignoreCase = true) ||
                                                                   errorMessage.contains("invalid signature", ignoreCase = true) ||
                                                                   errorMessage.contains("UNAUTHORIZED", ignoreCase = true) ||
                                                                   errorMessage.contains("401", ignoreCase = true) ||
                                                                   causeMsg.contains("401", ignoreCase = true) ||
                                                                   errorMessage.contains("token", ignoreCase = true)
                                                
                                                val resultToSend = currentResult
                                                currentResult = null
                                                
                                                if (isTokenError) {
                                                    // Bei Token-Fehler: Sende spezifische Fehlermeldung
                                                    Log.e("Shazam", "⚠️ INVALID_SIGNATURE erkannt - Token muss erneuert werden!")
                                                    resultToSend?.success(mapOf(
                                                        "title" to "",
                                                        "artist" to "",
                                                        "error" to "INVALID_SIGNATURE",
                                                        "error_message" to "Apple Developer Token ungültig oder abgelaufen. Bitte Token erneuern."
                                                    ))
                                                } else {
                                                    // Andere Fehler: Sende leere Daten, damit App weiterläuft
                                                    resultToSend?.success(mapOf("title" to "", "artist" to ""))
                                                }
                                                
                                                // Saubere Freigabe der Session bei Fehler
                                                stopRecordingSafely()
                                            }
                                        }
                                    } catch (e: Exception) {
                                        // Catch für unerwartete Fehler innerhalb des matchResult-Handlers
                                        Log.e("Shazam", "Fehler bei MatchResult-Verarbeitung: ${e.message}", e)
                                        // Sende leere Antwort und stoppe Recording, aber beende App nicht
                                        val resultToSend = currentResult
                                        currentResult = null
                                        resultToSend?.success(mapOf("title" to "", "artist" to ""))
                                        stopRecordingSafely()
                                    }
                                }
                            } catch (e: Exception) {
                                // Catch für Fehler im collect-Block (z.B. Netzwerk-Timeout, Stille)
                                Log.e("Shazam", "Fehler im recognitionResults-Stream: ${e.message}", e)
                                // Sende leere Antwort, damit App weiterläuft und auf nächstes Intervall wartet
                                val resultToSend = currentResult
                                currentResult = null
                                resultToSend?.success(mapOf("title" to "", "artist" to ""))
                                stopRecordingSafely()
                            }
                        }

                        // Audio-Aufnahme in separatem Thread
                        withContext(Dispatchers.IO) {
                            // Fester Wert: 1792 Shorts = 3584 Bytes (exakt was Shazam erwartet)
                            val shortBuffer = ShortArray(bufferSize)
                            var lastRmsUpdateTime = 0L
                            
                            // Sammle RMS-Werte für Schwellenwert-Prüfung
                            val rmsValues = mutableListOf<Double>()
                            val rawRmsValues = mutableListOf<Double>() // AUTOMATIC GAIN & THRESHOLD MAPPING: Rohe RMS-Werte (ohne Sensitivity) für Gain-Anpassung
                            val scanStartTime = System.currentTimeMillis()
                            var blockStartTime = scanStartTime
                            val scanDurationMs = 8000L // 8 Sekunden
                            val smartThresholdDurationMs = 2000L // 2 Sekunden für Smart-Threshold
                            var shouldSendToShazam = true // Wird auf false gesetzt, wenn unter Schwellenwert
                            var smartThresholdCalculated = false // Wird auf true gesetzt, nachdem Smart-Threshold berechnet wurde
                            // autoGainCalculated und optimizedSensitivity sind jetzt auf Klassenebene definiert
                            while (!matchFound && isRecording) {
                                try {
                                    val readSize = audioRecord?.read(shortBuffer, 0, shortBuffer.size) ?: 0
                                    if (readSize > 0) {
                                        val rms = calculateRMS(shortBuffer, readSize)
                                        
                                        val currentTime = System.currentTimeMillis()
                                        val elapsedTime = currentTime - scanStartTime
                                        Log.d("VIBESBOX_DEBUG", "Zeit vergangen: $elapsedTime ms")
                                        
                                        // AUTOMATIC GAIN & THRESHOLD MAPPING: Dynamische Gain-Anpassung aus echten Pegel-Messungen
                                        if (smartThresholdEnabled && !autoGainCalculated && elapsedTime <= smartThresholdDurationMs) {
                                            rawRmsValues.add(rms.toDouble())
                                            if (elapsedTime >= smartThresholdDurationMs && rawRmsValues.isNotEmpty()) {
                                                val avgRaw = rawRmsValues.average().coerceAtLeast(1.0)
                                                val avgNormalizedBeforeAdjust = (avgRaw * micSensitivity / rmsNormalizationDivisor).coerceIn(0.0, 1.0)
                                                val isQuietSignal = avgNormalizedBeforeAdjust < 0.08
                                                val targetNormalized = if (isQuietSignal) 0.22 else 0.3
                                                val optimizedSens = (targetNormalized * rmsNormalizationDivisor / avgRaw).coerceIn(0.5, 2.0)
                                                val adaptiveThreshold = when {
                                                    isQuietSignal -> 0.12
                                                    avgNormalizedBeforeAdjust < 0.15 -> 0.18
                                                    else -> 0.25
                                                }
                                                lastOptimizedSensitivity = optimizedSens
                                                lastCalculatedThreshold = adaptiveThreshold
                                                optimizedSensitivity = optimizedSens
                                                micSensitivity = optimizedSensitivity // Wichtig: sofort auf Audio-Eingang anwenden
                                                recognitionThreshold = lastCalculatedThreshold
                                                autoGainCalculated = true
                                                Log.d("Shazam", "Auto-Gain: avgRaw=$avgRaw, avgNorm=$avgNormalizedBeforeAdjust, quiet=$isQuietSignal, optimizedSensitivity=$lastOptimizedSensitivity, threshold=$lastCalculatedThreshold")
                                            }
                                        } else if (!smartThresholdEnabled && !smartThresholdCalculated) {
                                            // Manueller Modus: Verwende manuellen Schwellenwert
                                            recognitionThreshold = manualThreshold
                                            smartThresholdCalculated = true
                                        }
                                        
                                        // Wende optimierte Sensitivity an und normalisiere auf 0.0-1.0
                                        val normalizedRms = (rms * micSensitivity / rmsNormalizationDivisor).coerceIn(0.0, 1.0)
                                        
                                        // Blockweise RMS sammeln und regelmäßig gegen Threshold prüfen.
                                        rmsValues.add(normalizedRms)
                                        val blockElapsed = currentTime - blockStartTime
                                        val canCheckThreshold = blockElapsed >= scanDurationMs && shouldSendToShazam &&
                                                !(smartThresholdEnabled && elapsedTime < smartThresholdDurationMs)

                                        if (canCheckThreshold) {
                                            val averageRms = if (rmsValues.isNotEmpty()) {
                                                rmsValues.average()
                                            } else {
                                                0.0
                                            }

                                            if (averageRms < recognitionThreshold) {
                                                if (smartThresholdEnabled) {
                                                    val previousSensitivity = micSensitivity
                                                    val increasedSensitivity = (previousSensitivity * 1.25).coerceIn(0.5, 2.0)
                                                    val loweredThreshold = maxOf(0.05, (averageRms * 1.8).coerceAtMost(0.25))
                                                    micSensitivity = increasedSensitivity
                                                    optimizedSensitivity = increasedSensitivity
                                                    lastOptimizedSensitivity = increasedSensitivity
                                                    recognitionThreshold = loweredThreshold
                                                    lastCalculatedThreshold = loweredThreshold
                                                    autoGainCalculated = true
                                                    _sendAutoAdjustValuesWithRetry(lastOptimizedSensitivity, lastCalculatedThreshold)

                                                    Log.w(
                                                        "Shazam",
                                                        "[Smart-Adjust] Erhöhe micSensitivity auf ${String.format("%.2f", increasedSensitivity)} wegen leisem Pegel (${String.format("%.3f", averageRms)}). Neuer Threshold: ${String.format("%.3f", loweredThreshold)}"
                                                    )

                                                    // WICHTIG: Bei Smart-Adjust nicht abbrechen, sondern nächsten Block neu bewerten.
                                                    rmsValues.clear()
                                                    blockStartTime = currentTime
                                                } else {
                                                    // Manueller Modus: Durchschnitt unter Schwellenwert -> Scan verwerfen
                                                    Log.w("Shazam", "❌ Scan verworfen - Signal zu leise (Durchschnitt: ${String.format("%.3f", averageRms)}, Schwellenwert: ${String.format("%.3f", recognitionThreshold)})")
                                                    shouldSendToShazam = false
                                                    isRecording = false

                                                    // Sende leere Antwort an Flutter
                                                    Handler(Looper.getMainLooper()).post {
                                                        val resultToSend = currentResult
                                                        currentResult = null
                                                        resultToSend?.success(mapOf("title" to "", "artist" to ""))
                                                    }

                                                    // Stoppe Recording
                                                    stopRecordingSafely()
                                                    break
                                                }
                                            } else {
                                                Log.d("Shazam", "✅ Signal ausreichend laut (Durchschnitt: ${String.format("%.3f", averageRms)}, Schwellenwert: ${String.format("%.3f", recognitionThreshold)}) - Scan läuft weiter")
                                                rmsValues.clear()
                                                blockStartTime = currentTime
                                            }
                                        }
                                        
                                        // Sende normalisierten RMS-Wert alle 50ms (20 Updates pro Sekunde)
                                        val sink = rmsEventSink
                                        if (sink != null && (currentTime - lastRmsUpdateTime) >= 50) {
                                            lastRmsUpdateTime = currentTime
                                            Handler(Looper.getMainLooper()).post {
                                                try {
                                                    sink.success(normalizedRms)
                                                } catch (e: Exception) {
                                                    Log.e("Shazam", "Fehler beim Senden von RMS: ${e.message}", e)
                                                }
                                            }
                                        }
                                        
                                        // Nur an Shazam senden, wenn Signal laut genug ist
                                        if (shouldSendToShazam) {
                                            // Konvertiere ShortArray zu ByteArray (2 Bytes pro Short)
                                            val byteBuffer = ByteBuffer.allocate(readSize * 2).order(ByteOrder.LITTLE_ENDIAN)
                                            byteBuffer.asShortBuffer().put(shortBuffer, 0, readSize)
                                            val bytes = byteBuffer.array()

                                            // Jetzt sind 'bytes.size' exakt 3584 (oder weniger)
                                            try {
                                                createdSession.matchStream(bytes, bytes.size, System.currentTimeMillis())
                                                Log.d("Shazam", "Höre zu... Pegel: $rms")
                                            } catch (e: Exception) {
                                                Log.e("Shazam", "Fehler bei matchStream: ${e.message}", e)
                                                // Bei Fehler stoppe Recording sauber
                                                break
                                            }
                                        }
                                    }
                                } catch (e: Exception) {
                                    Log.e("Shazam", "Fehler beim Audio-Read: ${e.message}", e)
                                    // Bei Fehler in der Audio-Schleife: stoppe Recording, aber beende Service nicht
                                    break
                                }
                            }
                        }
                    }
                    is ShazamKitResult.Failure -> {
                        val exception = sessionResult.reason
                        Log.e("Shazam", "Session-Fehler: ${exception.message}")
                        currentResult?.error("SESSION_ERROR", exception.message, null)
                        currentResult = null
                    }
                }
            } catch (e: Exception) {
                Log.e("Shazam", "Fehler bei Session-Erstellung: ${e.message}", e)
                currentResult?.error("EXCEPTION", e.message, null)
                currentResult = null
            }
        }
    }

    private fun captureAudioSignatureOnly() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val localAudio = audioRecord
                if (localAudio == null || localAudio.state != AudioRecord.STATE_INITIALIZED) {
                    withContext(Dispatchers.Main) {
                        currentResult?.error("AUDIO_ERROR", "AudioRecord nicht initialisiert", null)
                        currentResult = null
                    }
                    return@launch
                }

                isRecording = true
                matchFound = false
                localAudio.startRecording()

                val signatureDurationMs = 8000L
                val signatureStartMs = System.currentTimeMillis()
                val shortBuffer = ShortArray(bufferSize)
                val endAt = System.currentTimeMillis() + signatureDurationMs
                var lastRmsUpdateTime = 0L
                var collectedAudioBytes = 0
                
                // Nutze den echten ShazamKit SignatureGenerator (Fingerprint),
                // NICHT rohe PCM-Bytes als "Signatur".
                val signatureGeneratorResult = ShazamKit.createSignatureGenerator(
                    AudioSampleRateInHz.SAMPLE_RATE_44100,
                )
                val signatureGenerator = when (signatureGeneratorResult) {
                    is ShazamKitResult.Success<*> -> signatureGeneratorResult.data as SignatureGenerator
                    is ShazamKitResult.Failure -> {
                        val reason = signatureGeneratorResult.reason?.message ?: "Unbekannter Fehler"
                        Log.e("Shazam", "SignatureGenerator konnte nicht erstellt werden: $reason")
                        withContext(Dispatchers.Main) {
                            val resultToSend = currentResult
                            currentResult = null
                            resultToSend?.success(mapOf("title" to "", "artist" to ""))
                        }
                        stopRecordingSafely()
                        return@launch
                    }
                }

                while (isRecording && System.currentTimeMillis() < endAt) {
                    val readSize = localAudio.read(shortBuffer, 0, shortBuffer.size)
                    if (readSize > 0) {
                        // Während der Signature-Aufnahme weiterhin Live-RMS an Flutter senden
                        val rms = calculateRMS(shortBuffer, readSize)
                        val normalizedRms = (rms * micSensitivity / rmsNormalizationDivisor).coerceIn(0.0, 1.0)
                        val now = System.currentTimeMillis()
                        if ((now - lastRmsUpdateTime) >= 50) {
                            lastRmsUpdateTime = now
                            val sink = rmsEventSink
                            if (sink != null) {
                                Handler(Looper.getMainLooper()).post {
                                    try {
                                        sink.success(normalizedRms)
                                    } catch (e: Exception) {
                                        Log.e("Shazam", "Fehler beim Senden von RMS (Signature-Flow): ${e.message}", e)
                                    }
                                }
                            }
                        }

                        val byteBuffer = ByteBuffer.allocate(readSize * 2).order(ByteOrder.LITTLE_ENDIAN)
                        byteBuffer.asShortBuffer().put(shortBuffer, 0, readSize)
                        val bytes = byteBuffer.array()
                        signatureGenerator.append(bytes, bytes.size, System.currentTimeMillis())
                        collectedAudioBytes += bytes.size
                    }
                }

                val signatureBytes = signatureGenerator.generateSignature().dataRepresentation
                val signature = if (signatureBytes.isEmpty()) "" else Base64.encodeToString(signatureBytes, Base64.NO_WRAP)
                val elapsedMs = System.currentTimeMillis() - signatureStartMs
                Log.d("Shazam", "DEBUG: Gesammelte Audiodaten: $collectedAudioBytes Bytes (Aufnahme: ${elapsedMs}ms).")
                Log.d("Shazam", "ShazamKit-Fingerprint erzeugt: rawBytes=${signatureBytes.size}, base64Length=${signature.length}.")
                if (signatureBytes.size > 100 * 1024) {
                    Log.w("Shazam", "WARNUNG: Signatur ist größer als erwartet (>100KB).")
                }
                if (signature.length < 500) {
                    Log.w("Shazam", "DEBUG: Signatur zu kurz!")
                }

                stopRecordingSafely()

                withContext(Dispatchers.Main) {
                    val resultToSend = currentResult
                    currentResult = null
                    resultToSend?.success(
                        mapOf(
                            "title" to "",
                            "artist" to "",
                            "signature" to signature
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e("Shazam", "Fehler bei Signature-Capture: ${e.message}", e)
                stopRecordingSafely()
                withContext(Dispatchers.Main) {
                    val resultToSend = currentResult
                    currentResult = null
                    resultToSend?.success(mapOf("title" to "", "artist" to ""))
                }
            }
        }
    }
    
    private fun calculateRMS(buffer: ShortArray, readSize: Int): Double {
        var sum = 0.0
        for (i in 0 until readSize) {
            val sample = buffer[i].toDouble()
            sum += sample * sample
        }
        return Math.sqrt(sum / readSize)
    }
    
    /// Sendet Auto-Adjust Werte an Flutter mit Retry-Logik
    /// Falls der Sink noch nicht bereit ist, versucht es alle 500ms erneut (max. 10 Versuche = 5 Sekunden)
    private fun _sendAutoAdjustValuesWithRetry(micSensitivity: Double, recognitionThreshold: Double) {
        val maxRetries = 10 // Max. 10 Versuche = 5 Sekunden
        var retryCount = 0
        
        fun trySend() {
            val adjustSink = autoAdjustEventSink
            Log.d("VIBESBOX_DEBUG", "Sende Daten an Flutter (Versuch ${retryCount + 1}/$maxRetries): mic_sensitivity=$micSensitivity, recognition_threshold=$recognitionThreshold")
            
            if (adjustSink != null) {
                // Den Sende-Befehl auf den Main-Thread zwingen
                Handler(Looper.getMainLooper()).post {
                    try {
                        autoAdjustEventSink?.success(mapOf(
                            "mic_sensitivity" to micSensitivity,
                            "recognition_threshold" to recognitionThreshold
                        ))
                        Log.i("VIBESBOX_SIGNAL", "✅ Signal auf Main-Thread erfolgreich abgesetzt")
                    } catch (e: Exception) {
                        Log.e("VIBESBOX_SIGNAL", "❌ Fehler auf Main-Thread: ${e.message}")
                    }
                }
            } else {
                retryCount++
                if (retryCount < maxRetries) {
                    Log.w("VIBESBOX_DEBUG", "⚠️ Sink ist noch NULL (Versuch $retryCount/$maxRetries) - Wiederhole in 500ms...")
                    Handler(Looper.getMainLooper()).postDelayed({
                        trySend()
                    }, 500) // Warte 500ms vor nächstem Versuch
                } else {
                    Log.e("VIBESBOX_DEBUG", "FEHLER: Kann nicht senden, Sink ist nach $maxRetries Versuchen immer noch NULL!")
                }
            }
        }
        
        trySend()
    }
    
    private fun stopRecording() {
        stopRecordingSafely()
    }
    
    private fun stopRecordingSafely() {
        // Prüfe AudioRecord-Status bevor wir Flags setzen
        val wasRecording = isRecording
        
        // Setze Flags
        isRecording = false
        matchFound = false
        
        // Sende 0.0 an RMS-Stream, damit Pegelanzeige auf Null geht (Mikrofon wird geschlossen)
        val sink = rmsEventSink
        if (sink != null) {
            Handler(Looper.getMainLooper()).post {
                try {
                    sink.success(0.0)
                } catch (e: Exception) {
                    Log.e("Shazam", "Fehler beim Senden von RMS 0.0: ${e.message}", e)
                }
            }
        }
        
        // Saubere Freigabe der Session mit try-catch
        val currentSession = session
        if (currentSession != null) {
            try {
                // Versuche Session zu schließen (falls Methode existiert)
                Log.d("Shazam", "Beende Session sauber...")
                // ShazamKit hat keine explizite close() Methode, Session wird automatisch freigegeben
                // Setze nur auf null, um Doppel-Freigabe zu vermeiden
                session = null
                Log.d("Shazam", "Session erfolgreich freigegeben")
            } catch (e: Exception) {
                Log.e("Shazam", "Fehler beim Beenden der Session: ${e.message}", e)
                // Auch bei Fehler Session auf null setzen, um Doppel-Freigabe zu vermeiden
                session = null
            }
        }
        
        // Stoppe AudioRecord falls noch aktiv
        if (audioRecord != null) {
            try {
                if (wasRecording) {
                    audioRecord?.stop()
                }
                audioRecord?.release()
            } catch (e: Exception) {
                Log.e("Shazam", "Fehler beim Freigeben des AudioRecord: ${e.message}", e)
            }
            audioRecord = null
        }
        
        Log.d("Shazam", "Mikrofon komplett geschlossen - kein permanentes Icon mehr")
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true // Vor Android 6.0 gibt es keine Batterie-Optimierung
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }
    
    private fun startForegroundService(showStatusNotification: Boolean, notificationTitle: String?, notificationListening: String?): Boolean {
        if (!showStatusNotification) {
            // Falls während laufender Erkennung deaktiviert: Leiste sofort entfernen.
            stopForegroundService()
            return true
        }
        if (!checkAudioPermission()) {
            Log.w("Shazam", "startForegroundService: RECORD_AUDIO nicht gewährt – Service wird nicht gestartet (Crash-Vermeidung)")
            return false
        }
        try {
            // Erstelle Notification Channel (Android 8.0+)
            ShazamForegroundService.createNotificationChannel(this)
            
            val serviceIntent = Intent(this, ShazamForegroundService::class.java).apply {
                if (!notificationTitle.isNullOrBlank()) {
                    putExtra("notification_title", notificationTitle)
                }
                if (!notificationListening.isNullOrBlank()) {
                    putExtra("notification_listening", notificationListening)
                }
            }
            
            // Android 14+ (API 34+) benötigt foregroundServiceType
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // foregroundServiceType wird im Manifest definiert, hier nur Intent vorbereiten
                Log.d("Shazam", "Foreground Service mit Mikrofon-Typ (Android 14+)")
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d("Shazam", "Foreground Service gestartet (mit Mikrofon-Typ)")
            // KEIN kontinuierlicher RMS-Stream mehr - Mikrofon wird nur während Scans aktiviert
            return true
        } catch (se: SecurityException) {
            Log.e(
                "Shazam",
                "Foreground Service Start blockiert (z. B. Android 15 Hintergrund-Restriktion): ${se.message}",
                se
            )
            return false
        } catch (e: Exception) {
            Log.e("Shazam", "Fehler beim Starten des Foreground Service: ${e.message}", e)
            return false
        }
    }
    
    /// Startet kontinuierlichen RMS-Stream (unabhängig von Shazam-Scans)
    private fun startContinuousRmsStream() {
        if (isRmsRecording || rmsAudioRecord != null) {
            Log.d("Shazam", "RMS-Stream läuft bereits")
            return
        }
        
        if (!checkAudioPermission()) {
            Log.e("Shazam", "Keine Audio-Berechtigung für RMS-Stream")
            return
        }
        
        val sampleRate = 44100
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        
        if (bufferSize == AudioRecord.ERROR_BAD_VALUE || bufferSize == AudioRecord.ERROR) {
            Log.e("Shazam", "RMS-Stream: AudioRecord Buffer Size Error")
            return
        }
        
        rmsAudioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            channelConfig,
            audioFormat,
            bufferSize
        )
        
        if (rmsAudioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            Log.e("Shazam", "RMS-Stream: AudioRecord Initialization Failed")
            rmsAudioRecord = null
            return
        }
        
        isRmsRecording = true
        rmsAudioRecord?.startRecording()
        
        // Starte Thread für kontinuierliche RMS-Berechnung
        rmsRecordingThread = Thread {
            val shortBuffer = ShortArray(bufferSize / 2)
            while (isRmsRecording && rmsAudioRecord != null) {
                try {
                    val readSize = rmsAudioRecord?.read(shortBuffer, 0, shortBuffer.size) ?: 0
                    if (readSize > 0) {
                        val rms = calculateRMS(shortBuffer, readSize)
                        
                        // Wende Sensitivity an und normalisiere auf 0.0-1.0
                        val normalizedRms = (rms * micSensitivity / rmsNormalizationDivisor).coerceIn(0.0, 1.0)
                        
                        // Sende normalisierten RMS-Wert IMMER (auch wenn kein Scan aktiv ist)
                        // Dies ermöglicht die Pegelanzeige im Profil und Footer
                        val sink = rmsEventSink
                        if (sink != null) {
                            Handler(Looper.getMainLooper()).post {
                                try {
                                    sink.success(normalizedRms)
                                } catch (e: Exception) {
                                    Log.e("Shazam", "Fehler beim Senden von RMS: ${e.message}", e)
                                }
                            }
                        }
                    }
                    // Kleine Pause, um CPU nicht zu überlasten
                    try {
                        Thread.sleep(50) // ~20 Updates pro Sekunde
                    } catch (e: InterruptedException) {
                        // Thread wurde unterbrochen - normal beim Stoppen
                        Log.d("Shazam", "RMS-Stream Thread unterbrochen (normal)")
                        break
                    }
                } catch (e: Exception) {
                    if (e is InterruptedException) {
                        // Thread wurde unterbrochen - normal beim Stoppen
                        Log.d("Shazam", "RMS-Stream Thread unterbrochen (normal)")
                        break
                    } else {
                        Log.e("Shazam", "Fehler im RMS-Stream: ${e.message}", e)
                        break
                    }
                }
            }
        }
        rmsRecordingThread?.start()
        Log.d("Shazam", "Kontinuierlicher RMS-Stream gestartet")
    }
    
    /// Stoppt kontinuierlichen RMS-Stream
    private fun stopContinuousRmsStream() {
        isRmsRecording = false
        
        rmsRecordingThread?.interrupt()
        rmsRecordingThread = null
        
        try {
            rmsAudioRecord?.stop()
            rmsAudioRecord?.release()
        } catch (e: Exception) {
            Log.e("Shazam", "Fehler beim Stoppen des RMS-Streams: ${e.message}", e)
        }
        rmsAudioRecord = null
        Log.d("Shazam", "Kontinuierlicher RMS-Stream gestoppt")
    }
    
    private fun stopForegroundService() {
        // Sende 0.0 an RMS-Stream, damit Pegelanzeige auf Null geht
        val sink = rmsEventSink
        if (sink != null) {
            Handler(Looper.getMainLooper()).post {
                try {
                    sink.success(0.0)
                } catch (e: Exception) {
                    Log.e("Shazam", "Fehler beim Senden von RMS 0.0: ${e.message}", e)
                }
            }
        }
        
        try {
            ShazamForegroundService.requestStop(this)
            val serviceIntent = Intent(this, ShazamForegroundService::class.java)
            stopService(serviceIntent)
            Log.d("Shazam", "Foreground Service gestoppt")
        } catch (e: Exception) {
            Log.e("Shazam", "Fehler beim Stoppen des Foreground Service: ${e.message}", e)
        }
    }

    private fun isShazamForegroundServiceRunning(): Boolean {
        return try {
            val manager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
            manager.getRunningServices(Int.MAX_VALUE).any {
                it.service.className == ShazamForegroundService::class.java.name
            }
        } catch (e: Exception) {
            Log.w("Shazam", "isShazamForegroundServiceRunning fehlgeschlagen: ${e.message}")
            false
        }
    }
}
