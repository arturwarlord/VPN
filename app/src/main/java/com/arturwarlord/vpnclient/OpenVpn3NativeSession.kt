package com.arturwarlord.vpnclient

import java.io.Closeable
import java.util.concurrent.atomic.AtomicLong

/** Internal native OpenVPN session owner. Not connected to the UI yet. */
internal class OpenVpn3NativeSession(vpnService: OpenVpnVpnService) : Closeable {
    private val nativeHandle = AtomicLong(nativeCreate(vpnService))
    init { check(nativeHandle.get() != 0L) { "Unable to initialize native OpenVPN bridge" } }

    @Synchronized
    fun evaluateProfile(profileText: String): Boolean {
        val handle=nativeHandle.get()
        return handle!=0L && profileText.isNotBlank() && nativeEvaluateProfile(handle,profileText)
    }

    /** Call only after VPN consent and while the service is in foreground. */
    @Synchronized
    fun start(username:String="",password:String=""):Boolean {
        val handle=nativeHandle.get()
        return handle!=0L && nativeStart(handle,username,password)
    }

    @Synchronized
    fun stop() { val handle=nativeHandle.get(); if(handle!=0L) nativeStop(handle) }

    @Synchronized
    override fun close() { val handle=nativeHandle.getAndSet(0L);if(handle!=0L)nativeDestroy(handle) }

    private external fun nativeCreate(vpnService:OpenVpnVpnService):Long
    private external fun nativeEvaluateProfile(handle:Long,profileText:String):Boolean
    private external fun nativeStart(handle:Long,username:String,password:String):Boolean
    private external fun nativeStop(handle:Long)
    private external fun nativeDestroy(handle:Long)

    companion object { init { System.loadLibrary("freeroute_openvpn3") } }
}
