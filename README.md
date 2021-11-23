# Illinois App
The official mobile app of the University of Illinois. Powered by the [Rokwire Platform](https://rokwire.org/).

## Requirements

### [Flutter](https://flutter.dev/docs/get-started/install) v2.2.2

### [Android Studio](https://developer.android.com/studio) 3.6+

### [xCode](https://apps.apple.com/us/app/xcode/id497799835) 12.5

### [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) 1.9.3+


## Build


### Clone this repo

### Supply the following private configuration files:

#### • /.travis.yml
[No description available]


#### • /secrets.tar.enc
[No description available]

#### • /assets/config.keys.json (for versions after 3.0 inclusive)
JSON data with the following format:
{
	"key":"",
	"iv":""
}

"key" and "iv" fields contain base64 strings of randomly generated 16-bytes AES128 key and IV. These keys are used for decryption of "/assets/configs.json.enc" from application assets as well as for the decryption of "secretKeys" string in application config.

#### • /assets/configs.json.enc
1. JSON data with the following format:
```
{
  "production": {
    "config_url": "https://api.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  },
  "dev": {
    "config_url": "https://api-dev.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  },
  "test": {
    "config_url": "https://api-test.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  }
}
```
2. For versions prior to 3.0:
2.1. Generate random 16-bytes AES128 key.
2.2. AES encrypt the JSON string, CBC mode, PKCS7 padding, using the AES.
2.3. Create a data blob contains the AES key at the beginning followed by the encrypted data.
2.4. Get a base64 encoded string of the data blob and save it as "/assets/configs.json.enc".

Alternatively, you can use AESCrypt.encode from /lib/utils/Crypt.dart to generate content of /assets/configs.json.enc.

3. For versions after 3.0 inclusive:
3.1. AES encrypt the JSON string, CBC mode, PKCS7 padding, using the key and IV from "/assets/config.keys.json".
2.4. Get a base64 encoded string of the encryption result and save it as "/assets/configs.json.enc".

#### • /ios/Runner/GoogleService-Info-Debug.plist
#### • /ios/Runner/GoogleService-Info-Release.plist

The Firebase configuration file for iOS generated from Google Firebase console.

#### • /android/keys.properties
Contains a GoogleMaps and Android Backup API keys.
```
googleMapsApiKey=XXXXXXXXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXX
androidBackupApiKey=XXXXXXXXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXX
```

#### • /android/app/src/debug/google-services.json
#### • /android/app/src/release/google-services.json
#### • /android/app/src/profile/google-services.json
The Firebase configuration file for Android generated from Google Firebase console.

### Build the project

```
$ flutter build apk
$ flutter build ios
```
NB: You may need to update singing & capabilities content for Runner project by opening /ios/Runner.xcworkspace from xCode

