# Duo Translate for iOS

原生 SwiftUI 同声翻译应用，复刻本地 Web 原型的主要功能：

- 中文与法语双向自动翻译
- `gpt-realtime-2.1` 实时音频 WebSocket
- 播放译音期间暂停麦克风，播放结束后恢复
- 可调语音边界检测
- 单击暂停/继续，长按 2 秒结束并保存会话
- 多会话记录、详情、纪要生成与文本导出
- API Key 使用 Keychain 永久保存在本机
- iOS 26 的标准标签栏自动采用 Liquid Glass；浮动麦克风卡片也使用玻璃效果

## 运行

1. 使用完整 Xcode 打开 `DuoTranslate.xcodeproj`。
2. 在 Signing & Capabilities 中选择开发团队并修改 Bundle Identifier（如有需要）。
3. 选择 iOS 17 或更高版本的真机运行。实时麦克风功能建议使用真机测试。
4. 首次启动后进入“设置”，填写并保存 OpenAI API Key。

## 安全说明

当前版本按本地验证需求，将标准 API Key 存入仅本机可用的 Keychain，并由应用直接建立 WebSocket。若发布给其他用户，建议改为由受信任服务器使用标准 Key 创建短期客户端凭据，避免向分发包的终端用户暴露项目级密钥。

