import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type AnnouncementRecord = {
  id?: string
  title?: string
  category?: string
  status?: string
  image_url?: string
}

type DispatchLogRow = {
  id: string
  attempt_count: number
  provider_status: string
}

type OneSignalFilter = {
  field: 'tag'
  key: string
  relation: '=' | 'not_exists'
  value?: string
}

type NotificationTarget = {
  name: string
  soundEnabled: boolean
  filters: OneSignalFilter[]
}

const MAX_TITLE_LENGTH = 120
const MAX_BODY_LENGTH = 220
const MAX_RETRY = 3
const CATEGORIES = ['umum', 'kesehatan', 'infrastruktur', 'keuangan', 'acara']

function parseIncomingPayload(rawBody: string): Record<string, unknown> {
  if (!rawBody.trim()) {
    throw new Error('Request body is empty')
  }

  try {
    const parsed = JSON.parse(rawBody)
    if (typeof parsed === 'string') {
      return JSON.parse(parsed) as Record<string, unknown>
    }
    return parsed as Record<string, unknown>
  } catch (_) {
    const preview = rawBody.length > 180 ? `${rawBody.slice(0, 180)}...` : rawBody
    throw new Error(`Invalid JSON body. Raw preview: ${preview}`)
  }
}

function getOneSignalConfig() {
  const appId = Deno.env.get('ONESIGNAL_APP_ID') ?? ''
  const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? ''
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const soundAndroidChannelId =
    Deno.env.get('ONESIGNAL_SOUND_ANDROID_CHANNEL_ID') ??
    'announcement_channel_sound_v3'
  const silentAndroidChannelId =
    Deno.env.get('ONESIGNAL_SILENT_ANDROID_CHANNEL_ID') ??
    'announcement_channel_silent_v1'

  if (!appId || !apiKey || !supabaseUrl || !supabaseKey) {
    throw new Error(
      'Missing required secrets: ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY',
    )
  }

  return {
    appId,
    apiKey,
    supabaseUrl,
    supabaseKey,
    soundAndroidChannelId,
    silentAndroidChannelId,
  }
}

function isValidImageUrl(value: string): boolean {
  return value.startsWith('http://') || value.startsWith('https://')
}

function truncate(value: string, max: number): string {
  return value.length > max ? value.slice(0, max) : value
}

function shouldRetry(statusCode: number): boolean {
  return statusCode === 429 || (statusCode >= 500 && statusCode < 600)
}

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms))
}

function normalizeCategory(value: string): string {
  const normalized = value.trim().toLowerCase()
  if (CATEGORIES.includes(normalized)) return normalized
  throw new Error(`Unsupported announcement category: ${value}`)
}

function tagFilter(key: string, value: string): OneSignalFilter {
  return {
    field: 'tag',
    key,
    relation: '=',
    value,
  }
}

function missingTagFilter(key: string): OneSignalFilter {
  return {
    field: 'tag',
    key,
    relation: 'not_exists',
  }
}

function buildNotificationTargets(category: string): NotificationTarget[] {
  const categorySoundTag = `sound_category_${category}`
  const notifAllowed = tagFilter('notif_allowed', '1')

  // Each target becomes one OneSignal request so Android can use the correct
  // notification channel for sound or silent delivery.
  return [
    {
      name: 'sound_legacy_untagged',
      soundEnabled: true,
      filters: [
        missingTagFilter('notif_allowed'),
      ],
    },
    {
      name: 'sound_per_category',
      soundEnabled: true,
      filters: [
        notifAllowed,
        tagFilter('sound_mode_per_category', '1'),
        tagFilter(categorySoundTag, '1'),
      ],
    },
    {
      name: 'sound_default',
      soundEnabled: true,
      filters: [
        notifAllowed,
        tagFilter('sound_mode_per_category', '0'),
        tagFilter('sound_default_enabled', '1'),
      ],
    },
    {
      name: 'silent_per_category',
      soundEnabled: false,
      filters: [
        notifAllowed,
        tagFilter('sound_mode_per_category', '1'),
        tagFilter(categorySoundTag, '0'),
      ],
    },
    {
      name: 'silent_default',
      soundEnabled: false,
      filters: [
        notifAllowed,
        tagFilter('sound_mode_per_category', '0'),
        tagFilter('sound_default_enabled', '0'),
      ],
    },
  ]
}

function getRecipientCount(response: unknown): number {
  if (!response || typeof response !== 'object') return 0
  const recipients = (response as { recipients?: unknown }).recipients
  return typeof recipients === 'number' ? recipients : 0
}

async function upsertDispatchLog(
  supabase: ReturnType<typeof createClient>,
  announcementId: string,
  updates: Record<string, unknown>,
): Promise<void> {
  await supabase
    .from('notification_dispatch_log')
    .upsert(
      {
        announcement_id: announcementId,
        event_type: 'published',
        ...updates,
      },
      { onConflict: 'announcement_id,event_type' },
    )
}

