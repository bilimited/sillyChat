/**
 * @file api.js
 * Bridge API — handles Dart (Flutter) ↔ WebView (JS) data transport.
 *
 * Dart → JS (push):
 *   window.onChatChange(chatJson)            — full chat data
 *   window.onStateChange(stateJson)          — AI state (with/without LLMBuffer)
 *   window.onMessageAdded(msgJson, idx)      — incremental: new message
 *   window.onMessageUpdated(msgJson)         — incremental: updated message
 *   window.onMessageRemoved(msgJson)         — incremental: deleted message
 *   window.onTokenAppend(token)              — streaming: single token chunk
 *   window.onThemeChange(themeJson)          — theme mode switch
 *   window.onDisplaySettingsChange(json)     — display settings sync
 *   window.scrollToBottom()                  — force scroll to bottom
 *   window.scrollToMessage(id)               — scroll to specific message
 *
 * JS → Dart (callHandler):
 *   'notifyReady'        — JS is mounted and listening
 *   'fetchChat'          — request full chat data (manual resync)
 *   'fetchAllCharacters' — request character list
 *   'emitMessage'        — user action from WebView
 */

//Params Definitions (JSDoc) ----------------------------------------

/**
 * 消息对象结构
 * @typedef {Object} Message
 * @property {number} id - 消息ID
 * @property {string} content - 消息内容
 * @property {number} sender - 发送者ID (0: User, -1: AI/System)
 * @property {string} time - 发送时间 ISO 格式
 * @property {string} type - 消息类型 (e.g. "common")
 * @property {string} role - 角色 (e.g. "user", "assistant")
 * @property {number} token - Token 数量
 * @property {string} visbility - 可见性 (e.g. "common")
 * @property {?string} bookmark - 书签
 * @property {Array} resPath - 资源路径
 * @property {Array<?string>} alternativeContent - 候补内容
 */

/**
 * 聊天会话完整对象结构
 * @typedef {Object} Chat
 * @property {number} id - 会话ID
 * @property {string} name - 会话名称
 * @property {string} lastMessage - 最后一条消息预览
 * @property {string} time - 最后更新时间
 * @property {?string} description - 描述
 * @property {Array<number>} characterIds - 关联角色ID列表
 * @property {Array<Message>} messages - 消息列表
 * @property {number} chatOptionId - 聊天选项ID
 * @property {?number} userId - 用户ID
 * @property {number} assistantId - 助手ID
 * @property {string} mode - 模式 (e.g. "auto")
 * @property {Array} bookmarks - 书签列表
 * @property {Object} chatVars - 聊天变量
 * @property {Object} activitedLorebookItems - 激活的世界书条目
 * @property {boolean} needAutoTitle - 是否需要自动生成标题
 * @property {Object} meta - 元数据
 */

/**
 * 应用状态对象结构
 * @typedef {Object} AppState
 * @property {string} id - 状态ID
 * @property {string} [LLMBuffer] - AI流式响应的缓冲区 (metadata-only推送时不包含)
 * @property {string} GenerateState - 生成状态描述 (e.g. "正在生成...")
 * @property {boolean} isGenerating - 是否正在生成中
 * @property {number} style - 样式枚举值
 * @property {number} currentAssistant - 当前助手ID
 */

/**
 * 角色关系结构
 * @typedef {Object} RelationInfo
 * @property {number} targetId - 目标角色ID
 * @property {string} type - 关系类型
 * @property {string} brief - 关系简介
 */

/**
 * 角色对象结构
 * @typedef {Object} Character
 * @property {number} id - 角色ID
 * @property {string} nickname - 角色昵称 (对应 roleName)
 * @property {string} [avatar] - 头像路径
 * @property {string} [backgroundImage] - 背景图路径
 * @property {string} [category] - 分类
 * @property {string} [brief] - 简介
 * @property {string} [archive] - 档案
 * @property {string} [firstMessage] - 首条消息
 * @property {Array<string>} [moreFirstMessage] - 更多首条消息
 * @property {Object.<string, RelationInfo>} relations - 关系网 (Key为ID字符串)
 * @property {string} messageStyle - 消息样式 (枚举字符串)
 */

// API Logic --------------------------------------------------------

class BridgeAPI {
  constructor() {
    this.listeners = {
      onChatChange: [],
      onStateChange: [],
      onMessageAdded: [],
      onMessageUpdated: [],
      onMessageRemoved: [],
      onTokenAppend: [],
      onThemeChange: [],
      onDisplaySettingsChange: [],
      scrollToBottom: [],
      scrollToMessage: [],
    };

    // 1. 绑定被动接收的方法 (Flutter -> JS)
    this._bindWindowMethods();
  }

