package com.arturwarlord.vpnclient

import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.IOException

/**
 * Android side of the OpenVPN 3 TUN-builder bridge.
 *
 * The native OpenVPN client owns the detached file descriptor returned by
 * establishTun(). This service deliberately does not start a session itself:
 * the native OpenVPNClient subclass and profile/credential pipeline must be
 * connected before the UI can expose an OpenVPN Connect action.
 */
class OpenVpnVpnService : VpnService() {
    companion object {
        private const val TAG = "FreeRouteOpenVPN"
    }

    /**
     * Called by the native TunBuilder callback after OpenVPN has supplied the
     * complete interface configuration. Returns a detached fd, or -1.
     *
     * addresses/routes are paired with prefix lengths by index. Invalid or
     * mismatched input is rejected rather than silently creating a partial VPN.
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