serve(async (req: Request) => {
  const requestId = crypto.randomUUID()
  const startedAt = Date.now()

  try {
    const payload = parseIncomingPayload(await req.text())
    const record = payload.record as AnnouncementRecord | undefined

    if (!record) {
      throw new Error('Missing record object in payload')
    }
    if (!record.id || !record.title || !record.category || !record.status) {
      throw new Error('Payload contract invalid: record.id/title/category/status are required')
    }
    if (record.status !== 'published') {
      return new Response(JSON.stringify({ message: 'Not published, ignoring.' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const category = normalizeCategory(record.category)
    const title = truncate(record.title.trim(), MAX_TITLE_LENGTH)
    const body = truncate(`Kategori: ${category}`, MAX_BODY_LENGTH)
    const imageUrl = (record.image_url ?? '').trim()
    const hasImage = imageUrl.length > 0 && isValidImageUrl(imageUrl)

    if (imageUrl.length > 0 && !hasImage) {
      throw new Error('image_url must be a valid http/https URL')
    }

    const {
      appId,
      apiKey,
      supabaseKey,
      supabaseUrl,
      soundAndroidChannelId,
      silentAndroidChannelId,
    } = getOneSignalConfig()
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { data: existingLog } = await supabase
      .from('notification_dispatch_log')
      .select('id,attempt_count,provider_status')
      .eq('announcement_id', record.id)
      .eq('event_type', 'published')
      .maybeSingle<DispatchLogRow>()

    if (existingLog?.provider_status === 'success') {
      console.log(
        JSON.stringify({
          level: 'info',
          request_id: requestId,
          announcement_id: record.id,
          action: 'idempotent_skip',
        }),
      )
      return new Response(
        JSON.stringify({
          success: true,
          skipped: true,
          reason: 'already_dispatched',
          request_id: requestId,
        }),
        { headers: { 'Content-Type': 'application/json' } },
      )
    }

    const baseRequestBody: Record<string, unknown> = {
      app_id: appId,
      target_channel: 'push',
      headings: {
        en: 'Pengumuman Desa Baru!',
      },
      contents: {
        en: title.length === 0 ? 'Ada pengumuman baru untuk Anda.' : title,
      },
      subtitle: { en: body },
      data: {
        announcement_id: String(record.id ?? ''),
        category,
      },
    }

    if (hasImage) {
      baseRequestBody.big_picture = imageUrl
      baseRequestBody.ios_attachments = { image: imageUrl }
      baseRequestBody.chrome_web_image = imageUrl
    }

    const targets = buildNotificationTargets(category)
    const targetMode = 'onesignal_tag_filters_by_sound_preference'
    const providerResponses: unknown[] = []
    let providerStatus = 'failed'
    let providerHttpStatus = 0
    let lastError = ''
    let attempts = existingLog?.attempt_count ?? 0
    let targetCount = 0

    for (const target of targets) {
      const requestBody: Record<string, unknown> = {
        ...baseRequestBody,
        filters: target.filters,
      }

      const channelId = target.soundEnabled
        ? soundAndroidChannelId.trim()
        : silentAndroidChannelId.trim()
      if (channelId.length > 0) {
        requestBody.existing_android_channel_id = channelId
      }
      if (target.soundEnabled) {
        requestBody.android_sound = 'announcement_tone'
      }

      let targetSucceeded = false
      let targetResponse: unknown = null
      for (let attempt = 1; attempt <= MAX_RETRY; attempt++) {
        attempts += 1
        const pushResponse = await fetch('https://api.onesignal.com/notifications', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Key ${apiKey}`,
          },
          body: JSON.stringify(requestBody),
        })

        providerHttpStatus = pushResponse.status
        targetResponse = await pushResponse.json()

        if (pushResponse.ok) {
          targetSucceeded = true
          break
        }

        lastError = JSON.stringify(targetResponse)
        if (!shouldRetry(pushResponse.status) || attempt === MAX_RETRY) {
          break
        }

        await sleep(400 * 2 ** (attempt - 1))
      }

      targetCount += getRecipientCount(targetResponse)

      providerResponses.push({
        target: target.name,
        sound_enabled: target.soundEnabled,
        channel_id: channelId || null,
        success: targetSucceeded,
        response: targetResponse,
      })

      if (!targetSucceeded) {
        providerStatus = 'failed'
        break
      }

      providerStatus = 'success'
    }

    await upsertDispatchLog(supabase, record.id, {
      request_id: requestId,
      target_mode: targetMode,
      target_count: targetCount,
      provider_status: providerStatus,
      provider_http_status: providerHttpStatus,
      provider_response: providerResponses,
      attempt_count: attempts,
      last_error: lastError || null,
      sent_at: providerStatus === 'success' ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    })

    const logPayload = {
      level: providerStatus === 'success' ? 'info' : 'error',
      request_id: requestId,
      announcement_id: record.id,
      category,
      target_mode: targetMode,
      target_count: targetCount,
      provider_status: providerStatus,
      provider_http_status: providerHttpStatus,
      duration_ms: Date.now() - startedAt,
    }
    console.log(JSON.stringify(logPayload))

    if (providerStatus !== 'success') {
      return new Response(
        JSON.stringify({
          success: false,
          provider: 'onesignal',
          status: providerHttpStatus,
          request_id: requestId,
          debug: {
            targetMode,
            targetCount,
            responses: providerResponses,
          },
          response: providerResponses,
        }),
        { headers: { 'Content-Type': 'application/json' }, status: 400 },
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        provider: 'onesignal',
        request_id: requestId,
        debug: {
          targetMode,
          targetCount,
        },
        response: providerResponses,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.log(
      JSON.stringify({
        level: 'error',
        request_id: requestId,
        provider_status: 'failed',
        error: (error as Error).message,
      }),
    )
    return new Response(
      JSON.stringify({
        success: false,
        request_id: requestId,
        error: (error as Error).message,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})
