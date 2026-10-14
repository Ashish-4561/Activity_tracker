import {
  generateToken,
  verifyToken,
  hashPassword,
  comparePassword,
  validateEmail,
  getCurrentDate,
} from '../src/utils/auth';

describe('Backend Auth Utilities Unit Tests', () => {
  test('validateEmail validates email addresses correctly', () => {
    expect(validateEmail('user@example.com')).toBe(true);
    expect(validateEmail('test.name+tag@sub.domain.org')).toBe(true);
    expect(validateEmail('invalid-email')).toBe(false);
    expect(validateEmail('missing@domain')).toBe(false);
    expect(validateEmail('@missinguser.com')).toBe(false);
  });

  test('hashPassword and comparePassword work correctly', async () => {
    const password = 'SuperSecretPassword123!';
    const hash = await hashPassword(password);

    expect(hash).toBeDefined();
    expect(hash).not.toBe(password);
    expect(hash.startsWith('$2')).toBe(true);

    const matches = await comparePassword(password, hash);
    expect(matches).toBe(true);

    const wrongMatches = await comparePassword('WrongPassword', hash);
    expect(wrongMatches).toBe(false);
  });

  test('generateToken and verifyToken round-trip valid payload', () => {
    const userId = 'usr-123456';
    const email = 'ashish@example.com';

    const token = generateToken(userId, email);
    expect(token).toBeDefined();
    expect(typeof token).toBe('string');

    const decoded = verifyToken(token);
    expect(decoded.userId).toBe(userId);
    expect(decoded.email).toBe(email);
  });

  test('verifyToken throws on tampered token', () => {
    const token = generateToken('usr-1', 'test@test.com');
    const tampered = token.slice(0, -5) + 'abcde';

    expect(() => verifyToken(tampered)).toThrow('Invalid or expired token');
  });

  test('getCurrentDate returns YYYY-MM-DD formatted date', () => {
    const date = getCurrentDate();
    expect(date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});
