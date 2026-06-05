/**
 * Parse message content into segments: text, think, toolCallResult.
 * Ported from Flutter's _parseContentSegments() in message_bubble.dart.
 */

export const SegmentType = {
  TEXT: 'text',
  THINK: 'think',
  TOOL_CALL_RESULT: 'toolCallResult',
};

const TAG_REGEX = /<think>(.*?)<\/think>|<ToolCallResult\s+id="([^"]*)"\s+name="([^"]*)"\s+args='([^']*)'>(.*?)<\/ToolCallResult>/gs;

const UNCLOSED_THINK_REGEX = /<think>(.*)/s;

/**
 * @typedef {Object} ContentSegment
 * @property {string} type
 * @property {string} content
 * @property {Object<string,string>} [attributes]
 * @property {boolean} [isThinking]
 */

/**
 * Parse a content string into an array of ContentSegment.
 * Handles interleaved text, <think> blocks, <ToolCallResult> blocks,
 * and unclosed <think> tags (streaming output).
 */
export function parseContentSegments(content) {
  const segments = [];
  let lastEnd = 0;

  for (const match of content.matchAll(TAG_REGEX)) {
    if (match.index > lastEnd) {
      const text = content.substring(lastEnd, match.index);
      if (text) {
        segments.push({ type: SegmentType.TEXT, content: text });
      }
    }

    if (match[1] !== undefined) {
      segments.push({ type: SegmentType.THINK, content: match[1] || '' });
    } else {
      segments.push({
        type: SegmentType.TOOL_CALL_RESULT,
        content: match[5] || '',
        attributes: {
          id: match[2] || '',
          name: match[3] || '',
          args: match[4] || '',
        },
      });
    }

    lastEnd = match.index + match[0].length;
  }

  if (lastEnd < content.length) {
    const remaining = content.substring(lastEnd);
    const unclosed = UNCLOSED_THINK_REGEX.exec(remaining);
    if (unclosed) {
      if (unclosed.index > 0) {
        segments.push({ type: SegmentType.TEXT, content: remaining.substring(0, unclosed.index) });
      }
      segments.push({ type: SegmentType.THINK, content: unclosed[1] || '', isThinking: true });
    } else {
      if (remaining) {
        segments.push({ type: SegmentType.TEXT, content: remaining });
      }
    }
  }

  return segments;
}
