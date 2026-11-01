#include <jni.h>
#include <string>
#include "openvpn_client_bridge.hpp"
namespace { JavaVM* g_javaVm=nullptr; }
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm,void*){g_javaVm=vm;return JNI_VERSION_1_6;}
extern "C" JNIEXPORT jstring JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3Core_nativePlatform(JNIEnv* env,jobject)
{try{std::string s="OpenVPN 3 Core / "+openvpn::ClientAPI::OpenVPNClientHelper::platform();return env->NewStringUTF(s.c_str());}catch(...){return env->NewStringUTF("OpenVPN 3 Core error");}}
extern "C" JNIEXPORT jlong JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeCreate(JNIEnv* env,jobject,jobject service)
{try{if(!g_javaVm||!service)return 0;return reinterpret_cast<jlong>(new FreeRouteOpenVpnClient(g_javaVm,env,service));}catch(...){return 0;}}
extern "C" JNIEXPORT jboolean JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeEvaluateProfile(JNIEnv* env,jobject,jlong handle,jstring profile)
{
    auto* c=reinterpret_cast<FreeRouteOpenVpnClient*>(handle);if(!c||!profile)return JNI_FALSE;
    jsize n=env->GetStringUTFLength(profile);long max=openvpn::ClientAPI::OpenVPNClientHelper::max_profile_size();if(n<=0||max<=0||n>max)return JNI_FALSE;
    const char* chars=env->GetStringUTFChars(profile,nullptr);if(!chars||env->ExceptionCheck()){if(env->ExceptionCheck())env->ExceptionClear();return JNI_FALSE;}
    bool ok=false;try{openvpn::ClientAPI::Config cfg;cfg.content.assign(chars,static_cast<size_t>(n));ok=c->evaluateProfile(cfg);}catch(...){ok=false;}
    env->ReleaseStringUTFChars(profile,chars);if(env->ExceptionCheck()){env->ExceptionClear();return JNI_FALSE;}return ok?JNI_TRUE:JNI_FALSE;
}
extern "C" JNIEXPORT jboolean JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeStart(JNIEnv* env,jobject,jlong handle,jstring username,jstring password)
{
    auto* c=reinterpret_cast<FreeRouteOpenVpnClient*>(handle);if(!c)return JNI_FALSE;
    std::string user,pass;const char* u=username?env->GetStringUTFChars(username,nullptr):nullptr;
    if(username&&!u){if(env->ExceptionCheck())env->ExceptionClear();return JNI_FALSE;}if(u)user.assign(u);
    const char* p=password?env->GetStringUTFChars(password,nullptr):nullptr;
    if(password&&!p){if(u)env->ReleaseStringUTFChars(username,u);if(env->ExceptionCheck())env->ExceptionClear();return JNI_FALSE;}if(p)pass.assign(p);
    if(u)env->ReleaseStringUTFChars(username,u);if(p)env->ReleaseStringUTFChars(password,p);
    bool started=c->start(user,pass);
    volatile char* a=user.empty()?nullptr:&user[0];for(size_t i=0;i<user.size();++i)a[i]=0;
    volatile char* b=pass.empty()?nullptr:&pass[0];for(size_t i=0;i<pass.size();++i)b[i]=0;
    return started?JNI_TRUE:JNI_FALSE;
}
extern "C" JNIEXPORT void JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeStop(JNIEnv*,jobject,jlong handle)
{auto*c=reinterpret_cast<FreeRouteOpenVpnClient*>(handle);if(c)c->stopAndJoin();}
extern "C" JNIEXPORT void JNICALL Java_com_arturwarlord_vpnclient_OpenVpn3NativeSession_nativeDestroy(JNIEnv*,jobject,jlong handle)
{delete reinterpret_cast<FreeRouteOpenVpnClient*>(handle);}
