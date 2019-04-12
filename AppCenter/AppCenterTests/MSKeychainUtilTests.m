// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSKeychainUtil.h"
#import "MSKeychainUtilPrivate.h"
#import "MSTestFrameworks.h"

@interface MSKeychainUtilTests : XCTestCase
@property(nonatomic) id keychainUtilMock;
@property(nonatomic, copy) NSString *acServiceName;

@end

@implementation MSKeychainUtilTests

- (void)setUp {
  [super setUp];
  self.keychainUtilMock = OCMClassMock([MSKeychainUtil class]);
  self.acServiceName = [NSString stringWithFormat:@"(null).%@", kMSServiceSuffix];
}

- (void)tearDown {
  [super tearDown];
  [self.keychainUtilMock stopMocking];
}

#if !TARGET_OS_TV
- (void)testKeychain {

  // If
  NSString *key = @"Test Key";
  NSString *value = @"Test Value";
  NSDictionary *expectedAddItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecValueData : (NSData * _Nonnull)[value dataUsingEncoding:NSUTF8StringEncoding]
  };
  NSDictionary *expectedDeleteItemQuery =
      @{(__bridge id)kSecAttrService : self.acServiceName, (__bridge id)kSecClass : @"genp", (__bridge id)kSecAttrAccount : key};
  NSDictionary *expectedMatchItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
    (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne
  };

  // Expect these stubbed calls.
  OCMStub([self.keychainUtilMock addSecItem:[expectedAddItemQuery mutableCopy]]).andReturn(noErr);
  OCMStub([self.keychainUtilMock deleteSecItem:[expectedDeleteItemQuery mutableCopy]]).andReturn(noErr);
  OCMStub([self.keychainUtilMock secItemCopyMatchingQuery:[expectedMatchItemQuery mutableCopy] result:[OCMArg anyPointer]])
      .andReturn(noErr);

  // Reject any other calls.
  OCMReject([self.keychainUtilMock addSecItem:[OCMArg any]]);
  OCMReject([self.keychainUtilMock deleteSecItem:[OCMArg any]]);
  OCMReject([self.keychainUtilMock secItemCopyMatchingQuery:[OCMArg any] result:[OCMArg anyPointer]]);

  // When
  [MSKeychainUtil storeString:value forKey:key];
  [MSKeychainUtil stringForKey:key];
  [MSKeychainUtil deleteStringForKey:key];

  // Then
  OCMVerifyAll(self.keychainUtilMock);
}

- (void)testArraySerializationDeserialization {

  // If
  NSMutableArray *expectedArray = [[NSMutableArray alloc] init];
  NSString *expectedAuthToken1 = @"authToken1";
  NSString *expectedAuthToken2 = @"authToken2";
  [expectedArray addObject:expectedAuthToken1];
  [expectedArray addObject:expectedAuthToken2];
  NSString *key = @"keyToStoreAuthTokenArray";

  NSDictionary *expectedAddItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecValueData : (NSData * _Nonnull)[NSKeyedArchiver archivedDataWithRootObject:expectedArray]
  };
  NSDictionary *expectedMatchItemQuery = @{
    (__bridge id)kSecAttrService : self.acServiceName,
    (__bridge id)kSecClass : @"genp",
    (__bridge id)kSecAttrAccount : key,
    (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
    (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne
  };

  // Expect these stubbed calls.
  OCMStub([self.keychainUtilMock addSecItem:[expectedAddItemQuery mutableCopy]]).andReturn(noErr);
  OCMStub([self.keychainUtilMock secItemCopyMatchingQuery:[expectedMatchItemQuery mutableCopy] result:[OCMArg anyPointer]])
      .andReturn(noErr);

  // When
  [MSKeychainUtil storeArray:expectedArray forKey:key];
  [MSKeychainUtil arrayForKey:key];

  // Then
  OCMVerify([self.keychainUtilMock addSecItem:[expectedAddItemQuery mutableCopy]]);
  OCMVerify([self.keychainUtilMock secItemCopyMatchingQuery:[expectedMatchItemQuery mutableCopy] result:[OCMArg anyPointer]]);
}

- (void)testStoreStringHandlesDuplicateItemError {

  // If
  NSString *key = @"testKey";
  NSString *value = @"testValue";
  __block int addSecItemCallsCount = 0;
  OCMStub([self.keychainUtilMock addSecItem:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    ++addSecItemCallsCount;
    int returnValue = addSecItemCallsCount > 1 ? noErr : errSecDuplicateItem;
    [invocation setReturnValue:&returnValue];
  });

  // When
  BOOL actualResult = [MSKeychainUtil storeString:value forKey:key];

  // Then
  XCTAssertEqual(addSecItemCallsCount, 2);
  XCTAssertEqual(actualResult, YES);
  OCMVerify([self.keychainUtilMock deleteSecItem:OCMOCK_ANY]);
}

#endif

@end
