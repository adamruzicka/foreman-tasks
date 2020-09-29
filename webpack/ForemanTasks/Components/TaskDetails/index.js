import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';
import TaskDetails from './TaskDetails';
import * as taskDetailsActions from './TaskDetailsActions';
import * as taskActions from '../TaskActions';
import {
  selectEndedAt,
  selectStartAt,
  selectStartBefore,
  selectStartedAt,
  selectLocks,
  selectLinks,
  selectInput,
  selectOutput,
  selectResumable,
  selectCancellable,
  selectHelp,
  selectErrors,
  selectProgress,
  selectUsername,
  selectLabel,
  selectExecutionPlan,
  selectFailedSteps,
  selectRunningSteps,
  selectHasSubTasks,
  selectUsernamePath,
  selectAction,
  selectState,
  selectResult,
  selectTimeoutId,
  selectTaskReload,
  selectParentTask,
  selectExternalId,
  selectDynflowEnableConsole,
  selectCanEdit,
  selectStatus,
  selectAPIError,
  selectIsLoading,
} from './TaskDetailsSelectors';

const mapStateToProps = state => ({
  startAt: selectStartAt(state),
  startBefore: selectStartBefore(state),
  startedAt: selectStartedAt(state),
  endedAt: selectEndedAt(state),
  input: selectInput(state),
  output: selectOutput(state),
  resumable: selectResumable(state),
  cancellable: selectCancellable(state),
  errors: selectErrors(state),
  progress: selectProgress(state),
  username: selectUsername(state),
  label: selectLabel(state),
  executionPlan: selectExecutionPlan(state),
  failedSteps: selectFailedSteps(state),
  runningSteps: selectRunningSteps(state),
  help: selectHelp(state),
  hasSubTasks: selectHasSubTasks(state),
  locks: selectLocks(state),
  links: selectLinks(state),
  usernamePath: selectUsernamePath(state),
  action: selectAction(state),
  state: selectState(state),
  result: selectResult(state),
  timeoutId: selectTimeoutId(state),
  taskReload: selectTaskReload(state),
  parentTask: selectParentTask(state),
  externalId: selectExternalId(state),
  dynflowEnableConsole: selectDynflowEnableConsole(state),
  canEdit: selectCanEdit(state),
  status: selectStatus(state),
  APIerror: selectAPIError(state),
  isLoading: selectIsLoading(state),
});

const mapDispatchToProps = dispatch =>
  bindActionCreators({ ...taskActions, ...taskDetailsActions }, dispatch);

export default connect(mapStateToProps, mapDispatchToProps)(TaskDetails);
