/**
 * @file api.js
 * 处理 Flutter (Dart) 到 WebView (JS) 的数据传输
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
 * @property {string} LLMBuffer - AI流式响应的缓冲区 (正在生成的内容)
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

  // ----------------------------------------------------------------------
  // Public Methods: Actions (JS 主动请求 Flutter)
  // ----------------------------------------------------------------------

  /**
   * 主动请求获取当前 Chat 数据
   * 说明：Flutter 收到请求后，会通过 window.onChatChange 异步推送数据回来。
   * 所以调用此方法后，应该确保已经 subscribeChat。
   * @returns {Promise<void>}
   */
  fetchChat() {
    console.log('[Bridge] Requesting Chat Data...');
    return this._callFlutter('fetchChat');
  }

  /**
   * 获取所有角色列表
   * 说明：这是一个异步调用，直接返回 Promise 包含角色数组。
   * @returns {Promise<Array<Character>>} 角色列表
   */
  async fetchAllCharacters() {
    console.log('[Bridge] Requesting All Characters...');
    try {
      const result = await this._callFlutter('fetchAllCharacters');
      // Flutter 传回来的通常已经是 JSON 对象 (List)，无需再次 parse，
      // 但根据具体的 encoder 实现，如果传回的是 string，这里可以加一层保险
      return typeof result === 'string' ? JSON.parse(result) : result;
    } catch (error) {
      console.error('[Bridge] Failed to fetch characters:', error);
      return [];
    }
  }
}

// 初始化并挂载到 window，方便调试和调用
const appApi = new BridgeAPI();
window.appApi = appApi;

export default appApi;