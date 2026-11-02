package com.arturwarlord.vpnclient

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.wireguard.crypto.KeyPair
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Holds the one pending FreeRoute enrollment.
 *
 * The device private key is encrypted with an AES-GCM key held by Android Keystore.
 * Only the public key is displayed or sent to the registration workflow.
 */
class FreeRouteEnrollmentStore(context: Context) {
    data class PendingEnrollment(
        val deviceName: String,
        val publicKey: String,
        val privateKey: String
    )

    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    @Synchronized
    fun loadOrCreate(): PendingEnrollment {
        val deviceName = preferences.getString(KEY_DEVICE_NAME, null)
        val publicKey = preferences.getString(KEY_PUBLIC_KEY, null)
        val iv = preferences.getString(KEY_PRIVATE_KEY_IV, null)
        val encryptedPrivateKey = preferences.getString(KEY_PRIVATE_KEY_CIPHERTEXT, null)

        val values = listOf(deviceName, publicKey, iv, encryptedPrivateKey)
        if (values.all { it == null }) {
            return createPendingEnrollment()
        }
        if (values.any { it.isNullOrBlank() }) {
            throw IllegalStateException(
                "Найдена неполная локальная регистрация. Не создавай новый ключ, пока не восстановишь текущий."
            )
        }

        val restoredPrivateKey = decryptPrivateKey(
            iv = requireNotNull(iv),
            ciphertext = requireNotNull(encryptedPrivateKey)
        )
        return PendingEnrollment(
            deviceName = requireNotNull(deviceName),
            publicKey = requireNotNull(publicKey),
            privateKey = restoredPrivateKey
        )
    }

    @Synchronized
    fun clear() {
        if (!preferences.edit().clear().commit()) {
            throw IllegalStateException("Не удалось удалить временную запись регистрации.")
        }
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
    }

    private fun createPendingEnrollment(): PendingEnrollment {
        val generated = KeyPair()
        val privateKey = generated.getPrivateKey().toBase64()
        val publicKey = generated.getPublicKey().toBase64()
        val plaintext = privateKey.toByteArray(StandardCharsets.US_ASCII)

        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateEncryptionKey())
            val ciphertext = cipher.doFinal(plaintext)
            val iv = cipher.iv
            require(iv.size == GCM_IV_LENGTH_BYTES) {
                "Android Keystore returned an unexpected AES-GCM nonce."
            }

            val deviceName = "android-" + UUID.randomUUID().toString().take(8)
            val saved = preferences.edit()
                .putString(KEY_DEVICE_NAME, deviceName)
                .putString(KEY_PUBLIC_KEY, publicKey)
                .putString(KEY_PRIVATE_KEY_IV, Base64.encodeToString(iv, Base64.NO_WRAP))
                .putString(
                    KEY_PRIVATE_KEY_CIPHERTEXT,
                    Base64.encodeToString(ciphertext, Base64.NO_WRAP)
                )
                .commit()
            if (!saved) {
                throw IllegalStateException("Не удалось сохранить ключ на устройстве.")
            }

            return PendingEnrollment(
                deviceName = deviceName,
                publicKey = publicKey,
                privateKey = privateKey
            )
        } finally {
            plaintext.fill(0)
        }
    }

    private fun decryptPrivateKey(iv: String, ciphertext: String): String {
        val nonce = Base64.decode(iv, Base64.NO_WRAP)
        require(nonce.size == GCM_IV_LENGTH_BYTES) {
            "Сохранённая запись регистрации имеет неверный формат."
        }
        val encryptedBytes = Base64.decode(ciphertext, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateEncryptionKey(),
            GCMParameterSpec(GCM_TAG_LENGTH_BITS, nonce)
        )
        val plaintext = cipher.doFinal(encryptedBytes)
        return try {
            String(plaintext, StandardCharsets.US_ASCII)
        } finally {
            plaintext.fill(0)
        }
    }

    private fun getOrCreateEncryptionKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return generator.generateKey()
    }

    private companion object {
        const val PREFERENCES_NAME = "freeroute_pending_enrollment"
        const val KEY_DEVICE_NAME = "device_name"
        const val KEY_PUBLIC_KEY = "public_key"
        const val KEY_PRIVATE_KEY_IV = "private_key_iv"
        const val KEY_PRIVATE_KEY_CIPHERTEXT = "private_key_ciphertext"
        const val KEY_ALIAS = "com.arturwarlord.freeroute.device-enrollment"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_LENGTH_BYTES = 12
        const val GCM_TAG_LENGTH_BITS = 128
    }
}
