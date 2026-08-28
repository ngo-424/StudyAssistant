import dataFoundationTest from './DataFoundation.test'
import foundationTest from './Foundation.test'
import focusTimerEngineTest from './FocusTimerEngine.test'
import focusTimerCoordinatorTest from './FocusTimerCoordinator.test'
import focusPresentationTest from './FocusPresentation.test'
import localUnitTest from './LocalUnit.test'
import taskManagementTest from './TaskManagement.test'

export default function testsuite() {
  dataFoundationTest()
  foundationTest()
  focusTimerEngineTest()
  focusTimerCoordinatorTest()
  focusPresentationTest()
  localUnitTest()
  taskManagementTest()
}
