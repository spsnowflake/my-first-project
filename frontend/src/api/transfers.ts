export type TransferDirection = 'all' | 'in' | 'out'

export type TransferItem = {
  txHash: string
  logIndex: number
  blockNumber: number
  blockTimestamp: string
  from: string
  to: string
  value: string
  valueFormatted: string
  createdAt: string
}

export type TransfersResponse = {
  address: string
  total: number
  page: number
  limit: number
  items: TransferItem[]
}

function getApiBaseUrl(): string {
  const base = import.meta.env.VITE_API_BASE_URL?.trim()
  // 未配置时走同源 + Vite 代理（WSL 开发推荐，避免 Windows 浏览器连不上 :3000）
  if (!base) return ''
  return base.replace(/\/$/, '')
}

export async function fetchTransfers(
  address: string,
  options: {
    direction?: TransferDirection
    page?: number
    limit?: number
  } = {},
): Promise<TransfersResponse> {
  const params = new URLSearchParams()
  if (options.direction) params.set('direction', options.direction)
  if (options.page) params.set('page', String(options.page))
  if (options.limit) params.set('limit', String(options.limit))

  const qs = params.toString()
  const url = `${getApiBaseUrl()}/api/transfers/${address}${qs ? `?${qs}` : ''}`

  const res = await fetch(url)
  if (!res.ok) {
    let message = `请求失败 (${res.status})`
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      // ignore
    }
    throw new Error(message)
  }

  return (await res.json()) as TransfersResponse
}
