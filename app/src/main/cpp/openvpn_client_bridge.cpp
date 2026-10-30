#include "openvpn_client_bridge.hpp"

void FreeRouteOpenVpnClient::event(const openvpn::ClientAPI::Event& event)
{
    // Event delivery will be wired to the Kotlin controller in the JNI stage.
    (void)event;
}

void FreeRouteOpenVpnClient::acc_event(
    const openvpn::ClientAPI::AppCustomControlMessageEvent& event)
{
    // Custom control messages are intentionally not acted on in this stage.
    (void)event;
}

void FreeRouteOpenVpnClient::log(const openvpn::ClientAPI::LogInfo& info)
{
    // Avoid writing profile/server data to logcat. Structured, redacted event
    // reporting will be added with the JNI controller.
    (void)info;
}

bool FreeRouteOpenVpnClient::pause_on_connection_timeout()
{
    // Do not silently pause/retry until Android lifecycle policy is available.
    return false;
}

void FreeRouteOpenVpnClient::external_pki_cert_request(
    openvpn::ClientAPI::ExternalPKICertRequest& request)
{
    request.error = true;
    request.errorText = "External PKI is not supported by this FreeRoute build";
}

void FreeRouteOpenVpnClient::external_pki_sign_request(
    openvpn::ClientAPI::ExternalPKISignRequest& request)
{
    request.error = true;
    request.errorText = "External PKI is not supported by this FreeRoute build";
}

bool FreeRouteOpenVpnClient::socket_protect(
    openvpn_io::detail::socket_type socket,
    std::string remote,
    bool ipv6)
{
    // Fail closed: transport must not start until VpnService.protect(fd) is
    // connected and its result can be checked through the JNI bridge.
    (void)socket;
    (void)remote;
    (void)ipv6;
    return false;
}
