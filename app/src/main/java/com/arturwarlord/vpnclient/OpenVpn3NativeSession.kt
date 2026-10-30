package com.arturwarlord.vpnclient

import java.io.Closeable
import java.util.concurrent.atomic.AtomicLong

/**
 * Owns one native OpenVPN client callback object bound to a live VpnService.
 *
 * Profile evaluation is performed by the same native OpenVPNClient instance
 * that will later own credentials and the connection lifecycle. This class
 * still does not start a tunnel.
 */
internal class OpenVpn3NativeSession(
    vpnService: OpenVpnVpnService
) : Closeable {
    private val nativeHandle = AtomicLong(nativeCreate(vpnService))

    init {
        check(nativeHandle.get() != 0L) {
            "Unable to initialize the native OpenVPN service bridge"
        }
    }

    @Synchronized
    fun evaluateProfile(profileText: String): Boolean {
        val handle = nativeHandle.get()
        if (handle == 0L || profileText.isBlank()) return false
        return nativeEvaluateProfile(handle, profileText)
    }

    @Synchronized
    override fun close() {
        val handle = nativeHandle.getAndSet(0L)
        if (handle != 0L) nativeDestroy(handle)
    }

    private external fun nativeCreate(vpnService: OpenVpnVpnService): Long
    private external fun nativeEvaluateProfile(handle: Long, profileText: String): Boolean
    private external fun nativeDestroy(handle: Long)

    companion object {
        init {
            System.loadLibrary("freeroute_openvpn3")
        }
    }
}
