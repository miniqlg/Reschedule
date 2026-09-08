# Re课表

离线读取 `.xlsx` 和文字型 `.pdf` 的 Flutter 手机课表。应用只有三个主页面：今天、本周、设置；课程和学期信息仅保存在设备本地。

## 本机工具目录

- Flutter：`D:\DevTools\ReClass\Flutter`
- JDK：`D:\DevTools\ReClass\JDK`
- Android SDK：`D:\DevTools\ReClass\AndroidSDK`
- Android 用户配置：`D:\DevTools\ReClass\AndroidUser`
- Gradle 缓存：`D:\DevTools\ReClass\Gradle`
- 下载缓存：`D:\DevTools\ReClass\Downloads`

打开 PowerShell 后，在项目目录运行：

```powershell
. .\toolchain.ps1
flutter pub get
flutter test
flutter run
```

构建 Android 测试包：

```powershell
. .\toolchain.ps1
flutter build apk --debug
```

## 导入边界

- 支持现代 Excel `.xlsx` 网格课表。
- 支持带可提取文字的 PDF，以及 `/UniGB-UCS2-H` 字体映射缺失的教务系统 PDF。
- 不支持 `.xls`、CSV、图片、扫描件或加密 PDF。
- 导入前提供课程校对；确认后在单个数据库事务中替换当前课表。
- 私人课表样例应放在 `test/private_fixtures/`，该目录不会提交。
