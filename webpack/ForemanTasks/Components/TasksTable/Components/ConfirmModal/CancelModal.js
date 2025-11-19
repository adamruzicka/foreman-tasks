import { cancelTask } from '../../TasksTableActions';
import { createTaskModal } from './createTaskModal';

const CancelModal = createTaskModal({
  actionCreator: cancelTask,
  title: 'Cancel Task',
  messageTemplate:
    'This will cancel task "%(taskName)s", putting it in the stopped state. Are you sure?',
  confirmButtonVariant: 'primary',
  ouiaIdPrefix: 'cancel',
});

export default CancelModal;
