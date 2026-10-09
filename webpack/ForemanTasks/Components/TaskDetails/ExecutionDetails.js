import React from 'react';
import PropTypes from 'prop-types';
import { Alert, AlertVariant } from '@patternfly/react-core';
import { translate as __ } from 'foremanReact/common/I18n';
import RunningSteps from './Components/RunningSteps';
import Errors from './Components/Errors';

const ExecutionDetails = ({
  state,
  runningSteps,
  cancelStep,
  id,
  taskReload,
  taskReloadStart,
  executionPlan,
  failedSteps,
  result,
  usesDynflow,
}) => {
  const hasFailedSteps = failedSteps.length > 0;
  const hasRunningSteps = runningSteps.length > 0;
  const isActiveExecutionState =
    state === 'running' || state === 'pending' || state === 'paused';

  // Prefer Errors when failed steps exist (e.g. paused-after-error). Only fall
  // back to the RunningSteps empty state for active tasks with no failures.
  const showRunningSteps =
    usesDynflow &&
    (hasRunningSteps || (isActiveExecutionState && !hasFailedSteps));
  const showJobStatus = !usesDynflow && state !== 'stopped' && !hasFailedSteps;
  const showErrors = hasFailedSteps || (!showRunningSteps && !showJobStatus);

  return (
    <div
      id="execution-details-panel"
      data-ouia-component-id="execution-details-panel"
    >
      {showJobStatus && (
        <Alert
          variant={AlertVariant.info}
          isInline
          title={
            state === 'running'
              ? __('Job is running')
              : __('Job is waiting to run')
          }
          ouiaId="active-job-status"
        />
      )}
      {showRunningSteps && (
        <RunningSteps
          executionPlan={executionPlan}
          result={result}
          runningSteps={runningSteps}
          id={id}
          cancelStep={cancelStep}
          taskReload={taskReload}
          taskReloadStart={taskReloadStart}
        />
      )}
      {showErrors && (
        <Errors
          executionPlan={executionPlan}
          failedSteps={failedSteps}
          requiresExecutionPlan={usesDynflow}
        />
      )}
    </div>
  );
};

ExecutionDetails.propTypes = {
  state: PropTypes.string,
  result: PropTypes.string,
  runningSteps: PropTypes.array,
  cancelStep: PropTypes.func.isRequired,
  id: PropTypes.string.isRequired,
  taskReload: PropTypes.bool.isRequired,
  taskReloadStart: PropTypes.func.isRequired,
  executionPlan: PropTypes.shape({}),
  failedSteps: PropTypes.array,
  usesDynflow: PropTypes.bool,
};

ExecutionDetails.defaultProps = {
  state: '',
  result: undefined,
  runningSteps: [],
  executionPlan: {},
  failedSteps: [],
  usesDynflow: true,
};

export default ExecutionDetails;
