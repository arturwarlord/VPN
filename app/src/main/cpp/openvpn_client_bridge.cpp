#include "openvpn_client_bridge.hpp"

#include <stdexcept>

FreeRouteOpenVpnClient::FreeRouteOpenVpnClient(
    JavaVM* vm, JNIEnv* env, jobject vpnService)
    : vm_(vm), vpnService_(nullptr), protectSocketMethod_(nullptr)
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
        env->DeleteLocalRef(serviceClass);
    }
    if (protectSocketMethod_ == nullptr || env->ExceptionCheck()) {
        if (env->ExceptionCheck()) env->ExceptionClear();
        env->DeleteGlobalRef(vpnService_);
        vpnService_ = nullptr;
        throw std::runtime_error("OpenVPN VpnService protectSocketDescriptor method is unavailable");
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
    // Event delivery will be connected to a Kotlin state controller in the next stage.
    (void)event;
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
    openvpn_io::detail::socket_type socket,
    std::string remote,
    bool ipv6)
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

    // Fail closed if Android refuses to protect the transport socket.
    return !javaException && protectedSocket == JNI_TRUE;
}
