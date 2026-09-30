#import <Foundation/Foundation.h>

@interface DeviceSpecificEncryptionParameters : NSObject

@property (nonatomic, strong) NSData * _Nonnull key;
@property (nonatomic, strong) NSData * _Nonnull salt;

@end

@interface BuildConfig : NSObject

- (instancetype _Nonnull)initWithBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId;

@property (nonatomic, strong, readonly) NSString * _Nullable appCenterId;
@property (nonatomic, readonly) int32_t apiId;
@property (nonatomic, strong, readonly) NSString * _Nonnull apiHash;
@property (nonatomic, readonly) bool isInternalBuild;
@property (nonatomic, readonly) bool isAppStoreBuild;
@property (nonatomic, readonly) int64_t appStoreId;
@property (nonatomic, strong, readonly) NSString * _Nonnull appSpecificUrlScheme;
@property (nonatomic, readonly) bool isICloudEnabled;
@property (nonatomic, readonly) bool isSiriEnabled;

+ (DeviceSpecificEncryptionParameters * _Nonnull)deviceSpecificEncryptionParameters:(NSString * _Nonnull)rootPath baseAppBundleId:(NSString * _Nonnull)baseAppBundleId;
- (NSData * _Nullable)bundleDataWithAppToken:(NSData * _Nullable)appToken tokenType:(NSString * _Nullable)tokenType tokenEnvironment:(NSString * _Nullable)tokenEnvironment signatureDict:(NSDictionary * _Nullable)signatureDict;

// Telegram Plus
// Resolves the shared App Group container at runtime instead of assuming that
// "group.<bundle id>" is usable. Order: the stock group, then any app group that
// the running binary's own code signature actually grants (the case after a
// third-party re-sign such as Feather), then the app's own container. The result
// is cached in NSUserDefaults, so the code signature is parsed at most once per
// process. Never returns nil unless no container can be created at all.
+ (NSURL * _Nullable)appGroupURLForBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId;
// The same resolution, returning the group name, or nil when the app fell back to
// its own container (extensions then have no shared storage).
+ (NSString * _Nullable)appGroupNameForBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId;

+ (void)getHardwareEncryptionAvailableWithBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^ _Nonnull)(NSData * _Nullable))completion;
+ (void)encryptApplicationSecret:(NSData * _Nonnull)secret baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^ _Nonnull)(NSData * _Nullable, NSData * _Nullable))completion;
+ (void)decryptApplicationSecret:(NSData * _Nonnull)secret publicKey:(NSData * _Nonnull)publicKey baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^ _Nonnull)(NSData * _Nullable, bool))completion;

@end
