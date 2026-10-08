import { Router } from 'express';
import {
  signup,
  login,
  getProfile,
  updateProfile,
  changePassword,
  deleteAccount,
  googleAuth,
  sendPhoneOtp,
  verifyPhoneOtp,
} from '../controllers/authController';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// Public routes
router.post('/signup', signup);
router.post('/login', login);
router.post('/google', googleAuth);
router.post('/phone/send-otp', sendPhoneOtp);
router.post('/phone/verify-otp', verifyPhoneOtp);

// Protected routes
router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);
router.post('/change-password', authMiddleware, changePassword);
router.delete('/account', authMiddleware, deleteAccount);

export default router;
