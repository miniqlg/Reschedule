$env:FLUTTER_HOME = 'D:\DevTools\ReClass\Flutter\flutter'
$env:JAVA_HOME = 'D:\DevTools\ReClass\JDK\jdk-21.0.12.1+1'
$env:ANDROID_HOME = 'D:\DevTools\ReClass\AndroidSDK'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = 'D:\DevTools\ReClass\AndroidUser'
$env:PUB_CACHE = 'D:\DevTools\ReClass\Flutter\PubCache'
$env:GRADLE_USER_HOME = 'D:\DevTools\ReClass\Gradle'
$env:TEMP = 'D:\DevTools\ReClass\Temp'
$env:TMP = $env:TEMP
$env:Path = "$env:FLUTTER_HOME\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

Write-Host 'Re课表工具链已加载。可运行 flutter doctor 或 flutter run。'
