jest.mock('../src/utils/jwt.util', () => ({ verifyToken: jest.fn() }));
jest.mock('../src/utils/logger.util', () => ({ error: jest.fn(), info: jest.fn(), warn: jest.fn() }));

const { verifyToken } = require('../src/utils/jwt.util');
const { authenticate, optionalAuthenticate } = require('../src/middleware/auth.middleware');

const responseMock = () => {
  const res = { status: jest.fn(), json: jest.fn() };
  res.status.mockReturnValue(res);
  res.json.mockReturnValue(res);
  return res;
};
const reqMock = (authorization) => ({ headers: authorization === undefined ? {} : { authorization } });

describe('authentication middleware branch behavior', () => {
  beforeEach(() => jest.clearAllMocks());

  test.each([undefined, 'Basic token', 'Bearer '])('rejects missing or malformed Authorization header: %s', (header) => {
    const req = reqMock(header);
    const res = responseMock();
    const next = jest.fn();
    authenticate(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: 'No token provided' });
    expect(next).not.toHaveBeenCalled();
    expect(verifyToken).not.toHaveBeenCalled();
  });

  test('attaches the decoded identity and proceeds for a valid bearer token', () => {
    verifyToken.mockReturnValueOnce({ user_id: 4, shop_id: 7, email: 'a@b.test' });
    const req = reqMock('Bearer signed-token');
    const next = jest.fn();
    authenticate(req, responseMock(), next);
    expect(verifyToken).toHaveBeenCalledWith('signed-token');
    expect(req.user).toEqual({ id: 4, shop_id: 7, email: 'a@b.test' });
    expect(next).toHaveBeenCalledTimes(1);
  });

  test.each([
    ['Token expired', 'Token expired'],
    ['Invalid token', 'Invalid token'],
    ['unexpected verify failure', 'Authentication failed'],
  ])('maps verify failure "%s" to an unauthorized response', (message, expected) => {
    verifyToken.mockImplementationOnce(() => { throw new Error(message); });
    const res = responseMock();
    const next = jest.fn();
    authenticate(reqMock('Bearer bad-token'), res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: expected });
    expect(next).not.toHaveBeenCalled();
  });

  test('optional authentication proceeds without a header or a bearer token', () => {
    const nextWithoutHeader = jest.fn();
    const reqWithoutHeader = reqMock();
    optionalAuthenticate(reqWithoutHeader, responseMock(), nextWithoutHeader);
    expect(nextWithoutHeader).toHaveBeenCalledTimes(1);
    expect(reqWithoutHeader.user).toBeUndefined();

    const nextWrongScheme = jest.fn();
    const reqWrongScheme = reqMock('Basic xyz');
    optionalAuthenticate(reqWrongScheme, responseMock(), nextWrongScheme);
    expect(nextWrongScheme).toHaveBeenCalledTimes(1);
    expect(reqWrongScheme.user).toBeUndefined();

    const nextEmpty = jest.fn();
    optionalAuthenticate(reqMock('Bearer '), responseMock(), nextEmpty);
    expect(nextEmpty).toHaveBeenCalledTimes(1);
    expect(verifyToken).not.toHaveBeenCalled();
  });

  test('optional authentication attaches valid identity and ignores invalid tokens', () => {
    verifyToken.mockReturnValueOnce({ user_id: 9, shop_id: null, email: 'optional@b.test' });
    const req = reqMock('Bearer optional-token');
    const next = jest.fn();
    optionalAuthenticate(req, responseMock(), next);
    expect(req.user).toEqual({ id: 9, shop_id: null, email: 'optional@b.test' });
    expect(next).toHaveBeenCalledTimes(1);

    verifyToken.mockImplementationOnce(() => { throw new Error('bad optional token'); });
    const invalidReq = reqMock('Bearer invalid');
    const invalidNext = jest.fn();
    optionalAuthenticate(invalidReq, responseMock(), invalidNext);
    expect(invalidReq.user).toBeUndefined();
    expect(invalidNext).toHaveBeenCalledTimes(1);
  });
});
