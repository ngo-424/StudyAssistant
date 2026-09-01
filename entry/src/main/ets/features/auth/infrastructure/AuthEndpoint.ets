import { DEBUG } from 'BuildProfile'

const DEVELOPMENT_API_BASE_URL: string = 'http://127.0.0.1:3000/v1'
// 上架前必须替换为经过备案且启用 HTTPS 的正式域名；.invalid 可确保未配置时不会误传数据。
const PRODUCTION_API_BASE_URL: string = 'https://api.studyassistant.invalid/v1'

export const AUTH_API_BASE_URL: string = DEBUG ? DEVELOPMENT_API_BASE_URL : PRODUCTION_API_BASE_URL
export const AUTH_API_CONFIGURED: boolean = DEBUG || !PRODUCTION_API_BASE_URL.includes('.invalid/')
