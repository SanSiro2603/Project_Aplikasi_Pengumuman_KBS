import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type AnnouncementRecord = {
  id?: string
  title?: string
  category?: string
  status?: string
}

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

  if (!appId || !apiKey) {
    throw new Error('Missing ONESIGNAL_APP_ID or ONESIGNAL_REST_API_KEY secret')
  }

  return { appId, apiKey }
}

function isUuid(value: string): boolean {
  const uuidV4Like =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return uuidV4Like.test(value)
}

serve(async (req: Request) => {
  try {
    const payload = parseIncomingPayload(await req.text())
    const record = payload.record as AnnouncementRecord | undefined

    if (record?.status !== 'published') {
      return new Response(
        JSON.stringify({ message: 'Not published, ignoring.' }),
        { headers: { 'Content-Type': 'application/json' } },
      )
    }

    const title = (record.title ?? '').trim()
    const { appId, apiKey } = getOneSignalConfig()
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    let subscriptionIds: string[] = []
    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey)
      const { data } = await supabase.from('device_tokens').select('token')
      subscriptionIds =
        (data ?? [])
          .map((row: { token?: string }) => (row.token ?? '').trim())
          .filter((token) => token.length > 0 && isUuid(token))
          .filter((token, index, arr) => arr.indexOf(token) === index)
    }

    const requestBody: Record<string, unknown> = {
      app_id: appId,
      target_channel: 'push',
      headings: {
        en: 'Pengumuman Desa Baru!',
      },
      contents: {
        en: title.length == 0 ? 'Ada pengumuman baru untuk Anda.' : title,
      },
      data: {
        announcement_id: String(record.id ?? ''),
        category: String(record.category ?? ''),
      },
      android_sound: 'announcement_tone',
    }
    if (subscriptionIds.length > 0) {
      requestBody.include_subscription_ids = subscriptionIds
    } else {
      requestBody.included_segments = ['Subscribed Users']
    }

    const pushResponse = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Key ${apiKey}`,
      },
      body: JSON.stringify(requestBody),
    })

    const pushJson = await pushResponse.json()
    if (!pushResponse.ok) {
      return new Response(
        JSON.stringify({
          success: false,
          provider: 'onesignal',
          status: pushResponse.status,
          debug: {
            targetMode:
              subscriptionIds.length > 0 ? 'include_subscription_ids' : 'included_segments',
            subscriptionCount: subscriptionIds.length,
            sampleSubscriptionIds: subscriptionIds.slice(0, 3),
          },
          response: pushJson,
        }),
        { headers: { 'Content-Type': 'application/json' }, status: 400 },
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        provider: 'onesignal',
        debug: {
          targetMode:
            subscriptionIds.length > 0 ? 'include_subscription_ids' : 'included_segments',
          subscriptionCount: subscriptionIds.length,
          sampleSubscriptionIds: subscriptionIds.slice(0, 3),
        },
        response: pushJson,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { 'Content-Type': 'application/json' }, status: 400 },
    )
  }
})
