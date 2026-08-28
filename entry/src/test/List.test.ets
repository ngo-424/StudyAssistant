import dataFoundationTest from './DataFoundation.test'
import foundationTest from './Foundation.test'
import localUnitTest from './LocalUnit.test'
import taskManagementTest from './TaskManagement.test'

export default function testsuite() {
  dataFoundationTest()
  foundationTest()
  localUnitTest()
  taskManagementTest()
}
