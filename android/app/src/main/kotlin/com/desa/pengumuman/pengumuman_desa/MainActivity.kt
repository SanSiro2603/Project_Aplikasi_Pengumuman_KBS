package com.desa.pengumuman.pengumuman_desa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.content.Context
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAnnouncementChannel()
    }

    private fun createAnnouncementChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundChannelId = "announcement_channel_sound_v3"
        val silentChannelId = "announcement_channel_silent_v1"
        val channelDescription = "Notifikasi pengumuman warga"

        // Android 8+ locks notification sound per channel, so sound and silent
        // notifications must use separate channel ids.
        val soundUri = Uri.parse("android.resource://$packageName/raw/announcement_tone")
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val soundChannel = NotificationChannel(
            soundChannelId,
            "Pengumuman Desa - Bersuara",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = channelDescription
            enableVibration(true)
            setSound(soundUri, audioAttributes)
        }

        val silentChannel = NotificationChannel(
            silentChannelId,
            "Pengumuman Desa - Senyap",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = channelDescription
            enableVibration(true)
            setSound(null, null)
        }

        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(soundChannel)
        manager.createNotificationChannel(silentChannel)
    }
}
