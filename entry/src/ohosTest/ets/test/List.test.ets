import abilityTest from './Ability.test';
import continuationTest from './Continuation.test';
import dataExportTest from './DataExport.test';

export default function testsuite() {
  abilityTest();
  continuationTest();
  dataExportTest();
}
