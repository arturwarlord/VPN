package com.arturwarlord.vpnclient

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.database.Cursor
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.Gravity
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.ByteArrayInputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.Inet6Address
import java.net.URL
import org.json.JSONObject

class MainActivity : Activity() {
    private val pickProfileRequest = 4101
    private val vpnConsentRequest = 4102
    private var backend: GoBackend? = null
    private var profile: Config? = null
    private var isConnected = false
    private var isBusy = false
    private var isCheckingExit = false
    private var connectionStartedAtEpochMillis = 0L
    private var hasHandshakeForCurrentSession = false
    private var isHandshakeCheckRunning = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val handshakePollIntervalMs = 2_000L
    private val handshakeWarningAfterMs = 20_000L
    private val handshakePollRunnable = object : Runnable {
        override fun run() = checkWireGuardHandshake()
    }
    private var selectedProfileFileName: String? = null
    private val savedProfiles = mutableListOf<SavedProfile>()

    private lateinit var statusView: TextView
    private lateinit var profileView: TextView
    private lateinit var profileSpinner: Spinner
    private lateinit var importButton: Button
    private lateinit var connectButton: Button
    private lateinit var disconnectButton: Button
    private lateinit var checkCountryButton: Button

    private data class SavedProfile(
        val fileName: String,
        val label: String,
        val config: Config
    )

    private val tunnel = object : Tunnel {
        override fun getName(): String = "freeroute"

        override fun onStateChange(newState: Tunnel.State) {
            runOnUiThread {
                isConnected = newState == Tunnel.State.UP
                isBusy = false
                if (isConnected) {
                    if (connectionStartedAtEpochMillis == 0L) {
                        connectionStartedAtEpochMillis = System.currentTimeMillis()
                    }
                    renderState("Туннель включён · ждём ответа сервера")
                    scheduleHandshakeCheck()
                } else {
                    mainHandler.removeCallbacks(handshakePollRunnable)
                    connectionStartedAtEpochMillis = 0L
                    hasHandshakeForCurrentSession = false
                    renderState("VPN отключён")
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(11, 16, 32)
        window.navigationBarColor = Color.rgb(11, 16, 32)
        backend = GoBackend(applicationContext)
        buildUi()
        loadSavedProfiles()
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
            setPadding(0, dp(8), 0, dp(26))
        }
        root.addView(subtitle, matchWidthWrapHeight())

        statusView = TextView(this).apply {
            text = "Ожидает настройки"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8), dp(22), dp(8), dp(22))
            background = rounded(Color.rgb(24, 34, 55), 18)
        }
        root.addView(statusView, matchWidthWrapHeight())

        profileView = TextView(this).apply {
            text = "Импортируй профиль сервера, чтобы начать"
            textSize = 14f
            setTextColor(Color.rgb(170, 184, 210))
            gravity = Gravity.CENTER
            setPadding(dp(4), dp(12), dp(4), dp(8))
        }
        root.addView(profileView, matchWidthWrapHeight())

        val profileLabel = TextView(this).apply {
            text = "ВЫБРАННЫЙ ПРОФИЛЬ / СЕРВЕР"
            textSize = 11f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.rgb(140, 153, 177))
            setPadding(0, dp(8), 0, dp(4))
        }
        root.addView(profileLabel, matchWidthWrapHeight())

        profileSpinner = Spinner(this).apply {
            minimumHeight = dp(48)
            background = rounded(Color.rgb(24, 34, 55), 12)
            setPadding(dp(12), 0, dp(12), 0)
        }
        root.addView(profileSpinner, matchWidthWrapHeight())

        importButton = makeButton("Добавить профиль", Color.rgb(47, 88, 158))
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

        checkCountryButton = makeButton("Проверить страну выхода", Color.rgb(52, 83, 133))
        checkCountryButton.setOnClickListener { checkExitCountry() }
        root.addView(checkCountryButton, buttonLayout())

        val licensesButton = makeButton("О лицензиях", Color.rgb(36, 48, 71))
        licensesButton.setOnClickListener { showLicenses() }
        root.addView(licensesButton, buttonLayout())

