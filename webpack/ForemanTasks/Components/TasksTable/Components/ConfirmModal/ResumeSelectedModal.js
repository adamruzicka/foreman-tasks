import { bulkResumeBySearch, bulkResumeById } from '../../TasksBulkActions';
import { createBulkTaskModal } from './createBulkTaskModal';

const ResumeSelectedModal = createBulkTaskModal({
  bulkActionBySearch: bulkResumeBySearch,
  bulkActionById: bulkResumeById,
  title: 'Resume Selected Tasks',
  messageTemplate:
    'This will resume %(number)s task(s), putting them in the running state. Are you sure?',
  confirmButtonVariant: 'primary',
  ouiaIdPrefix: 'resume-selected',
});

export default ResumeSelectedModal;
