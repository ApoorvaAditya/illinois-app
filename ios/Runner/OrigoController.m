////  OrigoController.m
//  Runner
//
//  Created by Mihail Varbanov on 2/21/23.
//  Copyright 2020 Board of Trustees of the University of Illinois.
	
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//    http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "OrigoController.h"

#import "NSDictionary+InaTypedValue.h"
#import "NSDate+InaUtils.h"

#import <OrigoSDK/OrigoSDK.h>

@interface OrigoController()<OrigoKeysManagerDelegate>
@property (nonatomic, strong) OrigoKeysManager*    origoKeysManager;

@property (nonatomic, strong) NSMutableSet* startCompletions;
@property (nonatomic, assign) bool isStarted;

@property (nonatomic, strong) void (^registerEndpointCompletion)(NSError* error);
@property (nonatomic, strong) void (^unregisterEndpointCompletion)(NSError* error);

@end

@interface OrigoKeysKey(UIUC)
@property (nonatomic, readonly) NSDictionary* uiucJson;
@end

///////////////////////////////////////////
// OrigoController

@implementation OrigoController

+ (instancetype)sharedInstance {
    static OrigoController *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
	
    return _sharedInstance;
}

- (instancetype)init {
	if (self = [super init]) {
	}
	return self;
}

- (void)initializeWithAppId:(NSString*)appId {
	NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:@"%@-%@ (%@)", appId,
		[bundleInfo inaStringForKey:@"CFBundleShortVersionString"],
		[bundleInfo inaStringForKey:@"CFBundleVersion"]
	];
	
	@try {
		_origoKeysManager = [[OrigoKeysManager alloc] initWithDelegate:self options:@{
			OrigoKeysOptionApplicationId: appId,
			OrigoKeysOptionVersion: version,
			OrigoKeysOptionSuppressApplePay: [NSNumber numberWithBool:TRUE],
		//OrigoKeysOptionBeaconUUID: @"...",
		}];
	}
	@catch (NSException *exception) {
		NSLog(@"Failed to initialize OrigoKeysManager: %@", exception);
	}
}

- (void)start {
	[self startWithCompletion:nil];
}
- (void)startWithCompletion:(void (^)(NSError* error))completion {
	//NSError *error = NULL;
	//if ([_origoKeysManager isEndpointSetup:&error] != TRUE)

	if (_origoKeysManager == nil) {
		if (completion != nil) {
			completion([NSError errorWithDomain:@"edu.illinois.rokwire" code: 1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Origo Controller not initialized.", nil) }]);
		}
	}
	else if (_isStarted) {
		completion(nil);
	}
	else if (_startCompletions != nil) {
		if (completion != nil) {
			[_startCompletions addObject:completion];
		}
	}
	else {
		_startCompletions = [[NSMutableSet alloc] init];
		if (completion != nil) {
			[_startCompletions addObject:completion];
		}
		[_origoKeysManager startup];
	}
}

- (void)didStartupWithError:(NSError*)error {
	_isStarted = (error == nil);

	if (_startCompletions != nil) {
		NSSet *startCompletions = _startCompletions;
		_startCompletions = nil;
		for (void (^completion)(NSError* error) in startCompletions) {
			completion(error);
		}
	}
}

- (NSArray*)mobileKeys {
	NSMutableArray* result = nil;
	if ([_origoKeysManager isEndpointSetup: NULL]) {
		NSArray<OrigoKeysKey*>* oregoKeys = [_origoKeysManager listMobileKeys: NULL];
		if (oregoKeys != nil) {
			result = [[NSMutableArray alloc] init];
			for (OrigoKeysKey* oregoKey in oregoKeys) {
				[result addObject:oregoKey.uiucJson];
			}
		}
	}
	return result;
}

- (bool)isEndpointRegistered {
	return (_origoKeysManager != nil) && _isStarted && [_origoKeysManager isEndpointSetup:NULL];
}

- (void)registerEndpointWithInvitationCode:(NSString*)invitationCode completion:(void (^)(NSError* error))completion {
	NSError *errorResult = nil;
	if ((_origoKeysManager == nil) || !_isStarted) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Origo Controller not initialized.", nil) }];
	}
	else if ([_origoKeysManager isEndpointSetup:NULL]) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:2 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Endpoint already setup", nil) }];
	}
	else if (_registerEndpointCompletion != nil) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:3 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Endpoint currently setup", nil) }];
	}
	else {
		_registerEndpointCompletion = completion;
		[_origoKeysManager setupEndpoint:invitationCode];
	}

	if ((errorResult != nil) && (completion != nil)) {
		completion(errorResult);
	}
}

