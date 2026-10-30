#pragma once

#include <jni.h>
#include <string>
#include <vector>
#include "ovpncli.hpp"

/**
 * OpenVPN 3 application and TUN-builder callbacks bound to Android VpnService.
 * Connection/profile lifecycle is intentionally not started in this phase.
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

    bool tun_builder_new() override;
    bool tun_builder_set_layer(int layer) override;
    bool tun_builder_set_remote_address(const std::string& address, bool ipv6) override;
    bool tun_builder_add_address(const std::string& address, int prefixLength,
                                 const std::string& gateway, bool ipv6, bool net30) override;
    bool tun_builder_set_route_metric_default(int metric) override;
    bool tun_builder_reroute_gw(bool ipv4, bool ipv6, unsigned int flags) override;
    bool tun_builder_add_route(const std::string& address, int prefixLength,
                               int metric, bool ipv6) override;
    bool tun_builder_exclude_route(const std::string& address, int prefixLength,
                                   int metric, bool ipv6) override;
    bool tun_builder_set_dns_options(const openvpn::DnsOptions& dns) override;
    bool tun_builder_set_mtu(int mtu) override;
    bool tun_builder_set_session_name(const std::string& name) override;
    bool tun_builder_add_proxy_bypass(const std::string& host) override;
    bool tun_builder_set_proxy_auto_config_url(const std::string& url) override;
    bool tun_builder_set_proxy_http(const std::string& host, int port) override;
    bool tun_builder_set_proxy_https(const std::string& host, int port) override;
    bool tun_builder_add_wins_server(const std::string& address) override;
    bool tun_builder_set_allow_family(int af, bool allow) override;
    bool tun_builder_set_allow_local_dns(bool allow) override;
    int tun_builder_establish() override;
    bool tun_builder_persist() override;
    std::vector<std::string> tun_builder_get_local_networks(bool ipv6) override;
    void tun_builder_establish_lite() override;
    void tun_builder_teardown(bool disconnect) override;

private:
    JNIEnv* acquireEnv(bool& attached) const;
    void releaseEnv(bool attached) const;
    int establishAndroidTun();

    JavaVM* vm_;
    jobject vpnService_;
    jmethodID protectSocketMethod_;
    jmethodID establishTunMethod_;

    std::vector<std::string> addresses_;
    std::vector<int> addressPrefixes_;
    std::vector<std::string> routes_;
    std::vector<int> routePrefixes_;
    std::vector<std::string> dnsServers_;
    int mtu_;
    std::string sessionName_;
    bool builderReady_;
};
