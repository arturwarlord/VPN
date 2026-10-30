#pragma once

#include "ovpncli.hpp"

/**
 * Concrete application callback surface for the pinned OpenVPN 3 ClientAPI.
 *
 * This first implementation stage deliberately does not establish a TUN,
 * protect transport sockets, or start connect(). Those operations remain
 * unavailable until the Android/JNI lifecycle bridge is implemented.
 */
class FreeRouteOpenVpnClient final : public openvpn::ClientAPI::OpenVPNClient {
public:
    FreeRouteOpenVpnClient() = default;
    ~FreeRouteOpenVpnClient() override = default;

    void event(const openvpn::ClientAPI::Event& event) override;
    void acc_event(const openvpn::ClientAPI::AppCustomControlMessageEvent& event) override;
    void log(const openvpn::ClientAPI::LogInfo& info) override;
    bool pause_on_connection_timeout() override;

    void external_pki_cert_request(
        openvpn::ClientAPI::ExternalPKICertRequest& request) override;
    void external_pki_sign_request(
        openvpn::ClientAPI::ExternalPKISignRequest& request) override;

    bool socket_protect(
        openvpn_io::detail::socket_type socket,
        std::string remote,
        bool ipv6) override;
};
