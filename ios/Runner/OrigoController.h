////  OrigoController.h
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

#import <Foundation/Foundation.h>


@interface OrigoController : NSObject
+ (instancetype)sharedInstance;

- (void)initializeWithAppId:(NSString*)appId;

- (void)start;
- (void)startWithCompletion:(void (^)(NSError* error))completion;

- (NSArray*)mobileKeys;
- (void)registerEndpointWithInvitationCode:(NSString*)invitationCode completion:(void (^)(NSError* error))completion;
- (void)unregisterEndpointWithCompletion:(void (^)(NSError* error))completion;
- (bool)isEndpointRegistered;
@end

