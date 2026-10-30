#include "openvpn_client_bridge.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <openvpn/tun/builder/rgwflags.hpp>
#include <stdexcept>
#include <utility>

FreeRouteOpenVpnClient::FreeRouteOpenVpnClient(
    JavaVM* vm, JNIEnv* env, jobject vpnService)
    : vm_(vm), vpnService_(nullptr), protectSocketMethod_(nullptr),
      establishTunMethod_(nullptr), mtu_(1500), sessionName_("FreeRoute OpenVPN"),
      builderReady_(false)
{
    if (vm_ == nullptr || env == nullptr || vpnService == nullptr) {
        throw std::invalid_argument("OpenVPN Android service bridge is not initialized");
    }

    vpnService_ = env->NewGlobalRef(vpnService);
    if (vpnService_ == nullptr) {
        throw std::runtime_error("Unable to retain OpenVPN VpnService reference");
    }

    jclass serviceClass = env->GetObjectClass(vpnService);
    if (serviceClass != nullptr) {
        protectSocketMethod_ = env->GetMethodID(serviceClass, "protectSocketDescriptor", "(I)Z");
        establishTunMethod_ = env->GetMethodID(
            serviceClass, "establishTun",
            "([Ljava/lang/String;[I[Ljava/lang/String;[I[Ljava/lang/String;ILjava/lang/String;)I");
        env->DeleteLocalRef(serviceClass);
    }
    if (protectSocketMethod_ == nullptr || establishTunMethod_ == nullptr || env->ExceptionCheck()) {
        if (env->ExceptionCheck()) env->ExceptionClear();
        env->DeleteGlobalRef(vpnService_);
        vpnService_ = nullptr;
        throw std::runtime_error("OpenVPN VpnService bridge methods are unavailable");
    }
}

FreeRouteOpenVpnClient::~FreeRouteOpenVpnClient()
{
    bool attached = false;
    JNIEnv* env = acquireEnv(attached);
    if (env != nullptr && vpnService_ != nullptr) {
        env->DeleteGlobalRef(vpnService_);
        vpnService_ = nullptr;
    }
    releaseEnv(attached);
}

