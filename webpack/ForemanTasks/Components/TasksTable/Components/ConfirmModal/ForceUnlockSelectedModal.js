import {
  bulkForceCancelBySearch,
  bulkForceCancelById,
} from '../../TasksBulkActions';
import { createBulkTaskModal } from './createBulkTaskModal';

const ForceUnlockSelectedModal = createBulkTaskModal({
  bulkActionBySearch: bulkForceCancelBySearch,
  bulkActionById: bulkForceCancelById,
  title: 'Force Unlock Selected Tasks',
  messageTemplate:
    'This will force unlock %(number)s task(s). This may cause harm and should be used with caution. Are you sure?',
  confirmButtonVariant: 'danger',
  ouiaIdPrefix: 'force-unlock-selected',
});

export default ForceUnlockSelectedModal;
