import { Router } from 'express';
import {
  createActivity,
  getActivities,
  getActivityById,
  updateActivity,
  deleteActivity,
  deleteGroup,
  renameGroup,
} from '../controllers/activityController';

const router = Router();

router.post('/', createActivity);
router.get('/', getActivities);
router.delete('/group/:groupName', deleteGroup);
router.put('/group/:groupName/rename', renameGroup);
router.get('/:id', getActivityById);
router.put('/:id', updateActivity);
router.delete('/:id', deleteActivity);

export default router;