JNIEnv* FreeRouteOpenVpnClient::acquireEnv(bool& attached) const
{
    attached = false;
    if (vm_ == nullptr) return nullptr;

    JNIEnv* env = nullptr;
    const jint status = vm_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (status == JNI_OK) return env;
    if (status != JNI_EDETACHED) return nullptr;

#if defined(__ANDROID__)
    if (vm_->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
#else
    if (vm_->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) return nullptr;
#endif
    attached = true;
    return env;
}

void FreeRouteOpenVpnClient::releaseEnv(bool attached) const
{
    if (attached && vm_ != nullptr) vm_->DetachCurrentThread();
}

void FreeRouteOpenVpnClient::event(const openvpn::ClientAPI::Event& event)
{
    (void)event; // State forwarding is added with the worker lifecycle.
}

void FreeRouteOpenVpnClient::acc_event(
    const openvpn::ClientAPI::AppCustomControlMessageEvent& event)
{
    (void)event;
}

void FreeRouteOpenVpnClient::log(const openvpn::ClientAPI::LogInfo& info)
{
    // Never send raw OpenVPN logs to logcat: they may contain profile/server details.
    (void)info;
}

bool FreeRouteOpenVpnClient::pause_on_connection_timeout()
{
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
    openvpn_io::detail::socket_type socket, std::string remote, bool ipv6)
{
    (void)remote;
    (void)ipv6;

    bool attached = false;
    JNIEnv* env = acquireEnv(attached);
    if (env == nullptr || vpnService_ == nullptr || protectSocketMethod_ == nullptr) {
        releaseEnv(attached);
        return false;
    }

    const jboolean protectedSocket = env->CallBooleanMethod(
        vpnService_, protectSocketMethod_, static_cast<jint>(socket));
    const bool javaException = env->ExceptionCheck();
    if (javaException) env->ExceptionClear();
    releaseEnv(attached);
    return !javaException && protectedSocket == JNI_TRUE;
}

bool FreeRouteOpenVpnClient::tun_builder_new()
{
    addresses_.clear();
    addressPrefixes_.clear();
    routes_.clear();
    routePrefixes_.clear();
    dnsServers_.clear();
    mtu_ = 1500;
    sessionName_ = "FreeRoute OpenVPN";
    builderReady_ = true;
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_set_layer(int layer)
{
    return layer == 3;
}

bool FreeRouteOpenVpnClient::tun_builder_set_remote_address(
    const std::string& address, bool ipv6)
{
    (void)address;
    (void)ipv6;
    // This is the transport endpoint, not an address assigned to the TUN.
    return builderReady_;
}

bool FreeRouteOpenVpnClient::tun_builder_add_address(
    const std::string& address, int prefixLength,
    const std::string& gateway, bool ipv6, bool net30)
{
    if (!builderReady_ || !gateway.empty() || net30) return false;
    const int maxPrefix = ipv6 ? 128 : 32;
    if (prefixLength < 0 || prefixLength > maxPrefix) return false;
    if ((address.find(':') != std::string::npos) != ipv6) return false;
    addresses_.push_back(address);
    addressPrefixes_.push_back(prefixLength);
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_set_route_metric_default(int metric)
{
    // Android VpnService.Builder has no route-metric API. Do not silently drop one.
    return metric < 0;
}

bool FreeRouteOpenVpnClient::tun_builder_reroute_gw(
    bool ipv4, bool ipv6, unsigned int flags)
{
    // Redirect-gateway flags beyond the plain default-route case require
    // platform-specific exclusion semantics which this phase does not emulate.
    if (!builderReady_ || flags != 0 || (!ipv4 && !ipv6)) return false;
    if (ipv4) {
        routes_.emplace_back("0.0.0.0");
        routePrefixes_.push_back(0);
    }
    if (ipv6) {
        routes_.emplace_back("::");
        routePrefixes_.push_back(0);
    }
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_add_route(
    const std::string& address, int prefixLength, int metric, bool ipv6)
{
    if (!builderReady_ || metric >= 0) return false;
    const int maxPrefix = ipv6 ? 128 : 32;
    if (prefixLength < 0 || prefixLength > maxPrefix) return false;
    if ((address.find(':') != std::string::npos) != ipv6) return false;
    routes_.push_back(address);
    routePrefixes_.push_back(prefixLength);
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_exclude_route(
    const std::string& address, int prefixLength, int metric, bool ipv6)
{
    (void)address;
    (void)prefixLength;
    (void)metric;
    (void)ipv6;
    // Exclusions cannot be represented safely by the current Builder contract.
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_set_dns_options(
    const openvpn::DnsOptions& dns)
{
    if (!builderReady_ || !dns.search_domains.empty()) return false;

    std::vector<std::string> parsedServers;
    for (const auto& entry : dns.servers) {
        const auto& server = entry.second;
        if (server.transport != openvpn::DnsServer::Transport::Unset &&
            server.transport != openvpn::DnsServer::Transport::Plain) return false;
        if (!server.domains.empty() || !server.sni.empty()) return false;
        for (const auto& address : server.addresses) {
            if (address.port != 0 && address.port != 53) return false;
            parsedServers.push_back(address.address);
        }
    }
    dnsServers_ = std::move(parsedServers);
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_set_mtu(int mtu)
{
    if (!builderReady_ || mtu < 576 || mtu > 9000) return false;
    mtu_ = mtu;
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_set_session_name(const std::string& name)
{
    if (!builderReady_ || name.empty() || name.size() > 64) return false;
    sessionName_ = name;
    return true;
}

bool FreeRouteOpenVpnClient::tun_builder_add_proxy_bypass(const std::string& host)
{
    (void)host;
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_set_proxy_auto_config_url(const std::string& url)
{
    (void)url;
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_set_proxy_http(const std::string& host, int port)
{
    (void)host;
    (void)port;
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_set_proxy_https(const std::string& host, int port)
{
    (void)host;
    (void)port;
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_add_wins_server(const std::string& address)
{
    (void)address;
    return false;
}

bool FreeRouteOpenVpnClient::tun_builder_set_allow_family(int af, bool allow)
{
    if (af != AF_INET && af != AF_INET6) return false;
    // "allow" would let this address family bypass the VPN on Android.
    return !allow;
}

bool FreeRouteOpenVpnClient::tun_builder_set_allow_local_dns(bool allow)
{
    // Allowing local DNS outside the VPN is not supported by this bridge.
    return !allow;
}

int FreeRouteOpenVpnClient::establishAndroidTun()
{
    bool attached = false;
    JNIEnv* env = acquireEnv(attached);
    if (env == nullptr || vpnService_ == nullptr || establishTunMethod_ == nullptr) {
        releaseEnv(attached);
        return -1;
    }

    jclass stringClass = env->FindClass("java/lang/String");
    if (stringClass == nullptr || env->ExceptionCheck()) {
        if (env->ExceptionCheck()) env->ExceptionClear();
        releaseEnv(attached);
        return -1;
    }

    auto makeStringArray = [&](const std::vector<std::string>& values) -> jobjectArray {
        jobjectArray array = env->NewObjectArray(
            static_cast<jsize>(values.size()), stringClass, nullptr);
        if (array == nullptr) return nullptr;
        for (jsize i = 0; i < static_cast<jsize>(values.size()); ++i) {
            jstring value = env->NewStringUTF(values[static_cast<size_t>(i)].c_str());
            if (value == nullptr) return nullptr;
            env->SetObjectArrayElement(array, i, value);
            env->DeleteLocalRef(value);
            if (env->ExceptionCheck()) return nullptr;
        }
        return array;
    };

    auto makeIntArray = [&](const std::vector<int>& values) -> jintArray {
        jintArray array = env->NewIntArray(static_cast<jsize>(values.size()));
        if (array != nullptr && !values.empty()) {
            env->SetIntArrayRegion(array, 0, static_cast<jsize>(values.size()),
                                   reinterpret_cast<const jint*>(values.data()));
        }
        return array;
    };

    jobjectArray addresses = makeStringArray(addresses_);
    jintArray addressPrefixes = makeIntArray(addressPrefixes_);
    jobjectArray routes = makeStringArray(routes_);
    jintArray routePrefixes = makeIntArray(routePrefixes_);
    jobjectArray dns = makeStringArray(dnsServers_);
    jstring session = env->NewStringUTF(sessionName_.c_str());

    int result = -1;
    if (addresses != nullptr && addressPrefixes != nullptr && routes != nullptr &&
        routePrefixes != nullptr && dns != nullptr && session != nullptr &&
        !env->ExceptionCheck()) {
        result = env->CallIntMethod(
            vpnService_, establishTunMethod_, addresses, addressPrefixes,
            routes, routePrefixes, dns, static_cast<jint>(mtu_), session);
    }

    const bool javaException = env->ExceptionCheck();
    if (javaException) {
        env->ExceptionClear();
        result = -1;
    }

    if (addresses) env->DeleteLocalRef(addresses);
    if (addressPrefixes) env->DeleteLocalRef(addressPrefixes);
    if (routes) env->DeleteLocalRef(routes);
    if (routePrefixes) env->DeleteLocalRef(routePrefixes);
    if (dns) env->DeleteLocalRef(dns);
    if (session) env->DeleteLocalRef(session);
    env->DeleteLocalRef(stringClass);
    releaseEnv(attached);
    return result;
}

int FreeRouteOpenVpnClient::tun_builder_establish()
{
    if (!builderReady_ || addresses_.empty()) return -1;
    const int fd = establishAndroidTun();
    if (fd >= 0) builderReady_ = false;
    return fd;
}

bool FreeRouteOpenVpnClient::tun_builder_persist()
{
    return false;
}

std::vector<std::string> FreeRouteOpenVpnClient::tun_builder_get_local_networks(bool ipv6)
{
    (void)ipv6;
    return {};
}

void FreeRouteOpenVpnClient::tun_builder_establish_lite()
{
    // Persistence is disabled; OpenVPN must call tun_builder_establish().
}

void FreeRouteOpenVpnClient::tun_builder_teardown(bool disconnect)
{
    (void)disconnect;
    // OpenVPN owns and closes the detached TUN fd returned by establish().
    addresses_.clear();
    addressPrefixes_.clear();
    routes_.clear();
    routePrefixes_.clear();
    dnsServers_.clear();
    builderReady_ = false;
}
