import { describe, expect, it } from '@ohos/hypium'
import { AuthSessionPayload } from '../main/ets/features/auth/domain/AuthModels'
import { AuthRules } from '../main/ets/features/auth/domain/AuthRules'
import { AuthPresentation } from '../main/ets/features/auth/presentation/AuthPresentation'

export default function authRulesTest() {
  describe('AuthRules', () => {
    it('normalizes and validates email without changing valid identity', 0, () => {
      expect(AuthRules.normalizeEmail(' Learner@Example.COM ')).assertEqual('learner@example.com')
      expect(AuthRules.validEmail('learner@example.com')).assertTrue()
      expect(AuthRules.validEmail('not-an-email')).assertFalse()
    })

    it('accepts exactly six numeric verification digits', 0, () => {
      expect(AuthRules.validCode('123456')).assertTrue()
      expect(AuthRules.validCode('12345')).assertFalse()
      expect(AuthRules.validCode('12345a')).assertFalse()
    })

    it('builds a validated account session from the server payload', 0, () => {
      const payload: AuthSessionPayload = {
        account: { id: 'account-1', email: 'Learner@Example.com' },
        tokens: {
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          accessExpiresAt: '2026-08-29T08:15:00.000Z',
          refreshExpiresAt: '2026-09-28T08:00:00.000Z'
        }
      }
      const now: number = Date.parse('2026-08-29T08:00:00.000Z')
      const session = AuthRules.fromPayload(payload, 'device-1', now)
      expect(session.email).assertEqual('learner@example.com')
      expect(AuthRules.accessNeedsRefresh(session, now)).assertFalse()
      expect(AuthRules.refreshExpired(session, now)).assertFalse()
    })

    it('masks account email for compact account summaries', 0, () => {
      expect(AuthPresentation.maskEmail('learner@example.com')).assertEqual('le***@example.com')
      expect(AuthPresentation.maskEmail('a@example.com')).assertEqual('a***@example.com')
    })
  })
}
