#import "TouchID.h"
#import <LocalAuthentication/LocalAuthentication.h>

@implementation TouchID

// These two combined need to be unique, so one can be fixed
NSString *keychainItemIdentifier = @"TouchIDKey";
NSString *keychainItemServiceName;

- (void) isAvailable:(CDVInvokedUrlCommand*)command; {

  if (TARGET_IPHONE_SIMULATOR) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The simulator is not supported"] callbackId:command.callbackId];
    return;
  }

  if (NSClassFromString(@"LAContext") == NULL) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
    return;
  }
  
  [self.commandDelegate runInBackground:^{

    NSError *error = nil;
    LAContext *laContext = [[LAContext alloc] init];
  
    if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                                  callbackId:command.callbackId];
    } else {
      NSArray *errorKeys = @[@"code", @"localizedDescription"];
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[error dictionaryWithValuesForKeys:errorKeys]]
                                  callbackId:command.callbackId];
    }
  }];
}

// this 'default' method uses keychain instead of localauth so the passcode fallback can be used
- (void) verifyFingerprint:(CDVInvokedUrlCommand*)command {

  NSString *message = [command.arguments objectAtIndex:0];
  NSString *callbackId = command.callbackId;

  [self.commandDelegate runInBackground:^{
    
    if (keychainItemServiceName == nil) {
      NSString *bundleID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
      keychainItemServiceName = [bundleID stringByAppendingString:@".TouchIDPlugin"];
    }
    
    if (![self createKeyChainEntry]) {
      NSLog(@"Keychain trouble. Falling back to verifyFingerprintWithCustomPasswordFallback.");
      [self verifyFingerprintWithCustomPasswordFallback:command];
      return;
    }
    
    // Create the keychain query attributes using the values from the first part of the code.
    NSMutableDictionary * query = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                   (__bridge id)(kSecClassGenericPassword), kSecClass,
                                   keychainItemIdentifier, kSecAttrAccount,
                                   keychainItemServiceName, kSecAttrService,
                                   message, kSecUseOperationPrompt,
                                   nil];
    
    // Start the query and the fingerprint scan and/or device passcode validation
    OSStatus userPresenceStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    
    // Ignore the found content of the key chain entry (the dummy password) and only evaluate the return code.
    if (noErr == userPresenceStatus)
    {
      NSLog(@"Fingerprint or device passcode validated.");
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                                  callbackId:command.callbackId];
    }
    else
    {
      NSLog(@"Fingerprint or device passcode could not be validated. Status %d.", (int) userPresenceStatus);
      
      NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:userPresenceStatus userInfo:nil];
      NSArray *errorKeys = @[@"code", @"localizedDescription"];
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                           messageAsDictionary:[error dictionaryWithValuesForKeys:errorKeys]]
                                  callbackId:callbackId];
      return;
    }
  }];
}

// This implementation uses LocalAuthentication and has no built-in passcode fallback
- (void) verifyFingerprintWithCustomPasswordFallback:(CDVInvokedUrlCommand*)command {
  
  NSString *message = [command.arguments objectAtIndex:0];
  NSString *callbackId = command.callbackId;
  
  if (NSClassFromString(@"LAContext") == NULL) {
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR]
                                callbackId:callbackId];
    return;
  }
  
  [self.commandDelegate runInBackground:^{
    NSError *error = nil;
    LAContext *laContext = [[LAContext alloc] init];
  
    if (![laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]]
                                  callbackId:callbackId];
      return;
    }
  
    [laContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:message reply:^(BOOL authOK, NSError *error) {
      if (authOK) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
                                  callbackId:command.callbackId];
      } else {
        // invoked when the scan failed 3 times in a row, the cancel button was pressed, or the 'enter password' button was pressed
        NSArray *errorKeys = @[@"code", @"localizedDescription"];
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                           messageAsDictionary:[error dictionaryWithValuesForKeys:errorKeys]]
                                    callbackId:callbackId];
      }
    }];
  }];
}

// Note that this needs to run only once but it can deal with multiple runs
- (BOOL) createKeyChainEntry {
  NSMutableDictionary	* attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                      (__bridge id)(kSecClassGenericPassword), kSecClass,
                                      keychainItemIdentifier, kSecAttrAccount,
                                      keychainItemServiceName, kSecAttrService,
                                      nil];

  CFErrorRef accessControlError = NULL;
  SecAccessControlRef accessControlRef = SecAccessControlCreateWithFlags(
                                                                         kCFAllocatorDefault,
                                                                         kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                         kSecAccessControlUserPresence,
                                                                         &accessControlError);
  if (accessControlRef == NULL || accessControlError != NULL)
  {
    NSLog(@"Can't store identifier '%@' in the KeyChain: %@.", keychainItemIdentifier, accessControlError);
    return NO;
  }
  
  attributes[(__bridge id)kSecAttrAccessControl] = (__bridge id)accessControlRef;
  attributes[(__bridge id)kSecUseNoAuthenticationUI] = @YES;
  // The content of the password is not important.
  attributes[(__bridge id)kSecValueData] = [@"dummy content" dataUsingEncoding:NSUTF8StringEncoding];
  
  SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
  return YES;
}

@end