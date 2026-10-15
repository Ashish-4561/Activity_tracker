import { Router } from 'express';
import {
  getGardens,
  getGardenById,
  createOrGetGroup,
  renameGroupById,
  deleteGroupById,
} from '../controllers/gardenController';

const router = Router();

router.get('/', getGardens);
router.get('/:groupId', getGardenById);
router.post('/group', createOrGetGroup);
router.put('/group/:groupId/rename', renameGroupById);
router.delete('/group/:groupId', deleteGroupById);

export default router;
