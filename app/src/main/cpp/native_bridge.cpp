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

extern "C" JNIEXPORT jboolean JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeEvaluateProfile(
    JNIEnv* env, jobject, jlong handle, jstring profileText)
{
    auto* client = reinterpret_cast<FreeRouteOpenVpnClient*>(handle);
    if (client == nullptr || profileText == nullptr) return JNI_FALSE;

    const jsize profileLength = env->GetStringUTFLength(profileText);
    const long maximumLength = openvpn::ClientAPI::OpenVPNClientHelper::max_profile_size();
    if (profileLength <= 0 || maximumLength <= 0 || profileLength > maximumLength) {
        return JNI_FALSE;
    }

    const char* chars = env->GetStringUTFChars(profileText, nullptr);
    if (chars == nullptr || env->ExceptionCheck()) {
        if (env->ExceptionCheck()) env->ExceptionClear();
        return JNI_FALSE;
    }

    bool accepted = false;
    try {
        openvpn::ClientAPI::Config config;
        config.content.assign(chars, static_cast<size_t>(profileLength));
        const openvpn::ClientAPI::EvalConfig evaluation = client->eval_config(config);
        accepted = !evaluation.error;
    } catch (...) {
        accepted = false;
    }

    env->ReleaseStringUTFChars(profileText, chars);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return JNI_FALSE;
    }
    return accepted ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeDestroy(
    JNIEnv*, jobject, jlong handle)
{
    auto* client = reinterpret_cast<FreeRouteOpenVpnClient*>(handle);
    delete client;
}
