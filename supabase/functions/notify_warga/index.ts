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

const MAX_TITLE_LENGTH = 120
const MAX_BODY_LENGTH = 220
const MAX_RETRY = 3

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
  const existingAndroidChannelId =
    Deno.env.get('ONESIGNAL_EXISTING_ANDROID_CHANNEL_ID') ??
    'announcement_channel_v2'

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
    existingAndroidChannelId,
  }
}

function isUuid(value: string): boolean {
  const uuidV4Like =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return uuidV4Like.test(value)
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

    const title = truncate(record.title.trim(), MAX_TITLE_LENGTH)
    const body = truncate(`Kategori: ${record.category}`, MAX_BODY_LENGTH)
    const imageUrl = (record.image_url ?? '').trim()
    const hasImage = imageUrl.length > 0 && isValidImageUrl(imageUrl)

    if (imageUrl.length > 0 && !hasImage) {
      throw new Error('image_url must be a valid http/https URL')
    }

    const { appId, apiKey, supabaseKey, supabaseUrl, existingAndroidChannelId } =
      getOneSignalConfig()
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

    let subscriptionIds: string[] = []
    const { data: tokens } = await supabase.from('device_tokens').select('token')
    subscriptionIds =
      (tokens ?? [])
        .map((row: { token?: string }) => (row.token ?? '').trim())
        .filter((token) => token.length > 0 && isUuid(token))
        .filter((token, index, arr) => arr.indexOf(token) === index)

    const targetMode =
      subscriptionIds.length > 0 ? 'include_subscription_ids' : 'included_segments'

    const requestBody: Record<string, unknown> = {
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
        category: String(record.category ?? ''),
      },
      android_sound: 'announcement_tone',
    }

    if (existingAndroidChannelId.trim().length > 0) {
      requestBody.existing_android_channel_id = existingAndroidChannelId.trim()
    }

    if (hasImage) {
      requestBody.big_picture = imageUrl
      requestBody.ios_attachments = { image: imageUrl }
      requestBody.chrome_web_image = imageUrl
    }

    if (subscriptionIds.length > 0) {
      requestBody.include_subscription_ids = subscriptionIds
    } else {
      requestBody.included_segments = ['Subscribed Users']
    }

    let providerStatus = 'failed'
    let providerHttpStatus = 0
    let providerResponse: unknown = null
    let lastError = ''
    let attempts = existingLog?.attempt_count ?? 0

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
      providerResponse = await pushResponse.json()

      if (pushResponse.ok) {
        providerStatus = 'success'
        break
      }

      lastError = JSON.stringify(providerResponse)
      if (!shouldRetry(pushResponse.status) || attempt === MAX_RETRY) {
        break
      }

      await sleep(400 * 2 ** (attempt - 1))
    }

    await upsertDispatchLog(supabase, record.id, {
      request_id: requestId,
      target_mode: targetMode,
      target_count: subscriptionIds.length,
      provider_status: providerStatus,
      provider_http_status: providerHttpStatus,
      provider_response: providerResponse,
      attempt_count: attempts,
      last_error: lastError || null,
      sent_at: providerStatus === 'success' ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    })

    const logPayload = {
      level: providerStatus === 'success' ? 'info' : 'error',
      request_id: requestId,
      announcement_id: record.id,
      target_mode: targetMode,
      subscription_count: subscriptionIds.length,
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
            subscriptionCount: subscriptionIds.length,
            sampleSubscriptionIds: subscriptionIds.slice(0, 3),
          },
          response: providerResponse,
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
          subscriptionCount: subscriptionIds.length,
          sampleSubscriptionIds: subscriptionIds.slice(0, 3),
        },
        response: providerResponse,
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
