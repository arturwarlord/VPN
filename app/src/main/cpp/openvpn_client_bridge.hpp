#pragma once

#include <jni.h>
#include "ovpncli.hpp"

/**
 * OpenVPN 3 application callbacks bound to the Android VpnService instance.
 * This stage wires socket protection only; it does not start connect().
 */
class FreeRouteOpenVpnClient final : public openvpn::ClientAPI::OpenVPNClient {
public:
    FreeRouteOpenVpnClient(JavaVM* vm, JNIEnv* env, jobject vpnService);
    ~FreeRouteOpenVpnClient() override;

    FreeRouteOpenVpnClient(const FreeRouteOpenVpnClient&) = delete;
    FreeRouteOpenVpnClient& operator=(const FreeRouteOpenVpnClient&) = delete;

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

private:
    JNIEnv* acquireEnv(bool& attached) const;
    void releaseEnv(bool attached) const;

    JavaVM* vm_;
    jobject vpnService_;
    jmethodID protectSocketMethod_;
};
