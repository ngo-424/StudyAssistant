import dataFoundationTest from './DataFoundation.test'
import foundationTest from './Foundation.test'
import localUnitTest from './LocalUnit.test'

export default function testsuite() {
  dataFoundationTest()
  foundationTest()
  localUnitTest()
}
