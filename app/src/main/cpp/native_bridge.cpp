#include <jni.h>
#include <exception>
#include <memory>
#include <string>

#include "openvpn_client_bridge.hpp"

namespace {
JavaVM* g_javaVm = nullptr;
}

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*)
{
    g_javaVm = vm;
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3Core_nativePlatform(JNIEnv* env, jobject)
{
    try {
        const std::string platform = openvpn::ClientAPI::OpenVPNClientHelper::platform();
        const std::string diagnostic = "OpenVPN 3 Core / " + platform;
        return env->NewStringUTF(diagnostic.c_str());
    } catch (const std::exception& error) {
        const std::string message = std::string("OpenVPN 3 Core error: ") + error.what();
        return env->NewStringUTF(message.c_str());
    } catch (...) {
        return env->NewStringUTF("OpenVPN 3 Core error: unknown native exception");
    }
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeCreate(
    JNIEnv* env, jobject, jobject vpnService)
{
    try {
        if (g_javaVm == nullptr || vpnService == nullptr) return 0;
        auto* client = new FreeRouteOpenVpnClient(g_javaVm, env, vpnService);
        return reinterpret_cast<jlong>(client);
    } catch (...) {
        return 0;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeDestroy(
    JNIEnv*, jobject, jlong handle)
{
    auto* client = reinterpret_cast<FreeRouteOpenVpnClient*>(handle);
    delete client;
}
