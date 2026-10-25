import { Router } from 'express';
import {
  completeActivity,
  uncompleteActivity,
  getCompletionsByDate,
  getCompletionHistory,
  trackActivityDuration,
} from '../controllers/completionController';

const router = Router();

router.post('/complete', completeActivity);
router.post('/uncomplete', uncompleteActivity);
router.post('/track-duration', trackActivityDuration);
router.get('/by-date', getCompletionsByDate);
router.get('/history', getCompletionHistory);

export default router;
