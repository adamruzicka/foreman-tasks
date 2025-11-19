import { forceCancelTask } from '../../TasksTableActions';
import { createTaskModal } from './createTaskModal';

const ForceUnlockModal = createTaskModal({
  actionCreator: forceCancelTask,
  title: 'Force Unlock Task',
  messageTemplate:
    'This will force unlock task "%(taskName)s". This may cause harm and should be used with caution. Are you sure?',
  confirmButtonVariant: 'danger',
  ouiaIdPrefix: 'force-unlock',
});

export default ForceUnlockModal;
