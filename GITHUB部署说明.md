# Calenotes 网页版：上传 GitHub 与开启个人账号

这份程序已经适配 GitHub Pages。**先部署网页，再按需开启在线账号。** 不需要把 Windows 的 `.exe` 上传到 Pages。

## 一、选哪个压缩包

| 文件 | 用途 | 是否需要在电脑安装开发环境 |
| --- | --- | --- |
| `Calenotes-GitHub-Pages-0.2.0.zip` | 已构建网页，推荐直接上传 | 不需要 |
| `Calenotes-GitHub-Source-0.2.0.zip` | 完整源码，适合继续开发、自动构建 | 手动部署时不需要；本地开发需要 Node.js 22.12+ |

压缩包必须先解压，再上传**里面的文件和文件夹**，不要把 ZIP 本身当作网页上传，也不要多套一层目录。

## 二、最简单的发布方式（推荐）

1. 登录 GitHub，右上角 `+` → `New repository`。
2. 仓库名填写 `calenotes`，选择 `Public`，点击 `Create repository`。不要把数据库密码或模型密钥写入仓库。
3. 在空仓库中点击 `uploading an existing file`；或进入 `Add file` → `Upload files`。
4. 解压 `Calenotes-GitHub-Pages-0.2.0.zip`，将里面所有文件和文件夹拖进去，提交到 `main` 分支。仓库首页应该直接看到 `index.html`、`assets`、`web-config.js`。
5. 打开仓库 `Settings` → `Pages`。
6. 在 `Build and deployment` 下将 Source 选为 `Deploy from a branch`；Branch 选择 `main`，目录选择 `/(root)`，点击 `Save`。
7. 等待部署成功。Pages 页面会显示真实网址，一般类似 `https://你的GitHub用户名.github.io/calenotes/`。
8. 打开网址即可使用。也可以将这个网址发给别人，电脑和手机都不需要安装软件。

第一次没有配置账号服务时，网页会明确提示“尚未配置在线账号”。点击“先用本机体验模式打开”即可使用日程、意义锚、学习记录、体能内容等基础功能。

本机体验数据仅保存在这个浏览器，不是在线账户，不会自动出现在另一台设备。用户清除网站数据后也会清除本机体验数据。

GitHub Pages 是静态网站托管，不会替网页运行数据库或保存用户密码。相关官方说明：[GitHub Pages 发布源](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)。

## 三、开启每个人自己的邮箱与密码账户

账号代码已经加入，使用 Supabase 的认证服务和数据库。你需要创建**自己管理的** Supabase 项目，填写两个公开配置并执行建表脚本，在线账户才会真正工作。

### 1. 创建后端项目