- (void)didRegisterEndpointWithError:(NSError*)error {
	if (_registerEndpointCompletion != nil) {
		void (^ completion)(NSError* error) = _registerEndpointCompletion;
		_registerEndpointCompletion = nil;
		completion(error);
	}
}

- (void)unregisterEndpointWithCompletion:(void (^)(NSError* error))completion {
	NSError *errorResult = nil;
	if ((_origoKeysManager == nil) || !_isStarted) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Origo Controller not initialized.", nil) }];
	}
	else if (![_origoKeysManager isEndpointSetup:NULL]) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:4 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Endpoint not setup", nil) }];
	}
	else if (_unregisterEndpointCompletion != nil) {
		errorResult = [NSError errorWithDomain:@"edu.illinois.rokwire" code:5 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Endpoint currently unregister", nil) }];
	}
	else {
		_unregisterEndpointCompletion = completion;
		[_origoKeysManager unregisterEndpoint];
	}

	if ((errorResult != nil) && (completion != nil)) {
		completion(errorResult);
	}
}

- (void)didUnregisterEndpointWithError:(NSError*)error {
	if (_unregisterEndpointCompletion != nil) {
		void (^ completion)(NSError* error) = _unregisterEndpointCompletion;
		_unregisterEndpointCompletion = nil;
		completion(error);
	}
}

#pragma mark OrigoKeysManagerDelegate

- (void)origoKeysDidStartup {
	[self didStartupWithError:nil];
}

- (void)origoKeysDidFailToStartup:(NSError *)error {
	[self didStartupWithError:error];
}

- (void)origoKeysDidSetupEndpoint {
	[self didRegisterEndpointWithError:nil];
}

- (void)origoKeysDidFailToSetupEndpoint:(NSError *)error {
	[self didRegisterEndpointWithError:error];
}

- (void)origoKeysDidUpdateEndpoint {}
- (void)origoKeysDidUpdateEndpointWithSummary:(OrigoKeysEndpointUpdateSummary *)endpointUpdateSummary {}
- (void)origoKeysDidFailToUpdateEndpoint:(NSError *)error {}

- (void)origoKeysDidTerminateEndpoint {
	[self didUnregisterEndpointWithError:nil];
}

@end

///////////////////////////////////////////
// OrigoKeysKey+UIUC

@implementation OrigoKeysKey(UIUC)

- (NSDictionary*)uiucJson {
	return @{
		@"type": self.keyType ?: [NSNull null],
		@"card_number": self.cardNumber ?: [NSNull null],
		@"active": [NSNumber numberWithBool:self.active],
		@"key_identifier": self.keyId ?: [NSNull null],
		@"unique_identifier": self.uniqueIdentifier ?: [NSNull null],
		@"external_id": self.externalId ?: [NSNull null],

		@"name": self.name ?: [NSNull null],
		@"suffix": self.suffix ?: [NSNull null],
		@"access_token": self.accessToken ?: [NSNull null],

		@"label": self.label ?: [NSNull null],
		@"issuer": self.issuer ?: [NSNull null],
		
		@"begin_date": [self.beginDate inaStringWithFormat:@"yyyy-MM-dd"] ?: [NSNull null],
		@"expiration_date": [self.endDate inaStringWithFormat:@"yyyy-MM-dd"] ?: [NSNull null],
	};
}

@end
