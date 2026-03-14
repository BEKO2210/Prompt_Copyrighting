/**
 * Zero-width Unicode watermarking.
 *
 * Encodes a payload (prompt_id + timestamp) into an invisible sequence of
 * zero-width characters and weaves it into the AI response text.
 *
 * Characters used:
 *   \u200B  ZERO WIDTH SPACE        → bit 0
 *   \u200C  ZERO WIDTH NON-JOINER   → bit 1
 *   \u200D  ZERO WIDTH JOINER       → separator / framing
 */

const BIT_0 = '\u200B';
const BIT_1 = '\u200C';
const SEP = '\u200D';

/**
 * Encode a string into zero-width characters (binary representation).
 */
function textToZeroWidth(text) {
  const bytes = Buffer.from(text, 'utf8');
  let result = SEP; // start marker
  for (const byte of bytes) {
    for (let i = 7; i >= 0; i--) {
      result += (byte >> i) & 1 ? BIT_1 : BIT_0;
    }
  }
  result += SEP; // end marker
  return result;
}

/**
 * Decode zero-width characters back to the original string.
 */
function zeroWidthToText(encoded) {
  // Strip separators and keep only bit chars
  const bits = encoded.replace(new RegExp(SEP, 'g'), '');
  const bytes = [];
  for (let i = 0; i + 7 < bits.length; i += 8) {
    let byte = 0;
    for (let j = 0; j < 8; j++) {
      if (bits[i + j] === BIT_1) {
        byte |= 1 << (7 - j);
      }
    }
    bytes.push(byte);
  }
  return Buffer.from(bytes).toString('utf8');
}

/**
 * Build watermark payload from prompt ID and optional metadata.
 */
function buildPayload(promptId, extra = {}) {
  const data = {
    pid: promptId,
    ts: Date.now(),
    ...extra,
  };
  return JSON.stringify(data);
}

/**
 * Inject a zero-width watermark into visible text.
 * The watermark is inserted after the first sentence-ending punctuation
 * or after the first 80 characters, whichever comes first.
 */
export function embed(text, promptId, extra = {}) {
  const payload = buildPayload(promptId, extra);
  const watermark = textToZeroWidth(payload);

  // Find a natural insertion point
  const sentenceEnd = text.search(/[.!?]\s/);
  const insertAt = sentenceEnd !== -1 && sentenceEnd < 200 ? sentenceEnd + 1 : Math.min(80, text.length);

  return text.slice(0, insertAt) + watermark + text.slice(insertAt);
}

/**
 * Extract watermark payload from watermarked text.
 * Returns the parsed payload object or null if no watermark found.
 */
export function extract(text) {
  // Find the zero-width sequence between two SEP markers
  const regex = new RegExp(`${SEP}([${BIT_0}${BIT_1}]+)${SEP}`);
  const match = text.match(regex);
  if (!match) return null;

  try {
    const decoded = zeroWidthToText(match[0]);
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}

/**
 * Strip all zero-width watermark characters from text.
 * Useful for clean display while preserving the original content.
 */
export function strip(text) {
  return text.replace(/[\u200B\u200C\u200D]/g, '');
}