  /**
   * 绑定全局方法，供 Dart 直接调用
   * @private
   */
  _bindWindowMethods() {
    // 接收聊天数据更新
    window.onChatChange = (data) => {
      const parsedData = this._safeParse(data);
      console.log('[Bridge] Received Chat Push:', parsedData?.id);
      this._notify('onChatChange', parsedData);
    };

    // 接收状态更新 (流式)
    window.onStateChange = (data) => {
      const parsedData = this._safeParse(data);
      this._notify('onStateChange', parsedData);
    };

    // ---- Incremental message events (P1) ----
    window.onMessageAdded = (data, index) => {
      const parsedData = this._safeParse(data);
      this._notify('onMessageAdded', { message: parsedData, index });
    };

    window.onMessageUpdated = (data) => {
      const parsedData = this._safeParse(data);
      this._notify('onMessageUpdated', parsedData);
    };

    window.onMessageRemoved = (data) => {
      const parsedData = this._safeParse(data);
      this._notify('onMessageRemoved', parsedData);
    };

    // ---- Token delta streaming (P1) ----
    window.onTokenAppend = (token) => {
      // token is a raw string (Dart sends json.encode(token))
      this._notify('onTokenAppend', token);
    };

    // ---- Theme & display settings ----
    window.onThemeChange = (data) => {
      const parsedData = this._safeParse(data);
      this._notify('onThemeChange', parsedData);
    };

    window.onDisplaySettingsChange = (data) => {
      const parsedData = this._safeParse(data);
      this._notify('onDisplaySettingsChange', parsedData);
    };

    // ---- Scroll control ----
    window.scrollToBottom = () => {
      this._notify('scrollToBottom');
    };

    window.scrollToMessage = (id) => {
      this._notify('scrollToMessage', id);
    };
  }

