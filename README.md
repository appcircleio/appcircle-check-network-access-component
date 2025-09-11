# Appcircle Network Accessibility Check Component

Check network accessibility to common build endpoints used in Appcircle workflows. This component validates access to package managers, build services, APIs and custom-defined URLs within build time.

The code checks selected URLs using curl, logs detailed results for non-2xx responses, and fails only on network or server errors.

- 2xx responses are considered OK.

- 3xx/4xx responses are logged as WARN (network is reachable, but the service may not respond as expected).

- 5xx responses and cURL transport errors (exit codes, timeouts, DNS issues, SSL errors) are treated as FAIL and stop the build.

## Optional Inputs

- `AC_CHECK_NETWORK_GITHUB_APPCIRCLE`: Check accessibility to `https://github.com/appcircleio/`. Default: true.
- `AC_CHECK_NETWORK_RUBYGEMS`: Check accessibility to `https://rubygems.org`. Default: true.
- `AC_CHECK_NETWORK_INDEX_RUBYGEMS`: Check accessibility to `https://index.rubygems.org`. Default: true.
- `AC_CHECK_NETWORK_SERVICES_GRADLE_ORG`: Check accessibility to `https://services.gradle.org`. Default: true.
- `AC_CHECK_NETWORK_DL_GOOGLE_COM_ANDROID_REPOSITORY`: Check accessibility to `https://dl.google.com/android/repository/repository2-1.xml`. Default: true.
- `AC_CHECK_NETWORK_DL_SSL_GOOGLE_COM_ANDROID_REPOSITORY`: Check accessibility to `https://dl-ssl.google.com/android/repository/repository2-1.xml`. Default: true.
- `AC_CHECK_NETWORK_MAVEN_GOOGLE_COM`: Check accessibility to `https://maven.google.com/web/index.html`. Default: true.
- `AC_CHECK_NETWORK_REPO1_MAVEN_ORG_MAVEN2`: Check accessibility to `https://repo1.maven.org/maven2/`. Default: true.
- `AC_CHECK_NETWORK_CDCOAPODS_ORG`: Check accessibility to `https://cdn.cocoapods.org`. Default: true.
- `AC_CHECK_NETWORK_GITHUB_COCOAPODS_SPECS`: Check accessibility to `https://github.com/CocoaPods/Specs`. Default: true.
- `AC_CHECK_NETWORK_FIREBASEAPPDISTRIBUTION_GOOGLEAPIS_COM`: Check accessibility to `https://firebaseappdistribution.googleapis.com/$discovery/rest?version=v1`. Default: true.
- `AC_CHECK_NETWORK_EXTRA_URL_PARAMETERS`: Additional URLs to check, defined as a comma separated list (e.g. `https://url1.com`, `https://url2.com`).
