package com.arturwarlord.vpnclient

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log

/**
 * Android service boundary for OpenVPN 3.
 *
 * The foreground lifecycle is deliberately separate from native session startup:
 * this phase proves notification/service ownership only. It does not connect.
 */
class OpenVpnVpnService : VpnService() {
    companion object {
        private const val TAG = "FreeRouteOpenVPN"
        private const val CHANNEL_ID = "freeroute_openvpn"
        private const val NOTIFICATION_ID = 3201

        const val ACTION_START_FOREGROUND = "com.arturwarlord.vpnclient.OPENVPN_START_FOREGROUND"
        const val ACTION_STOP = "com.arturwarlord.vpnclient.OPENVPN_STOP"
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_FOREGROUND -> startForegroundSession()
            ACTION_STOP -> stopForegroundSession()
            else -> {
                Log.w(TAG, "Ignored unsupported service action")
                stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundSession() {
        // Consent must be granted by the Activity before the service is started.
        if (VpnService.prepare(this) != null) {
            Log.w(TAG, "VPN consent is missing; refusing to start foreground session")
            stopSelf()
            return
        }

        createNotificationChannel()
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Unable to enter foreground state", error)
            stopSelf()
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, OpenVpnVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle("FreeRoute · OpenVPN")
            .setContentText("Служба VPN активна; подключение ещё не запущено")
            .setContentIntent(openAppIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_pause,
                    "Остановить",
                    stopIntent
                ).build()
            )
            .build()
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "FreeRoute OpenVPN",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Постоянное уведомление службы OpenVPN"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundSession() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onRevoke() {
        stopForegroundSession()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    /**
     * Called by the native TunBuilder callback after OpenVPN has supplied the
     * complete interface configuration. Returns a detached fd, or -1.
     */
    @Suppress("unused")
    fun establishTun(
        addresses: Array<String>,
        addressPrefixes: IntArray,
        routes: Array<String>,
        routePrefixes: IntArray,
        dnsServers: Array<String>,
        mtu: Int,
        sessionName: String
    ): Int {
        if (addresses.isEmpty() || addresses.size != addressPrefixes.size ||
            routes.size != routePrefixes.size || mtu !in 576..9000
        ) {
            Log.e(TAG, "Rejected invalid TUN configuration")
            return -1
        }

        return try {
            val builder = Builder()
                .setSession(sessionName.take(64).ifBlank { "FreeRoute OpenVPN" })
                .setMtu(mtu)

            addresses.forEachIndexed { index, address ->
                val prefix = addressPrefixes[index]
                if (prefix !in 0..(if (address.contains(':')) 128 else 32)) {
                    throw IllegalArgumentException("Invalid interface prefix")
                }
                builder.addAddress(address, prefix)
            }

            routes.forEachIndexed { index, route ->
                val prefix = routePrefixes[index]
                if (prefix !in 0..(if (route.contains(':')) 128 else 32)) {
                    throw IllegalArgumentException("Invalid route prefix")
                }
                builder.addRoute(route, prefix)
            }

            dnsServers.forEach { dns ->
                if (dns.isNotBlank()) builder.addDnsServer(dns)
            }

            val descriptor = builder.establish() ?: return -1
            descriptor.detachFd()
        } catch (error: Exception) {
            Log.e(TAG, "Unable to establish Android TUN interface", error)
            -1
        }
    }

    /** OpenVPN transport sockets must bypass this VPN to avoid routing loops. */
    @Suppress("unused")
    fun protectSocketDescriptor(fd: Int): Boolean {
        if (fd < 0) return false
        return protect(fd)
    }
}
