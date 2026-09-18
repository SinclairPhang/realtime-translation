# DuoTranslate · 同声翻译

中文与法语双向实时语音翻译，包含原生 iOS 应用和移动 Web 原型。

## iOS 应用

使用 Xcode 打开 `ios/DuoTranslate/DuoTranslate.xcodeproj`，在 Signing & Capabilities 中选择自己的开发团队，连接 iPhone 运行。最低支持 iOS 17；较新系统使用原生 Liquid Glass 标签栏。

- 自动双向互译，语音作为翻译内容，不作为操作指令。
- 播放译音时暂停收音，播放结束后自动恢复，可手动暂停。
- 长按按钮 2 秒结束会话，支持进度反馈。
- 多会话文本记录、纪要生成和导出。
- API Key 保存在本机 Keychain；模型、音色、翻译角色和输出设备可选。
- 支持音色试听，试听不录音、不写入会话记录，需要 API 额度。
- 简约蓝色图标、悬浮麦克风和径向渐变光晕。

进入应用设置填写自己的 OpenAI API Key。模型、音色和角色修改从下一次会话生效。麦克风与扬声器请在实体 iPhone 测试，不能通过 iPhone 镜像测试收音。音色试听需先结束翻译会话。

## Web 原型

需要 Node.js 20 或更高版本，无第三方 npm 依赖。

```sh
npm run build
npm run dev
```

访问 `http://127.0.0.1:4173`，在设置中配置 API Key。也可通过服务器的 `OPENAI_API_KEY` 环境变量提供密钥。`DUO_PORT` 可调整本地端口。

`dist/index.html` 是当前 Web 原型源文件；`scripts/build-worker.mjs` 生成本地服务使用的 `dist/server/index.js`。

## 数据与开发状态

本仓库不包含密钥、个人会话记录、签名证书或构建缓存。iOS 会话保存在设备本地；生成翻译和纪要时相关内容会发送至 OpenAI API。仓库上传不代表部署线上服务或上架 App Store。

当前为持续真机验证中的版本。图标为静态 PNG 玻璃质感设计，并非 Icon Composer 动态分层图标。
