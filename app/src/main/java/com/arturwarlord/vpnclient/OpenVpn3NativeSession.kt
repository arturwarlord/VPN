package com.arturwarlord.vpnclient

import java.io.Closeable
import java.util.concurrent.atomic.AtomicLong

/**
 * Owns one native OpenVPN client callback object bound to a live VpnService.
 *
 * This is an internal JNI lifecycle primitive only. It does not evaluate a
 * profile, establish TUN, or start an OpenVPN connection.
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

    override fun close() {
        val handle = nativeHandle.getAndSet(0L)
        if (handle != 0L) nativeDestroy(handle)
    }

    private external fun nativeCreate(vpnService: OpenVpnVpnService): Long
    private external fun nativeDestroy(handle: Long)

    companion object {
        init {
            System.loadLibrary("freeroute_openvpn3")
        }
    }
}
