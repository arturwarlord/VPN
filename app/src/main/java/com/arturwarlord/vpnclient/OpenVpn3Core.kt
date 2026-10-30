package com.arturwarlord.vpnclient

/**
 * Phase-one bridge to the upstream OpenVPN 3 ClientAPI.
 * This diagnostic does not start a VPN session or establish an Android TUN interface.
 */
internal object OpenVpn3Core {
    init {
        System.loadLibrary("freeroute_openvpn3")
    }

    external fun nativePlatform(): String
}
