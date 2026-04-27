package com.vibesbox.dj

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class ShazamForegroundService : Service() {

    /** Ab Android 14 (API 34): [startForeground] muss den FGS-Typ „Mikrofon“ angeben (Manifest: foregroundServiceType). */
    private fun startForegroundWithMicType(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val CHANNEL_ID = "shazam_service"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_UPDATE_NOTIFICATION = "com.android.application.UPDATE_NOTIFICATION"
        private const val ACTION_UPDATE_NOTIFICATION_VISIBILITY = "com.android.application.UPDATE_NOTIFICATION_VISIBILITY"
        private const val ACTION_STOP = "com.android.application.STOP_FOREGROUND_SERVICE"
        private const val EXTRA_VISIBLE = "visible"
        private const val EXTRA_NOTIFICATION_TITLE = "notification_title"
        private const val EXTRA_NOTIFICATION_LISTENING = "notification_listening"
        private const val EXTRA_CONTENT_TEXT = "content_text"
        private const val EXTRA_NAV_TARGET = "nav_target"
        private const val NAV_TARGET_HISTORY = "history"
        @Volatile private var currentNotificationTitle: String = "VibesBox Musikerkennung"
        @Volatile private var currentListeningText: String = "Höre gerade zu..."
        
        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
                // Falls Kanal jemals auf MIN angelegt wurde, neu mit sichtbarer Priorität anlegen.
                if (existing != null && existing.importance < NotificationManager.IMPORTANCE_LOW) {
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                }
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Musikerkennung",
                    NotificationManager.IMPORTANCE_LOW // Sichtbar in Statusleiste, ohne aufdringlich zu sein
                ).apply {
                    description = "System-Notification für Musikerkennung"
                    setShowBadge(false)
                    setSound(null, null) // Kein Sound
                    enableVibration(false) // Keine Vibration
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
        
        /** Aktualisiert die laufende Notification mit lokalisiertem Text (von Flutter). contentText = null → Standard „läuft“. */
        fun updateNotification(context: Context, notificationTitle: String?, contentText: String?, navigationTarget: String?) {
            val intent = Intent(context, ShazamForegroundService::class.java).apply {
                action = ACTION_UPDATE_NOTIFICATION
                putExtra(EXTRA_NOTIFICATION_TITLE, notificationTitle)
                putExtra(EXTRA_CONTENT_TEXT, contentText)
                putExtra(EXTRA_NAV_TARGET, navigationTarget)
            }
            context.startService(intent)
        }

        /**
         * Erzwingt ein sofortiges Content-Update (Zeile 2) auf bestehender Notification-ID.
         * Wird beim Locale-Wechsel genutzt und ruft unmittelbar notificationManager.notify() aus.
         */
        fun updateNotificationContent(context: Context, notificationTitle: String?, contentText: String?) {
            updateNotification(context, notificationTitle, contentText, null)
        }

        fun updateNotificationVisibility(
            context: Context,
            visible: Boolean,
            notificationTitle: String?,
            notificationListening: String?,
        ) {
            val intent = Intent(context, ShazamForegroundService::class.java).apply {
                action = ACTION_UPDATE_NOTIFICATION_VISIBILITY
                putExtra(EXTRA_VISIBLE, visible)
                putExtra(EXTRA_NOTIFICATION_TITLE, notificationTitle)
                putExtra(EXTRA_NOTIFICATION_LISTENING, notificationListening)
            }
            context.startService(intent)
        }

        fun applyNotificationVisibilityNow(
            context: Context,
            visible: Boolean,
            notificationTitle: String?,
            notificationListening: String?,
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createNotificationChannel(context)
            }
            if (!notificationTitle.isNullOrBlank()) {
                currentNotificationTitle = notificationTitle
            }
            if (!notificationListening.isNullOrBlank()) {
                currentListeningText = notificationListening
            }
            val notificationManager =
                context.getSystemService(NotificationManager::class.java)
            if (visible) {
                val tapIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                    action = MainActivity.ACTION_OPEN_APP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    2001,
                    tapIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setContentTitle(currentNotificationTitle)
                    .setContentText(currentListeningText)
                    .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                    .setOngoing(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setCategory(NotificationCompat.CATEGORY_SERVICE)
                    .setSilent(true)
                    .setShowWhen(false)
                    .setContentIntent(pendingIntent)
                    .build()
                notificationManager.notify(NOTIFICATION_ID, notification)
            } else {
                removeNotificationCompletely(notificationManager)
            }
        }

        fun requestStop(context: Context) {
            val stopIntent = Intent(context, ShazamForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(stopIntent)
        }

        private fun removeNotificationCompletely(notificationManager: NotificationManager) {
            notificationManager.cancel(NOTIFICATION_ID)
            val stillActive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                notificationManager.activeNotifications.any { it.id == NOTIFICATION_ID }
            } else {
                false
            }
            if (stillActive) {
                // Safety-Fallback bei kollidierenden IDs/inkonsistentem Systemzustand
                notificationManager.cancelAll()
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // WICHTIG: Stelle sicher, dass der Service den App-ClassLoader nutzt
        // Der Service läuft im selben Prozess wie die App und nutzt automatisch den App-ClassLoader
        // Keine isolierten Threads ohne ClassLoader-Zugriff
        
        createNotificationChannel(this)
        
        // Android 12+ / 14: Nach startForegroundService() MUSS startForeground() zeitnah erfolgen.
        // Ohne startForeground() → ForegroundServiceDidNotStartInTimeException (Crash).
        // Immer zuerst Platzhalter-Notification anzeigen, dann bei fehlender Berechtigung wieder beenden.
        startForegroundWithMicType(createNotification(null, null))
        if (!hasMicrophonePermission()) {
            Log.w(
                "ShazamForegroundService",
                "Mikrofon-Berechtigung fehlt – beende Vordergrunddienst (startForeground wurde bereits gesetzt)"
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(Service.STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!hasMicrophonePermission()) {
            Log.w("ShazamForegroundService", "Mikrofon-Berechtigung fehlt – stoppe Service")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(Service.STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }
        
        if (intent?.action == ACTION_UPDATE_NOTIFICATION) {
            val notificationTitle = intent.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            val contentText = intent.getStringExtra(EXTRA_CONTENT_TEXT)
            val navigationTarget = intent.getStringExtra(EXTRA_NAV_TARGET)
            if (!notificationTitle.isNullOrBlank()) {
                currentNotificationTitle = notificationTitle
            }
            val notification = createNotification(contentText, navigationTarget)
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, notification)
        } else if (intent?.action == ACTION_UPDATE_NOTIFICATION_VISIBILITY) {
            val visible = intent.getBooleanExtra(EXTRA_VISIBLE, false)
            val notificationTitle = intent.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            val notificationListening = intent.getStringExtra(EXTRA_NOTIFICATION_LISTENING)
            if (!notificationTitle.isNullOrBlank()) {
                currentNotificationTitle = notificationTitle
            }
            if (!notificationListening.isNullOrBlank()) {
                currentListeningText = notificationListening
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            if (visible) {
                val notification = createNotification(currentListeningText, null)
                notificationManager.notify(NOTIFICATION_ID, notification)
            } else {
                removeNotificationCompletely(notificationManager)
            }
        } else if (intent?.action == ACTION_STOP) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            removeNotificationCompletely(notificationManager)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(Service.STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        } else {
            val startTitle = intent?.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            val startListening = intent?.getStringExtra(EXTRA_NOTIFICATION_LISTENING)
            if (!startTitle.isNullOrBlank()) {
                currentNotificationTitle = startTitle
            }
            if (!startListening.isNullOrBlank()) {
                currentListeningText = startListening
            }
            // Sicherstellen: weiterhin als Foreground (nach Prozess-Neustart o. ä.)
            startForegroundWithMicType(createNotification(null, null))
        }
        return START_STICKY // Service soll neu starten, wenn er vom System beendet wird
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    private fun createNotification(contentText: String?, navigationTarget: String?): Notification {
        val text = if (!contentText.isNullOrBlank()) contentText else currentListeningText
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (navigationTarget == NAV_TARGET_HISTORY) {
                action = MainActivity.ACTION_OPEN_HISTORY
                putExtra(MainActivity.EXTRA_NAV_TARGET, NAV_TARGET_HISTORY)
            } else {
                action = MainActivity.ACTION_OPEN_APP
            }
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            if (navigationTarget == NAV_TARGET_HISTORY) 2002 else 2001,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentNotificationTitle)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Niedrige Priorität, aber sichtbar
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setSilent(true) // Kein Sound
            .setShowWhen(false) // Keine Zeit anzeigen
            .setContentIntent(pendingIntent)
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }
    
    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
}

