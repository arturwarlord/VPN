#include "openvpn_client_bridge.hpp"

#include <algorithm>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <openvpn/tun/builder/rgwflags.hpp>
#include <stdexcept>
#include <utility>

namespace {
void wipeString(std::string& value)
{
    volatile char* data = value.empty() ? nullptr : &value[0];
    for (size_t i = 0; i < value.size(); ++i) data[i] = 0;
    value.clear();
}
}

FreeRouteOpenVpnClient::FreeRouteOpenVpnClient(JavaVM* vm, JNIEnv* env, jobject vpnService)
    : vm_(vm), vpnService_(nullptr), protectSocketMethod_(nullptr), establishTunMethod_(nullptr), nativeEventMethod_(nullptr),
      mtu_(1500), sessionName_("FreeRoute OpenVPN"), builderReady_(false)
{
    if (!vm_ || !env || !vpnService) throw std::invalid_argument("OpenVPN Android service bridge is not initialized");
    vpnService_ = env->NewGlobalRef(vpnService);
    if (!vpnService_) throw std::runtime_error("Unable to retain OpenVPN VpnService reference");
    jclass cls = env->GetObjectClass(vpnService);
    if (cls) {
        protectSocketMethod_ = env->GetMethodID(cls, "protectSocketDescriptor", "(I)Z");
        establishTunMethod_ = env->GetMethodID(cls, "establishTun",
            "([Ljava/lang/String;[I[Ljava/lang/String;[I[Ljava/lang/String;ILjava/lang/String;)I");
        nativeEventMethod_ = env->GetMethodID(cls, "onNativeEvent", "(Ljava/lang/String;ZZ)V");
        env->DeleteLocalRef(cls);
    }
    if (!protectSocketMethod_ || !establishTunMethod_ || !nativeEventMethod_ || env->ExceptionCheck()) {
        if (env->ExceptionCheck()) env->ExceptionClear();
        env->DeleteGlobalRef(vpnService_); vpnService_ = nullptr;
        throw std::runtime_error("OpenVPN VpnService bridge methods are unavailable");
    }
}

FreeRouteOpenVpnClient::~FreeRouteOpenVpnClient()
{
    stopAndJoin();
    bool attached = false; JNIEnv* env = acquireEnv(attached);
    if (env && vpnService_) { env->DeleteGlobalRef(vpnService_); vpnService_ = nullptr; }
    releaseEnv(attached);
}

bool FreeRouteOpenVpnClient::evaluateProfile(const openvpn::ClientAPI::Config& config)
{
    std::lock_guard<std::mutex> lock(lifecycleMutex_);
    if (worker_.joinable() || workerRunning_.load()) return false;
    try {
        evaluatedProfile_ = eval_config(config);
        profileEvaluated_ = !evaluatedProfile_.error;
        return profileEvaluated_;
    } catch (...) { profileEvaluated_ = false; return false; }
}

bool FreeRouteOpenVpnClient::start(const std::string& username, const std::string& password)
{
    std::lock_guard<std::mutex> lock(lifecycleMutex_);
    if (worker_.joinable() || workerRunning_.load() || !profileEvaluated_) return false;
    if (evaluatedProfile_.externalPki || evaluatedProfile_.privateKeyPasswordRequired) return false;
    if (!evaluatedProfile_.autologin && (username.empty() || password.empty())) return false;
    if (!evaluatedProfile_.autologin) {
        openvpn::ClientAPI::ProvideCreds creds;
        creds.username = username; creds.password = password;
        const auto status = provide_creds(creds);
        wipeString(creds.username); wipeString(creds.password);
        if (status.error) return false;
    }
    workerRunning_.store(true);
    try {
        worker_ = std::thread([this]() {
            try { (void)connect(); } catch (...) {}
            workerRunning_.store(false);
        });
    } catch (...) { workerRunning_.store(false); return false; }
    return true;
}

void FreeRouteOpenVpnClient::stopAndJoin()
{
    std::lock_guard<std::mutex> lock(lifecycleMutex_);
    if (worker_.joinable()) {
        openvpn::ClientAPI::OpenVPNClient::stop();
        if (worker_.get_id() != std::this_thread::get_id()) worker_.join();
    }
    workerRunning_.store(false);
}

