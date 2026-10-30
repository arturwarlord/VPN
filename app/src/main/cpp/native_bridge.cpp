#include <jni.h>
#include <exception>
#include <string>
#include "ovpncli.hpp"

extern "C" JNIEXPORT jstring JNICALL
Java_com_arturwarlord_vpnclient_OpenVpn3Core_nativePlatform(JNIEnv *env, jobject)
{
    try
    {
        const std::string platform = openvpn::ClientAPI::OpenVPNClientHelper::platform();
        const std::string diagnostic = "OpenVPN 3 Core / " + platform;
        return env->NewStringUTF(diagnostic.c_str());
    }
    catch (const std::exception &error)
    {
        const std::string message = std::string("OpenVPN 3 Core error: ") + error.what();
        return env->NewStringUTF(message.c_str());
    }
    catch (...)
    {
        return env->NewStringUTF("OpenVPN 3 Core error: unknown native exception");
    }
}
