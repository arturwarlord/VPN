package com.arturwarlord.vpnclient

import net.openvpn.ovpn3.ClientAPI_OpenVPNClientHelper

/**
 * Access to the upstream OpenVPN 3 ClientAPI generated from client/ovpncli.i.
 * The generated ovpncliJNI Java class loads libfreeroute_openvpn3.so.
 */
internal object OpenVpn3SwigApi {
    init {
        System.loadLibrary("freeroute_openvpn3")
    }

    fun platform(): String = ClientAPI_OpenVPNClientHelper.platform()
}