JNIEnv* FreeRouteOpenVpnClient::acquireEnv(bool& attached) const
{
    attached = false; if (!vm_) return nullptr;
    JNIEnv* env = nullptr;
    jint status = vm_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (status == JNI_OK) return env;
    if (status != JNI_EDETACHED) return nullptr;
#if defined(__ANDROID__)
    if (vm_->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
#else
    if (vm_->AttachCurrentThread(reinterpret_cast<void**>(&env), nullptr) != JNI_OK) return nullptr;
#endif
    attached = true; return env;
}
void FreeRouteOpenVpnClient::releaseEnv(bool attached) const { if (attached && vm_) vm_->DetachCurrentThread(); }

void FreeRouteOpenVpnClient::event(const openvpn::ClientAPI::Event& e)
{
    bool attached = false;
    JNIEnv* env = acquireEnv(attached);
    if (!env || !vpnService_ || !nativeEventMethod_) {
        releaseEnv(attached);
        return;
    }

    // Event names are protocol state tokens. Never forward event.info, which may
    // contain server-supplied text or connection details.
    jstring name = env->NewStringUTF(e.name.c_str());
    if (name && !env->ExceptionCheck()) {
        env->CallVoidMethod(
            vpnService_,
            nativeEventMethod_,
            name,
            static_cast<jboolean>(e.error ? JNI_TRUE : JNI_FALSE),
            static_cast<jboolean>(e.fatal ? JNI_TRUE : JNI_FALSE)
        );
    }
    if (env->ExceptionCheck()) env->ExceptionClear();
    if (name) env->DeleteLocalRef(name);
    releaseEnv(attached);
}
void FreeRouteOpenVpnClient::acc_event(const openvpn::ClientAPI::AppCustomControlMessageEvent& e) { (void)e; }
void FreeRouteOpenVpnClient::log(const openvpn::ClientAPI::LogInfo& e) { (void)e; }
bool FreeRouteOpenVpnClient::pause_on_connection_timeout() { return false; }
void FreeRouteOpenVpnClient::external_pki_cert_request(openvpn::ClientAPI::ExternalPKICertRequest& r)
{ r.error = true; r.errorText = "External PKI is not supported by this FreeRoute build"; }
void FreeRouteOpenVpnClient::external_pki_sign_request(openvpn::ClientAPI::ExternalPKISignRequest& r)
{ r.error = true; r.errorText = "External PKI is not supported by this FreeRoute build"; }

bool FreeRouteOpenVpnClient::socket_protect(openvpn_io::detail::socket_type socket, std::string remote, bool ipv6)
{
    (void)remote; (void)ipv6;
    bool attached = false; JNIEnv* env = acquireEnv(attached);
    if (!env || !vpnService_ || !protectSocketMethod_) { releaseEnv(attached); return false; }
    jboolean ok = env->CallBooleanMethod(vpnService_, protectSocketMethod_, static_cast<jint>(socket));
    bool exception = env->ExceptionCheck(); if (exception) env->ExceptionClear();
    releaseEnv(attached); return !exception && ok == JNI_TRUE;
}

bool FreeRouteOpenVpnClient::tun_builder_new()
{ addresses_.clear(); addressPrefixes_.clear(); routes_.clear(); routePrefixes_.clear(); dnsServers_.clear(); mtu_=1500; sessionName_="FreeRoute OpenVPN"; builderReady_=true; return true; }
bool FreeRouteOpenVpnClient::tun_builder_set_layer(int layer) { return layer == 3; }
bool FreeRouteOpenVpnClient::tun_builder_set_remote_address(const std::string& a, bool v6) { (void)a; (void)v6; return builderReady_; }
bool FreeRouteOpenVpnClient::tun_builder_add_address(const std::string& a,int p,const std::string& g,bool v6,bool net30)
{ if(!builderReady_||!g.empty()||net30||p<0||p>(v6?128:32)||((a.find(':')!=std::string::npos)!=v6)) return false; addresses_.push_back(a); addressPrefixes_.push_back(p); return true; }
bool FreeRouteOpenVpnClient::tun_builder_set_route_metric_default(int metric) { return metric < 0; }
bool FreeRouteOpenVpnClient::tun_builder_reroute_gw(bool v4,bool v6,unsigned int flags)
{ if(!builderReady_||flags!=0||(!v4&&!v6)) return false; if(v4){routes_.emplace_back("0.0.0.0");routePrefixes_.push_back(0);} if(v6){routes_.emplace_back("::");routePrefixes_.push_back(0);} return true; }
bool FreeRouteOpenVpnClient::tun_builder_add_route(const std::string&a,int p,int metric,bool v6)
{ if(!builderReady_||metric>=0||p<0||p>(v6?128:32)||((a.find(':')!=std::string::npos)!=v6)) return false; routes_.push_back(a);routePrefixes_.push_back(p);return true; }
bool FreeRouteOpenVpnClient::tun_builder_exclude_route(const std::string&a,int p,int m,bool v6)
{ (void)a;(void)p;(void)m;(void)v6;return false; }
bool FreeRouteOpenVpnClient::tun_builder_set_dns_options(const openvpn::DnsOptions& dns)
{
    if(!builderReady_||!dns.search_domains.empty()) return false;
    std::vector<std::string> parsed;
    for(const auto& entry:dns.servers){const auto& s=entry.second;
        if((s.transport!=openvpn::DnsServer::Transport::Unset&&s.transport!=openvpn::DnsServer::Transport::Plain)||
           s.dnssec!=openvpn::DnsServer::Security::Unset||!s.domains.empty()||!s.sni.empty()) return false;
        for(const auto& a:s.addresses){if(a.port!=0&&a.port!=53)return false;parsed.push_back(a.address);}
    }
    dnsServers_=std::move(parsed);return true;
}
bool FreeRouteOpenVpnClient::tun_builder_set_mtu(int mtu){if(!builderReady_||mtu<576||mtu>9000)return false;mtu_=mtu;return true;}
bool FreeRouteOpenVpnClient::tun_builder_set_session_name(const std::string& n){if(!builderReady_||n.empty()||n.size()>64)return false;sessionName_=n;return true;}
bool FreeRouteOpenVpnClient::tun_builder_add_proxy_bypass(const std::string& h){(void)h;return false;}
bool FreeRouteOpenVpnClient::tun_builder_set_proxy_auto_config_url(const std::string& u){(void)u;return false;}
bool FreeRouteOpenVpnClient::tun_builder_set_proxy_http(const std::string& h,int p){(void)h;(void)p;return false;}
bool FreeRouteOpenVpnClient::tun_builder_set_proxy_https(const std::string& h,int p){(void)h;(void)p;return false;}
bool FreeRouteOpenVpnClient::tun_builder_add_wins_server(const std::string& a){(void)a;return false;}
bool FreeRouteOpenVpnClient::tun_builder_set_allow_family(int af,bool allow){if(af!=AF_INET&&af!=AF_INET6)return false;return !allow;}
bool FreeRouteOpenVpnClient::tun_builder_set_allow_local_dns(bool allow){return !allow;}

int FreeRouteOpenVpnClient::establishAndroidTun()
{
    bool attached=false; JNIEnv* env=acquireEnv(attached);
    if(!env||!vpnService_||!establishTunMethod_){releaseEnv(attached);return -1;}
    jclass stringClass=env->FindClass("java/lang/String");
    if(!stringClass||env->ExceptionCheck()){if(env->ExceptionCheck())env->ExceptionClear();releaseEnv(attached);return -1;}
    auto strings=[&](const std::vector<std::string>& values)->jobjectArray{
        jobjectArray arr=env->NewObjectArray(static_cast<jsize>(values.size()),stringClass,nullptr);if(!arr)return nullptr;
        for(jsize i=0;i<static_cast<jsize>(values.size());++i){jstring v=env->NewStringUTF(values[static_cast<size_t>(i)].c_str());if(!v)return nullptr;env->SetObjectArrayElement(arr,i,v);env->DeleteLocalRef(v);if(env->ExceptionCheck())return nullptr;}return arr;};
    auto ints=[&](const std::vector<int>& values)->jintArray{jintArray arr=env->NewIntArray(static_cast<jsize>(values.size()));if(arr&&!values.empty())env->SetIntArrayRegion(arr,0,static_cast<jsize>(values.size()),reinterpret_cast<const jint*>(values.data()));return arr;};
    jobjectArray a=strings(addresses_),r=strings(routes_),d=strings(dnsServers_);
    jintArray ap=ints(addressPrefixes_),rp=ints(routePrefixes_);jstring session=env->NewStringUTF(sessionName_.c_str());int fd=-1;
    if(a&&r&&d&&ap&&rp&&session&&!env->ExceptionCheck())fd=env->CallIntMethod(vpnService_,establishTunMethod_,a,ap,r,rp,d,static_cast<jint>(mtu_),session);
    if(env->ExceptionCheck()){env->ExceptionClear();fd=-1;}
    if(a)env->DeleteLocalRef(a);if(r)env->DeleteLocalRef(r);if(d)env->DeleteLocalRef(d);if(ap)env->DeleteLocalRef(ap);if(rp)env->DeleteLocalRef(rp);if(session)env->DeleteLocalRef(session);
    env->DeleteLocalRef(stringClass);releaseEnv(attached);return fd;
}
int FreeRouteOpenVpnClient::tun_builder_establish()
{ if(!builderReady_||addresses_.empty())return -1;bool v6=std::any_of(addresses_.begin(),addresses_.end(),[](const std::string&a){return a.find(':')!=std::string::npos;});if(v6&&mtu_<1280)return -1;int fd=establishAndroidTun();if(fd>=0)builderReady_=false;return fd; }
bool FreeRouteOpenVpnClient::tun_builder_persist(){return false;}
std::vector<std::string> FreeRouteOpenVpnClient::tun_builder_get_local_networks(bool ipv6){(void)ipv6;return {};}
void FreeRouteOpenVpnClient::tun_builder_establish_lite(){}
void FreeRouteOpenVpnClient::tun_builder_teardown(bool disconnect){(void)disconnect;addresses_.clear();addressPrefixes_.clear();routes_.clear();routePrefixes_.clear();dnsServers_.clear();builderReady_=false;}
