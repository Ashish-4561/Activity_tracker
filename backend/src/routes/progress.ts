import { Router } from 'express';
import {
  getDailyProgress,
  getWeeklyProgress,
  getMonthlyProgress,
  getStreakData,
  getRangeProgress,
} from '../controllers/progressController';

const router = Router();

router.get('/daily', getDailyProgress);
router.get('/weekly', getWeeklyProgress);
router.get('/monthly', getMonthlyProgress);
router.get('/streak', getStreakData);
router.get('/range', getRangeProgress);

export default router;
