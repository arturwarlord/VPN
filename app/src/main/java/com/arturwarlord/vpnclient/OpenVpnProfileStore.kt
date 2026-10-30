package com.arturwarlord.vpnclient

import android.content.Context
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/**
 * Stores imported OpenVPN profiles in app-private storage.
 *
 * This class deliberately does not parse, evaluate, connect, or log profile
 * contents. A later phase passes the selected text to OpenVPN 3 Core.
 */
internal class OpenVpnProfileStore(context: Context) {
    private val directory = File(context.filesDir, "openvpn-profiles").apply { mkdirs() }

    fun list(): List<File> = directory.listFiles()
        ?.filter { it.isFile && it.extension.equals("ovpn", ignoreCase = true) }
        ?.sortedBy { it.name.lowercase() }
        ?: emptyList()

    fun import(input: InputStream, displayName: String): File {
        val safeName = displayName.substringAfterLast('/').substringAfterLast('\\')
        require(safeName.substringAfterLast('.', "").equals("ovpn", ignoreCase = true)) {
            "Выбери файл с расширением .ovpn."
        }

        val bytes = readBounded(input)
        require(bytes.isNotEmpty()) { "Файл пустой." }
        require(bytes.none { it == 0.toByte() }) { "Файл содержит бинарные данные." }

        val text = try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes))
                .toString()
        } catch (_: Exception) {
            throw IllegalArgumentException("Профиль должен быть текстовым файлом UTF-8.")
        }
        require(text.isNotBlank()) { "Файл не содержит настроек." }

        val destination = uniqueFile(safeName)
        destination.writeBytes(bytes)
        return destination
    }

    private fun readBounded(input: InputStream): ByteArray {
        input.use { source ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val count = source.read(buffer)
                if (count < 0) break
                total += count
                require(total <= MAX_PROFILE_BYTES) {
                    "Размер .ovpn превышает лимит приложения 256 КиБ."
                }
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        }
    }

    private fun uniqueFile(displayName: String): File {
        val base = displayName.substringBeforeLast('.')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('.', '_', '-')
            .take(48)
            .ifBlank { "openvpn-profile" }

        var candidate = File(directory, "$base.ovpn")
        var suffix = 2
        while (candidate.exists()) {
            candidate = File(directory, "$base-$suffix.ovpn")
            suffix++
        }
        return candidate
    }

    private companion object {
        const val MAX_PROFILE_BYTES = 256 * 1024
    }
}
