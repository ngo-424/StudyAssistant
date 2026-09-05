import abilityTest from './Ability.test';
import continuationTest from './Continuation.test';
import dataExportTest from './DataExport.test';
import syncConflictTest from './SyncConflict.test';
import focusPresentationTest from '../../../test/FocusPresentation.test';
import focusTimerEngineTest from '../../../test/FocusTimerEngine.test';
import focusTimerCoordinatorTest from '../../../test/FocusTimerCoordinator.test';

export default function testsuite() {
  abilityTest();
  continuationTest();
  dataExportTest();
  syncConflictTest();
  focusPresentationTest();
  focusTimerEngineTest();
  focusTimerCoordinatorTest();
}
