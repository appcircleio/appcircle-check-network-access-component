# Appcircle Check Network Access Component

Check network access to common build endpoints used in Appcircle workflows. This component validates access to package managers, build services, APIs and custom-defined URLs within build time.

The code checks selected URLs using curl, logs detailed results for non-2xx responses, and fails only on network or server errors.

- `2xx` responses indicate successful requests.

- `3xx`/`4xx` responses are logged as WARN (network is reachable, but the service may not respond as expected).

- `5xx` responses and curl transport errors (exit codes, timeouts, DNS issues, SSL errors) are treated as FAIL and stop the build.

The curl exit code is also used to determine whether the connection was established. If HTTP responses are received, their headers and bodies are logged (truncated) for further details.

## Optional Inputs

- `AC_CHECK_NETWORK_GITHUB_APPCIRCLE`: If enabled, checks if the runner can access to `https://github.com/appcircleio/`. Default: `true`.
- `AC_CHECK_NETWORK_RUBYGEMS`: If enabled, checks if the runner can access to `https://rubygems.org`. Default: `true`.
- `AC_CHECK_NETWORK_INDEX_RUBYGEMS`: If enabled, checks if the runner can access to `https://index.rubygems.org`. Default: `true`.
- `AC_CHECK_NETWORK_SERVICES_GRADLE_ORG`: If enabled, checks if the runner can access to `https://services.gradle.org`. Default: `true`.
- `AC_CHECK_NETWORK_DL_GOOGLE_COM_ANDROID_REPOSITORY`: If enabled, checks if the runner can access to `https://dl.google.com/android/repository/repository2-1.xml`. Default: `true`.
- `AC_CHECK_NETWORK_DL_SSL_GOOGLE_COM_ANDROID_REPOSITORY`: If enabled, checks if the runner can access to `https://dl-ssl.google.com/android/repository/repository2-1.xml`. Default: `true`.
- `AC_CHECK_NETWORK_MAVEN_GOOGLE_COM`: If enabled, checks if the runner can access to `https://maven.google.com/web/index.html`. Default: `true`.
- `AC_CHECK_NETWORK_REPO1_MAVEN_ORG_MAVEN2`: If enabled, checks if the runner can access to `https://repo1.maven.org/maven2/`. Default: `true`.
- `AC_CHECK_NETWORK_CDCOAPODS_ORG`: If enabled, checks if the runner can access to `https://cdn.cocoapods.org`. Default: `true`.
- `AC_CHECK_NETWORK_GITHUB_COCOAPODS_SPECS`: If enabled, checks if the runner can access to `https://github.com/CocoaPods/Specs`. Default: `true`.
- `AC_CHECK_NETWORK_FIREBASEAPPDISTRIBUTION_GOOGLEAPIS_COM`: If enabled, checks if the runner can access to `https://firebaseappdistribution.googleapis.com/$discovery/rest?version=v1`. Default: `true`.
- `AC_CHECK_NETWORK_EXTRA_URL_PARAMETERS`: Additional URLs to check, defined as a comma separated list (e.g. `https://url1.com`, `https://url2.com`).