1. 打开 [Supabase](https://supabase.com/)，注册并登录。
2. 创建新项目；数据库密码自己保存，不要填到网页配置或 GitHub。
3. 项目创建完成后，在 `Connect` 或项目设置的 API 页面取得 Project URL。
4. 在 `Settings` → `API Keys` 找到 **Publishable key**，通常以 `sb_publishable_` 开头。旧项目也可使用 legacy `anon` key。
5. **不要使用** `service_role`、`sb_secret_...`、数据库连接密码或 DeepSeek 密钥。这些会绕过权限或产生费用，不能出现在网页中。

Project URL 与 publishable/anon key 本来就是面向前端的公开配置；用户数据是否隔离由数据库的 RLS 策略和服务器签发的登录令牌决定，而不是靠隐藏这个公开 key。[官方 API key 说明](https://supabase.com/docs/guides/getting-started/api-keys)。

### 2. 创建数据库与用户隔离规则

1. 在 Supabase 项目左侧打开 `SQL Editor` → `New query`。
2. 打开压缩包中的 `supabase/schema.sql`，复制**完整内容**，粘贴后点击 `Run`。
3. 脚本会创建个人数据表、版本冲突保护函数、按 `auth.uid()` 隔离用户的 RLS 策略，以及可选 AI 配额函数。
4. 不要关闭数据表的 RLS，也不要给匿名用户开放整张数据表。

账号 A 只能查询、修改 A 的行，账号 B 只能查询、修改 B 的行。不要把前端“隐藏按钮”当作数据隔离。[官方 RLS 说明](https://supabase.com/docs/guides/database/postgres/row-level-security)。

### 3. 填写网页配置

对于推荐的“已构建网页包”，在 GitHub 打开根目录 `web-config.js`，点击编辑，填写：

```javascript
window.CALENOTES_WEB_CONFIG = {
  supabaseUrl: "https://你的项目ID.supabase.co",
  supabaseAnonKey: "你的 publishable key 或 legacy anon key"
};
```

提交后等待 Pages 更新。**源码包**请改 `public/web-config.js`，不要只改构建产物。

### 4. 配置注册邮件与密码找回

1. Supabase → `Authentication`，启用 Email/Password 登录与注册。
2. 在 URL Configuration 中，将 Site URL 设置为完整 Pages 地址，例如 `https://你的用户名.github.io/calenotes/`。
3. Redirect URLs 同样加入该完整地址。若以后更换域名或仓库名，要同时更新这里。
4. 对外开放注册前，配置用于发送确认邮件和密码找回邮件的 **Custom SMTP**。

Supabase 自带默认邮件服务面向开发测试，默认仅向项目团队地址发送邮件，不能当成对所有公众开放的正式发件服务。因此仅填 URL/key、却没有配好发件服务时，其他人的注册确认或找回密码可能失败。[官方 SMTP 说明](https://supabase.com/docs/guides/auth/auth-smtp)。

### 5. 验证两个独立账户

1. 用邮箱 A 注册；若启用邮件确认，先点击确认邮件，再登录。
2. 新建一项任务，等待页面顶部显示“已同步到个人账户”。
3. 退出，再用邮箱 B 注册、登录，B 不应看到 A 的任务。
4. 用另一台设备登录 A，应该恢复 A 的云端数据。
5. 用“忘记密码”测试重置邮件；打开邮件链接后设置新密码。

我已通过模拟后端验证网页的 A/B 切换、空间隔离、同步失败保留、版本冲突和密码找回流程；**没有代替你创建 Supabase 项目，也没有对你的真实后端做上线验收**。上面五步是配置后必须执行的实际验收。

## 四、数据同步的实际行为

- 本机体验、账户 A、账户 B 使用不同的本机存储空间，不会自动混在一起。
- 登录时先验证身份，再读取这个用户的云端数据；修改先保存在本机，再自动同步。
- 正常退出账户会在同步完成后清理该账户的本机缓存。公共电脑使用后请退出账户。
- 登录会话保存在当前标签页会话中；关闭浏览器后可能需要重新登录，密码本身不保存在日程数据里。
- 另一台设备已有新版本时，不会用旧数据静默覆盖它。页面会提示冲突，可先“导出本机备份”，再“加载云端”。该按钮会替换本机副本，备份不要省略。
- 在线账户的每日意志卡额外使用数据库唯一日期记录，避免两个已登录设备当天重复展示；离线时暂不弹出账号意志卡，恢复网络后再检查。本机体验仍按浏览器本地日期记录判断。
- 个人账户支持导出和导入完整 JSON 备份。“导入备份（替换）”会替换当前账户的本机副本并同步，务必先保存需要保留的版本。
- 当前是整份个人数据的版本同步，不是多人实时协作。大型图片附件会占用浏览器与数据库空间，建议压缩图片；单个账户文档限约 5 MB。
- 本机体验数据和旧桌面版数据不会自动合并进新在线账户，避免把共享设备资料传到错误账户。

## 五、网页 AI（可选，基础功能不依赖它）

GitHub Pages 不能安全保存管理员的模型密钥。所以网页不会要求访客把 DeepSeek 密钥填进公开配置；由 Supabase Edge Function 在服务器端调用。

默认不部署该函数也能使用基础功能。要开启 AI：

1. 确认第三部分的 `schema.sql` 已全部运行。
2. Supabase → Edge Functions，新建名称为 `calenotes-ai` 的函数，将 `supabase/functions/calenotes-ai/index.ts` 的内容粘贴进去。
3. 使用本项目的函数配置：关闭平台的 legacy JWT verification；**函数内部仍会通过 Auth `/user` 接口验证登录令牌，不是匿名 AI 服务**。若使用 CLI，`supabase/config.toml` 已给出该设置。
4. 在 Edge Function Secrets 中设置 `DEEPSEEK_API_KEY`，值为管理员自己的模型密钥。
5. 设置 `ALLOWED_ORIGINS`，填写站点**来源**，例如 `https://你的用户名.github.io`。这里不带 `/calenotes/` 路径。多个来源用英文逗号分隔。
6. 部署函数，再登录网页测试饮食建议、运动方案或 AI 日程。

也可以在已安装并登录 Supabase CLI 的环境中执行：

```powershell
supabase link --project-ref 你的项目ID
supabase functions deploy calenotes-ai --no-verify-jwt
```

密钥通过 Supabase Dashboard 的 Secrets 页面填写，不要提交到仓库。函数默认限制每人每天 20 次请求，使用 UTC 日期；模型服务费用由配置密钥的管理员账户承担，可在 SQL 和函数代码中修改配额及输出长度。

函数使用内置环境变量访问 Supabase，不需要把 service_role key 放入前端。它校验登录用户、允许的网站来源和每日配额。没有部署函数时，网页会提示服务未配置，不会伪造 AI 建议。

## 六、如果选择源码包自动部署

1. 新建空的公开 GitHub 仓库，将源码包**内部内容**上传到仓库根目录。
2. 确保上传了隐藏目录 `.github/workflows/pages.yml`。
3. `Settings` → `Pages` → Source 选择 **GitHub Actions**。不要同时套用第二部分的分支根目录发布方式。
4. 打开 `Actions`，查看 `Deploy Calenotes to GitHub Pages` 工作流；没有自动开始时，点击 `Run workflow`。
5. 构建完成后在 Pages 页面取得网址。源码仓库根目录的开发用 `index.html` 不能直接按分支根目录发布，必须让工作流先构建 `dist`。
6. 修改 `public/web-config.js` 并提交后，Actions 会重新构建部署。

本地开发和打包：

```powershell
npm ci --ignore-scripts
npm run dev
npm run package:github
```

`--ignore-scripts` 用于纯网页构建，跳过 Electron 安装脚本；如果要开发桌面安装版，请按 `DESKTOP.md` 安装完整依赖。

## 七、故障处理

| 现象 | 检查 |
| --- | --- |
| 网址 404 | Pages 是否已部署成功；`index.html` 是否在发布目录根层；仓库名和网址是否对应 |
| 网页空白、资源 404 | 不要多套一层文件夹；静态包使用根目录发布，源码包使用 Actions；保持 assets 文件夹完整 |
| 注册按钮不可点击 | `web-config.js` 是否填写 URL 和 publishable/anon key；不支持把 secret/service_role key 当公开配置 |
| 不能注册、收不到确认邮件 | Email provider、Custom SMTP、Site URL 和 Redirect URLs 是否正确；检查垃圾邮件及 Supabase Auth 日志 |
| 登录后读取数据失败 | 是否执行完整 `schema.sql`；API 项目和 key 是否属于同一个项目；不要通过关闭 RLS 来“修复” |
| 顶部提示尚未同步 | 先保持页面打开，检查网络，点击立即同步；必要时先导出备份 |
| 多设备数据冲突 | 导出本机备份，再加载云端版本；本程序不会静默覆盖另一台设备 |
| AI 不可用 | 是否登录、是否部署函数、Secrets 与 ALLOWED_ORIGINS 是否正确、是否达到每日次数 |
| 提醒没有出现 | 点击顶部“启用提醒”；浏览器需要允许通知且页面保持运行，不提供关闭网页后的系统定时唤醒 |

GitHub Pages 链接在不同地区、校园或公司网络的可访问性可能不同；公开链接不等于所有网络都能稳定直连。Supabase 和邮件服务也有自己的额度及运行限制。需要更高可用性时，可保留同一份前端构建并改用适合目标用户网络的静态托管和后端服务。

## 八、这次交付的验证范围

- TypeScript 与 Vite 构建检查。
- 使用真实浏览器测试 `/calendar/` 项目子路径、体验模式任务、登录页面及手机布局。
- 模拟认证/数据库响应测试无效密码、A/B隔离、云端恢复、退出清理缓存、失败重试、并发冲突和密码找回。
- 真实 Supabase 项目、真实邮件、SQL执行和 Edge Function 部署仍需管理员配置后验收；本包不包含个人密钥或生产账户。
- 网页不提供桌面版“读取另一个网页窗口”的能力，原有桌面专用功能会提示适用范围；OCR/语音等联网能力仍受浏览器与网络支持限制。

**不要将本项目中模拟测试通过理解为真实云端服务已经上线。**