  /**
   * 内部工具：调用 Flutter 原生 Handler
   * @private
   * @param {string} handlerName
   * @param {...any} args
   * @returns {Promise<any>}
   */
  _callFlutter(handlerName, ...args) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      return window.flutter_inappwebview.callHandler(handlerName, ...args);
    } else {
      console.warn(`[Bridge] Flutter environment not ready. Cannot call: ${handlerName}`);
      return Promise.reject('Flutter environment not detected');
    }
  }

  _safeParse(data) {
    if (typeof data === 'string') {
      try { return JSON.parse(data); } catch (e) { return null; }
    }
    return data;
  }

  _notify(eventName, data) {
    if (this.listeners[eventName]) {
      this.listeners[eventName].forEach((cb) => cb(data));
    }
  }

  // ----------------------------------------------------------------------
  // Public Methods: Subscriptions (JS 监听 Flutter 推送)
  // ----------------------------------------------------------------------

  /**
   * 监听当前聊天会话的变化
   * @param {function(Chat): void} callback
   */
  subscribeChat(callback) {
    this.listeners.onChatChange.push(callback);
  }

  /**
   * 监听应用状态/生成状态的变化
   * @param {function(AppState): void} callback
   */
  subscribeState(callback) {
    this.listeners.onStateChange.push(callback);
  }

  /**
   * 监听单条消息添加
   * @param {function({message: Message, index: number}): void} callback
   */
  subscribeMessageAdded(callback) {
    this.listeners.onMessageAdded.push(callback);
  }

  /**
   * 监听单条消息更新
   * @param {function(Message): void} callback
   */
  subscribeMessageUpdated(callback) {
    this.listeners.onMessageUpdated.push(callback);
  }

  /**
   * 监听单条消息删除
   * @param {function(Message): void} callback
   */
  subscribeMessageRemoved(callback) {
    this.listeners.onMessageRemoved.push(callback);
  }

  /**
   * 监听流式token追加
   * @param {function(string): void} callback
   */
  subscribeTokenAppend(callback) {
    this.listeners.onTokenAppend.push(callback);
  }

  /**
   * 监听主题变化
   * @param {function({mode: string}): void} callback
   */
  subscribeTheme(callback) {
    this.listeners.onThemeChange.push(callback);
  }

  /**
   * 监听显示设置变化
   * @param {function(Object): void} callback
   */
  subscribeDisplaySettings(callback) {
    this.listeners.onDisplaySettingsChange.push(callback);
  }

  /**
   * 监听滚到底部指令
   * @param {function(): void} callback
   */
  subscribeScrollToBottom(callback) {
    this.listeners.scrollToBottom.push(callback);
  }

  /**
   * 监听滚动到指定消息指令
   * @param {function(number): void} callback
   */
  subscribeScrollToMessage(callback) {
    this.listeners.scrollToMessage.push(callback);
  }

  // ----------------------------------------------------------------------
  // Public Methods: Actions (JS 主动请求 Flutter)
  // ----------------------------------------------------------------------

  /**
   * 通知 Dart：JS 已就绪，可以开始推送数据。
   * 调用后 Dart 会主动推送初始聊天数据和状态。
   * @returns {Promise<void>}
   */
  notifyReady() {
    console.log('[Bridge] Notifying Flutter: JS is ready');
    return this._callFlutter('notifyReady');
  }

  /**
   * 主动请求获取当前 Chat 数据（手动重同步）
   * 说明：Flutter 收到请求后，会通过 window.onChatChange 异步推送数据回来。
   * @returns {Promise<void>}
   */
  fetchChat() {
    console.log('[Bridge] Requesting Chat Data...');
    return this._callFlutter('fetchChat');
  }

  /**
   * 获取所有角色列表
   * @returns {Promise<Array<Character>>} 角色列表
   */
  async fetchAllCharacters() {
    console.log('[Bridge] Requesting All Characters...');
    try {
      const result = await this._callFlutter('fetchAllCharacters');
      return typeof result === 'string' ? JSON.parse(result) : result;
    } catch (error) {
      console.error('[Bridge] Failed to fetch characters:', error);
      return [];
    }
  }

  // ----------------------------------------------------------------------
  // Message action helpers (convenience wrappers around emitMessage)
  // ----------------------------------------------------------------------

  /**
   * 发送消息
   * @param {string} text
   * @param {string[]} [selectedPath]
   */
  sendMessage(text, selectedPath = []) {
    this._callFlutter('emitMessage', {
      action: 'sendMessage',
      data: { text, selectedPath }
    });
  }

  /**
   * 重新生成
   * @param {number} [index]
   */
  retry(index) {
    this._callFlutter('emitMessage', {
      action: 'retry',
      data: { index }
    });
  }

  /**
   * 中断生成
   */
  interrupt() {
    this._callFlutter('emitMessage', {
      action: 'interrupt'
    });
  }

  /**
   * 编辑消息
   * @param {string} time - ISO时间戳
   * @param {string} newContent - 新内容
   */
  editMessage(time, newContent) {
    this._callFlutter('emitMessage', {
      action: 'editMessage',
      data: { time, newContent }
    });
  }

  /**
   * 删除消息
   * @param {string} time - ISO时间戳
   */
  deleteMessage(time) {
    this._callFlutter('emitMessage', {
      action: 'deleteMessage',
      data: { time }
    });
  }

  /**
   * 复制消息文本到剪贴板
   * @param {string} text
   */
  copyMessage(text) {
    this._callFlutter('emitMessage', {
      action: 'copyMessage',
      data: { text }
    });
  }

  /**
   * 切换备选回复版本
   * @param {string} time - ISO时间戳
   * @param {string} direction - "left" | "right"
   */
  switchAlternative(time, direction) {
    this._callFlutter('emitMessage', {
      action: 'switchAlternative',
      data: { time, direction }
    });
  }

  /**
   * 从剪贴板粘贴消息
   * @param {string} time - 参考消息的ISO时间戳
   * @param {string} position - "above" | "below"
   */
  pasteMessages(time, position) {
    this._callFlutter('emitMessage', {
      action: 'pasteMessages',
      data: { time, position }
    });
  }

  /**
   * 给消息添加图片附件
   * @param {string} time - ISO时间戳
   */
  addImageToMessage(time) {
    this._callFlutter('emitMessage', {
      action: 'addImageToMessage',
      data: { time }
    });
  }

  /**
   * 从消息位置创建分支聊天
   * @param {string} time - ISO时间戳
   */
  createBranch(time) {
    this._callFlutter('emitMessage', {
      action: 'createBranch',
      data: { time }
    });
  }

  /**
   * 删除所有备选条目
   * @param {string} time - ISO时间戳
   */
  deleteAlternatives(time) {
    this._callFlutter('emitMessage', {
      action: 'deleteAlternatives',
      data: { time }
    });
  }

  /**
   * 打开消息优化页面
   * @param {string} time - ISO时间戳
   */
  optimizeMessage(time) {
    this._callFlutter('emitMessage', {
      action: 'optimizeMessage',
      data: { time }
    });
  }

  /**
   * 通知 Dart 滚动位置变化
   * @param {boolean} isNearBottom
   */
  notifyScrollState(isNearBottom) {
    this._callFlutter('emitMessage', {
      action: 'scrollStateChanged',
      data: { isNearBottom }
    });
  }

  /**
   * 更多操作（走 onMessageEmit 回调到 Flutter 弹出 BottomSheet）
   * @param {string} time - ISO时间戳
   */
  messageMore(time) {
    this._callFlutter('emitMessage', {
      action: 'messageMore',
      data: { time }
    });
  }
}

// 初始化并挂载到 window，方便调试和调用
const appApi = new BridgeAPI();
window.appApi = appApi;

export default appApi;
