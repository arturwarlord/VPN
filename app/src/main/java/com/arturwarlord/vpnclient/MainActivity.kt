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
import android.provider.OpenableColumns
import android.view.Gravity
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.ByteArrayInputStream
import java.io.File
import java.net.Inet6Address

class MainActivity : Activity() {
    private val pickProfileRequest = 4101
    private val vpnConsentRequest = 4102
    private var backend: GoBackend? = null
    private var profile: Config? = null
    private var isConnected = false
    private var isBusy = false
    private var selectedProfileFileName: String? = null
    private val savedProfiles = mutableListOf<SavedProfile>()

    private lateinit var statusView: TextView
    private lateinit var profileView: TextView
    private lateinit var profileSpinner: Spinner
    private lateinit var importButton: Button
    private lateinit var connectButton: Button
    private lateinit var disconnectButton: Button

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
                renderState(if (isConnected) "VPN подключён" else "VPN отключён")
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

        val note = TextView(this).apply {
            text = "Каждый профиль хранится только на этом устройстве. Имя профиля можно использовать для обозначения страны, но фактическая страна выхода определяется удалённым сервером."
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
        Thread {
            try {
                tunnelBackend.setState(tunnel, Tunnel.State.UP, config)
                runOnUiThread {
                    isConnected = true
                    isBusy = false
                    renderState("VPN подключён")
                }
            } catch (_: Exception) {
                runOnUiThread {
                    isConnected = false
                    isBusy = false
                    renderState("Не удалось подключиться")
                    Toast.makeText(this, "Ошибка VPN. Проверь профиль и доступность сервера.", Toast.LENGTH_LONG).show()
                }
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
