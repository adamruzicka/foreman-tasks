import { bulkCancelBySearch, bulkCancelById } from '../../TasksBulkActions';
import { createBulkTaskModal } from './createBulkTaskModal';

const CancelSelectedModal = createBulkTaskModal({
  bulkActionBySearch: bulkCancelBySearch,
  bulkActionById: bulkCancelById,
  title: 'Cancel Selected Tasks',
  messageTemplate:
    'This will cancel %(number)s task(s), putting them in the stopped state. Are you sure?',
  confirmButtonVariant: 'primary',
  ouiaIdPrefix: 'cancel-selected',
});

export default CancelSelectedModal;