        val note = TextView(this).apply {
            text = "Каждый профиль хранится только на этом устройстве. Имя профиля не подтверждает страну выхода. Проверка по кнопке отправляет текущий публичный IP сервису ipwho.is; результат приблизительный и не сохраняется."
            textSize = 12f
            setTextColor(Color.rgb(140, 153, 177))
            gravity = Gravity.CENTER
            setPadding(0, dp(20), 0, 0)
        }
        root.addView(note, matchWidthWrapHeight())
        setContentView(root)
    }

    private fun loadSavedProfiles(preferredFileName: String? = null) {
        val directory = profilesDirectory()
        savedProfiles.clear()
        directory.listFiles()
            ?.filter { it.isFile && it.extension.equals("conf", ignoreCase = true) }
            ?.sortedBy { it.name.lowercase() }
            ?.forEach { file ->
                try {
                    val parsed = file.inputStream().use { Config.parse(it) }
                    val label = file.nameWithoutExtension.replace('_', ' ')
                    savedProfiles.add(SavedProfile(file.name, label, parsed))
                } catch (_: Exception) {
                    // Ignore invalid profile files; imports are validated before saving.
                }
            }

        val prefs = getSharedPreferences("freeroute_settings", MODE_PRIVATE)
        val wantedFileName = preferredFileName ?: prefs.getString("active_profile", null)
        val selectedIndex = savedProfiles.indexOfFirst { it.fileName == wantedFileName }
            .let { if (it >= 0) it else 0 }

        profileSpinner.onItemSelectedListener = null
        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            savedProfiles.map { it.label }.ifEmpty { listOf("Нет импортированных профилей") }
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        profileSpinner.adapter = adapter
        profileSpinner.setSelection(selectedIndex, false)

        val selected = savedProfiles.getOrNull(selectedIndex)
        selectedProfileFileName = selected?.fileName
        profile = selected?.config
        if (selected != null) {
            prefs.edit().putString("active_profile", selected.fileName).apply()
            profileView.text = describeProfile(selected)
        } else {
            profileView.text = describeProfile(null)
            prefs.edit().remove("active_profile").apply()
        }

        profileSpinner.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: android.widget.AdapterView<*>?,
                view: android.view.View?,
                position: Int,
                id: Long
            ) {
                val entry = savedProfiles.getOrNull(position) ?: return
                if (isConnected || isBusy) return
                selectedProfileFileName = entry.fileName
                profile = entry.config
                prefs.edit().putString("active_profile", entry.fileName).apply()
                profileView.text = describeProfile(entry)
                renderState("Готов к подключению")
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) = Unit
        }

        renderState(if (profile != null) "Готов к подключению" else "Ожидает профиль")
    }

    private fun profileIncludesIpv6DefaultRoute(config: Config): Boolean =
        config.peers.any { peer ->
            peer.allowedIps.any { network ->
                network.address is Inet6Address && network.mask == 0
            }
        }

    private fun describeProfile(entry: SavedProfile?): String {
        if (entry == null) return "Добавь WireGuard .conf профиль сервера"
        val base = "Профиль: " + entry.label
        return if (profileIncludesIpv6DefaultRoute(entry.config)) {
            base + " · IPv6-маршрут есть (сервер всё равно нужно проверить)"
        } else {
            base + " · ⚠ IPv6 не включён — возможна утечка"
        }
    }

    private fun profilesDirectory(): File =
        File(filesDir, "profiles").apply { mkdirs() }

    private fun displayNameFor(uri: android.net.Uri): String {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor: Cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && column >= 0) {
                cursor.getString(column)?.let { return it }
            }
        }
        return "profile-${System.currentTimeMillis()}.conf"
    }

    private fun uniqueProfileFile(displayName: String): File {
        val originalBase = displayName.substringAfterLast('/').substringBeforeLast('.', displayName)
        val safeBase = originalBase
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('.', '_', '-')
            .take(48)
            .ifBlank { "profile" }

        val directory = profilesDirectory()
        var candidate = File(directory, "${safeBase}.conf")
        var suffix = 2
        while (candidate.exists()) {
            candidate = File(directory, "${safeBase}-${suffix}.conf")
            suffix++
        }
        return candidate
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickProfileRequest && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalArgumentException("Не удалось прочитать файл.")
                Config.parse(ByteArrayInputStream(bytes))
                val newFile = uniqueProfileFile(displayNameFor(uri))
                newFile.writeBytes(bytes)
                loadSavedProfiles(newFile.name)
                Toast.makeText(this, "Профиль добавлен: ${newFile.nameWithoutExtension}", Toast.LENGTH_LONG).show()
            } catch (_: Exception) {
                Toast.makeText(this, "Не удалось импортировать. Выбери корректный WireGuard .conf файл.", Toast.LENGTH_LONG).show()
            }
        } else if (requestCode == vpnConsentRequest && resultCode == RESULT_OK) {
            startTunnel()
        } else if (requestCode == vpnConsentRequest) {
            renderState("Подключение отменено")
        }
    }

    private fun scheduleHandshakeCheck(delayMs: Long = 1_000L) {
        mainHandler.removeCallbacks(handshakePollRunnable)
        mainHandler.postDelayed(handshakePollRunnable, delayMs)
    }

    /**
     * An UP interface only proves that the local WireGuard engine started.
     * A recent handshake with one of the configured peers proves that the
     * remote WireGuard endpoint answered this session.
     */
    private fun checkWireGuardHandshake() {
        if (!isConnected || isBusy || hasHandshakeForCurrentSession) return

        val tunnelBackend = backend ?: return
        val activeConfig = profile ?: return
        val startedAt = connectionStartedAtEpochMillis
        if (startedAt <= 0L) return

        if (isHandshakeCheckRunning) {
            scheduleHandshakeCheck(handshakePollIntervalMs)
            return
        }

        isHandshakeCheckRunning = true
        Thread {
            val handshakeReceived = try {
                val statistics = tunnelBackend.getStatistics(tunnel)
                activeConfig.peers.any { peer ->
                    val peerStats = statistics.peer(peer.publicKey)
                    peerStats != null &&
                        peerStats.latestHandshakeEpochMillis() >= startedAt
                }
            } catch (_: Exception) {
                false
            }

            runOnUiThread {
                isHandshakeCheckRunning = false
                if (!isConnected || connectionStartedAtEpochMillis != startedAt) return@runOnUiThread

                if (handshakeReceived) {
                    hasHandshakeForCurrentSession = true
                    renderState("VPN подключён · сервер ответил")
                } else {
                    val elapsed = System.currentTimeMillis() - startedAt
                    renderState(
                        if (elapsed >= handshakeWarningAfterMs) {
                            "Туннель включён · сервер не ответил"
                        } else {
                            "Подключаемся · ждём ответа сервера"
                        }
                    )
                    scheduleHandshakeCheck(handshakePollIntervalMs)
                }
            }
        }.start()
    }

    private fun requestConnection() {
        if (profile == null) {
            Toast.makeText(this, "Сначала добавь профиль сервера", Toast.LENGTH_LONG).show()
            return
        }
        if (isBusy || isConnected) return

        val chosenProfile = profile ?: return
        if (!profileIncludesIpv6DefaultRoute(chosenProfile)) {
            AlertDialog.Builder(this)
                .setTitle("Возможна утечка IPv6")
                .setMessage(
                    "Этот профиль не направляет IPv6-трафик через VPN. Некоторые сайты могут увидеть исходное подключение и его страну. Можно отменить подключение или продолжить с этим риском. Даже при наличии маршрута IPv6 его работу нужно проверять на сервере."
                )
                .setNegativeButton("Отмена", null)
                .setPositiveButton("Продолжить") { _, _ -> requestVpnPermissionAndStart() }
                .show()
            return
        }
        requestVpnPermissionAndStart()
    }

    private fun requestVpnPermissionAndStart() {
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
        if (isBusy || isConnected) return
        val tunnelBackend = backend ?: GoBackend(applicationContext).also { backend = it }
        isBusy = true
        renderState("Подключаемся…")
        connectionStartedAtEpochMillis = System.currentTimeMillis()
        hasHandshakeForCurrentSession = false
        Thread {
            try {
                val resultingState = tunnelBackend.setState(tunnel, Tunnel.State.UP, config)
                runOnUiThread {
                    isConnected = resultingState == Tunnel.State.UP
                    isBusy = false
                    if (isConnected) {
                        renderState("Туннель включён · ждём ответа сервера")
                        scheduleHandshakeCheck()
                    } else {
                        renderState("VPN не запущен")
                    }
                }
            } catch (_: Exception) {
                mainHandler.removeCallbacks(handshakePollRunnable)
                runOnUiThread {
                    isConnected = false
                    isBusy = false
                    connectionStartedAtEpochMillis = 0L
                    hasHandshakeForCurrentSession = false
                    renderState("Не удалось подключиться")
                    Toast.makeText(this, "Ошибка VPN. Проверь профиль и доступность сервера.", Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }

    private fun checkExitCountry() {
        if (!isConnected || !hasHandshakeForCurrentSession || isBusy || isCheckingExit) {
            val message = if (isConnected && !hasHandshakeForCurrentSession) {
                "Удалённый сервер ещё не ответил: WireGuard handshake не подтверждён."
            } else {
                "Сначала подключи VPN"
            }
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
            return
        }

        isCheckingExit = true
        checkCountryButton.isEnabled = false
        Thread {
            var title = "Проверка страны выхода"
            var message: String
            var connection: HttpURLConnection? = null

            try {
                connection = URL("https://ipwho.is/?fields=success,ip,country,country_code")
                    .openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("Accept", "application/json")

                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IllegalStateException("Сервис геолокации вернул HTTP $code.")
                }

                val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val json = JSONObject(body)
                if (!json.optBoolean("success", false)) {
                    throw IllegalStateException("Сервис не смог определить страну текущего IP.")
                }

                val ip = json.optString("ip")
                val country = json.optString("country")
                val countryCode = json.optString("country_code")
                if (ip.isBlank() || country.isBlank() || countryCode.length != 2) {
                    throw IllegalStateException("Сервис вернул неполные сведения о стране.")
                }

                message = "Публичный IP: $ip\nОпределяемая страна: $country ($countryCode)\n\nЭто геолокация по IP, а не абсолютная гарантия. Запрос получил сервис ipwho.is; если туннель отключился во время проверки, он может увидеть IP основного подключения."
            } catch (error: Exception) {
                title = "Не удалось проверить страну"
                message = "Проверь подключение к VPN и доступность сервиса геолокации. Проверка не сохраняет IP в приложении.\n\nПричина: ${error.message ?: error.javaClass.simpleName}"
            } finally {
                connection?.disconnect()
            }

            runOnUiThread {
                isCheckingExit = false
                checkCountryButton.isEnabled = isConnected && !isBusy
                AlertDialog.Builder(this)
                    .setTitle(title)
                    .setMessage(message)
                    .setPositiveButton("Закрыть", null)
                    .show()
            }
        }.start()
    }

    private fun disconnect() {
        val tunnelBackend = backend
        if (tunnelBackend == null || !isConnected || isBusy) {
            renderState(if (isConnected) "VPN подключён" else "VPN отключён")
            return
        }
        isBusy = true
        renderState("Отключаемся…")
        Thread {
            try {
                tunnelBackend.setState(tunnel, Tunnel.State.DOWN, null)
                runOnUiThread {
                    isConnected = false
                    isBusy = false
                    renderState("VPN отключён")
                }
            } catch (_: Exception) {
                runOnUiThread {
                    isBusy = false
                    renderState("Не удалось отключиться")
                    Toast.makeText(this, "Не удалось отключить VPN. Попробуй ещё раз.", Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }

    private fun renderState(message: String) {
        statusView.text = message
        val canEdit = !isConnected && !isBusy
        importButton.isEnabled = canEdit
        profileSpinner.isEnabled = canEdit && savedProfiles.isNotEmpty()
        connectButton.isEnabled = profile != null && canEdit
        disconnectButton.isEnabled = isConnected && !isBusy
        checkCountryButton.isEnabled = isConnected && hasHandshakeForCurrentSession && !isBusy && !isCheckingExit
    }

    private fun showLicenses() {
        val licenseText = try {
            assets.open("THIRD_PARTY_NOTICES.txt").bufferedReader(Charsets.UTF_8).use { it.readText() }
        } catch (_: Exception) {
            "Не удалось открыть сведения о лицензиях. Исходный текст доступен в репозитории FreeRoute VPN."
        }
        val body = TextView(this).apply {
            text = licenseText
            textSize = 12f
            setTextColor(Color.DKGRAY)
            setTextIsSelectable(true)
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            addView(
                body,
                android.widget.FrameLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
        }
        AlertDialog.Builder(this)
            .setTitle("Открытые лицензии")
            .setView(scroll)
            .setPositiveButton("Закрыть", null)
            .show()
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
