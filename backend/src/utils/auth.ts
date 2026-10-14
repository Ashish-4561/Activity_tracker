import jwt from 'jsonwebtoken';
import bcryptjs from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

const isProduction = process.env.NODE_ENV === 'production';
const JWT_SECRET = process.env.JWT_SECRET || (isProduction ? '' : 'your_super_secret_key');

if (isProduction && (!JWT_SECRET || JWT_SECRET === 'your_super_secret_key')) {
  throw new Error('FATAL SECURITY ERROR: JWT_SECRET environment variable must be set to a secure string in production');
}

const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '7d';

export interface AuthToken {
  userId: string;
  email: string;
  iat?: number;
  exp?: number;
}

export function generateToken(userId: string, email: string): string {
  return jwt.sign(
    { userId, email },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRATION as any }
  );
}

export function verifyToken(token: string): AuthToken {
  try {
    return jwt.verify(token, JWT_SECRET) as AuthToken;
  } catch (error) {
    throw new Error('Invalid or expired token');
  }
}

export async function hashPassword(password: string): Promise<string> {
  const salt = await bcryptjs.genSalt(10);
  return bcryptjs.hash(password, salt);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  return bcryptjs.compare(password, hash);
}

export function generateId(): string {
  return uuidv4();
}

export function getCurrentDate(): string {
  return new Date().toISOString().split('T')[0];
}

export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}
