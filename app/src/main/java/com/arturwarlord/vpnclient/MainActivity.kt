package com.arturwarlord.vpnclient

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.VpnService
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.ByteArrayInputStream
import java.io.File

class MainActivity : Activity() {
    private val pickProfileRequest = 4101
    private val vpnConsentRequest = 4102
    private var backend: GoBackend? = null
    private var profile: Config? = null
    private var isWorking = false
    private lateinit var statusView: TextView
    private lateinit var profileView: TextView
    private lateinit var connectButton: Button
    private lateinit var disconnectButton: Button

    private val tunnel = object : Tunnel {
        override fun getName(): String = "freeroute"

        override fun onStateChange(newState: Tunnel.State) {
            runOnUiThread {
                isWorking = newState == Tunnel.State.UP
                renderState(if (isWorking) "VPN подключён" else "VPN отключён")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(11, 16, 32)
        window.navigationBarColor = Color.rgb(11, 16, 32)
        backend = GoBackend(applicationContext)
        buildUi()
        loadSavedProfile()
    }

    private fun buildUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(30), dp(24), dp(24))
            setBackgroundColor(Color.rgb(11, 16, 32))
        }

        val brand = TextView(this).apply {
            text = "FreeRoute"
            textSize = 32f
            setTextColor(Color.WHITE)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(brand, matchWidthWrapHeight())

        val subtitle = TextView(this).apply {
            text = "Личный VPN-клиент"
            textSize = 15f
            setTextColor(Color.rgb(170, 184, 210))
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(30))
        }
        root.addView(subtitle, matchWidthWrapHeight())

        statusView = TextView(this).apply {
            text = "Профиль не подключён"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8), dp(22), dp(8), dp(22))
            background = rounded(Color.rgb(24, 34, 55), 18)
        }
        root.addView(statusView, matchWidthWrapHeight())

        profileView = TextView(this).apply {
            text = "Сначала импортируй VPN-профиль"
            textSize = 14f
            setTextColor(Color.rgb(170, 184, 210))
            gravity = Gravity.CENTER
            setPadding(dp(4), dp(20), dp(4), dp(20))
        }
        root.addView(profileView, matchWidthWrapHeight())

        val importButton = makeButton("Импортировать профиль", Color.rgb(47, 88, 158))
        importButton.setOnClickListener {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, pickProfileRequest)
        }
        root.addView(importButton, buttonLayout())

        connectButton = makeButton("Подключить VPN", Color.rgb(39, 142, 101))
        connectButton.setOnClickListener { requestConnection() }
        root.addView(connectButton, buttonLayout())

        disconnectButton = makeButton("Отключить", Color.rgb(74, 83, 104))
        disconnectButton.setOnClickListener { disconnect() }
        root.addView(disconnectButton, buttonLayout())

        val note = TextView(this).apply {
            text = "Профиль хранится только во внутренней памяти приложения. Не отправляй файл конфигурации другим людям: он содержит приватный ключ."
            textSize = 12f
            setTextColor(Color.rgb(140, 153, 177))
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, 0)
        }
        root.addView(note, matchWidthWrapHeight())
        setContentView(root)
    }

    private fun loadSavedProfile() {
        val file = File(filesDir, "active-profile.conf")
        if (!file.isFile) {
            renderState("Ожидает настройки")
            return
        }
        try {
            profile = parseConfig(file.readBytes())
            profileView.text = "Профиль загружен: сохранён локально"
            renderState("Готов к подключению")
        } catch (error: Exception) {
            profile = null
            profileView.text = "Сохранённый профиль не удалось прочитать. Импортируй его заново."
            renderState("Нужен новый профиль")
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickProfileRequest && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalArgumentException("Не удалось прочитать файл.")
                val parsed = parseConfig(bytes)
                File(filesDir, "active-profile.conf").writeBytes(bytes)
                profile = parsed
                profileView.text = "Профиль импортирован и сохранён на устройстве"
                renderState("Готов к подключению")
                Toast.makeText(this, "Профиль успешно импортирован", Toast.LENGTH_LONG).show()
            } catch (error: Exception) {
                profile = null
                profileView.text = "Импорт не удался. Выбери корректный WireGuard .conf файл."
                renderState("Ошибка профиля")
                Toast.makeText(this, "Не удалось прочитать профиль: проверь файл .conf", Toast.LENGTH_LONG).show()
            }
        } else if (requestCode == vpnConsentRequest && resultCode == RESULT_OK) {
            startTunnel()
        } else if (requestCode == vpnConsentRequest) {
            renderState("Подключение отменено")
        }
    }

    private fun parseConfig(bytes: ByteArray): Config =
        Config.parse(ByteArrayInputStream(bytes))

    private fun requestConnection() {
        if (profile == null) {
            Toast.makeText(this, "Сначала импортируй профиль сервера", Toast.LENGTH_LONG).show()
            return
        }
        val consent = VpnService.prepare(this)
        if (consent != null) {
            @Suppress("DEPRECATION")
            startActivityForResult(consent, vpnConsentRequest)
        } else {
            startTunnel()
        }
    }

    private fun startTunnel() {
        val config = profile ?: return
        val tunnelBackend = backend ?: GoBackend(applicationContext).also { backend = it }
        renderState("Подключаемся…")
        Thread {
            try {
                tunnelBackend.setState(tunnel, Tunnel.State.UP, config)
                runOnUiThread { renderState("VPN подключён") }
            } catch (error: Exception) {
                runOnUiThread {
                    renderState("Не удалось подключиться")
                    Toast.makeText(this, "Ошибка VPN. Проверь профиль и доступность сервера.", Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }

    private fun disconnect() {
        val tunnelBackend = backend
        if (tunnelBackend == null) {
            renderState("VPN отключён")
            return
        }
        renderState("Отключаемся…")
        Thread {
            try {
                tunnelBackend.setState(tunnel, Tunnel.State.DOWN, null)
                runOnUiThread { renderState("VPN отключён") }
            } catch (error: Exception) {
                runOnUiThread { renderState("Не удалось отключиться") }
            }
        }.start()
    }

    private fun renderState(message: String) {
        statusView.text = message
        connectButton.isEnabled = !isWorking
        disconnectButton.isEnabled = isWorking
    }

    private fun makeButton(label: String, color: Int): Button =
        Button(this).apply {
            text = label
            textSize = 15f
            isAllCaps = false
            setTextColor(Color.WHITE)
            background = rounded(color, 14)
            minimumHeight = dp(54)
        }

    private fun rounded(color: Int, radiusDp: Int) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun matchWidthWrapHeight() =
        LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)

    private fun buttonLayout() =
        LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10)
        }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
