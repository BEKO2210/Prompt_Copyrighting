import { createHash } from 'node:crypto';

/**
 * Hash a raw API token with SHA-256 for safe storage / comparison.
 * Tokens are NEVER stored in plaintext.
 */
export function hashToken(raw) {
  return createHash('sha256').update(raw).digest('hex');
}

/**
 * Express middleware: validate Bearer token against allowed hashed tokens.
 *
 * Expects:
 *   req.headers.authorization = "Bearer <raw-token>"
 *   allowedHashes = Set<string> of SHA-256 hashed tokens
 */
export function bearerAuth(allowedHashes) {
  return (req, res, next) => {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid Authorization header.' });
    }

    const raw = header.slice(7);
    const hashed = hashToken(raw);

    if (!allowedHashes.has(hashed)) {
      return res.status(403).json({ error: 'Invalid API token.' });
    }

    // Attach token hash to request for logging (never the raw token)
    req.tokenHash = hashed;
    next();
  };
}

/**
 * Simple request logger middleware.
 * Logs method, path, token hash prefix, and timestamp.
 */
export function requestLogger(req, res, next) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const tokenPrefix = req.tokenHash ? req.tokenHash.slice(0, 8) + '...' : 'none';
    console.log(
      `[${new Date().toISOString()}] ${req.method} ${req.path} → ${res.statusCode} (${duration}ms) token=${tokenPrefix}`
    );
  });

  next();
}
