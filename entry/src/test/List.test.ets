import dataFoundationTest from './DataFoundation.test'
import foundationTest from './Foundation.test'
import focusTimerEngineTest from './FocusTimerEngine.test'
import focusTimerCoordinatorTest from './FocusTimerCoordinator.test'
import focusPresentationTest from './FocusPresentation.test'
import focusSystemPolicyTest from './FocusSystemPolicy.test'
import insightsAggregatorTest from './InsightsAggregator.test'
import localUnitTest from './LocalUnit.test'
import rewardRulesTest from './RewardRules.test'
import taskManagementTest from './TaskManagement.test'
import authRulesTest from './AuthRules.test'

export default function testsuite() {
  dataFoundationTest()
  foundationTest()
  focusTimerEngineTest()
  focusTimerCoordinatorTest()
  focusPresentationTest()
  focusSystemPolicyTest()
  insightsAggregatorTest()
  localUnitTest()
  rewardRulesTest()
  taskManagementTest()
  authRulesTest()
}
