import { resumeTask } from '../../TasksTableActions';
import { createTaskModal } from './createTaskModal';

const ResumeModal = createTaskModal({
  actionCreator: resumeTask,
  title: 'Resume Task',
  messageTemplate:
    'This will resume task "%(taskName)s", putting it in the running state. Are you sure?',
  confirmButtonVariant: 'primary',
  ouiaIdPrefix: 'resume',
});

export default ResumeModal;
