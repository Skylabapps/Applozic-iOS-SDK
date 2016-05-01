//
//  ALRegisterUserClientService.m
//  ChatApp
//
//  Created by devashish on 18/09/2015.
//  Copyright (c) 2015 AppLogic. All rights reserved.
//

#define INVALID_APPLICATIONID = @"INVALID_APPLICATIONID"
#define VERSION_CODE @"106"

#import "ALRegisterUserClientService.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALUtilityClass.h"
#import "ALRegistrationResponse.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageDBService.h"
#import "ALApplozicSettings.h"
#import "ALMQTTConversationService.h"
#import "ALMessageService.h"

@implementation ALRegisterUserClientService

-(void) initWithCompletion:(ALUser *)user withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion
{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/register/client",KBASE_URL];
    [ALUserDefaultsHandler setApplicationKey: user.applicationId];
    [user setPrefContactAPI:2];
    [user setEmailVerified:true];
    [user setDeviceType:4];
    [user setAppVersionCode: VERSION_CODE];
    [user setRegistrationId: [ALUserDefaultsHandler getApnDeviceToken]];
    if([ALUserDefaultsHandler getAppModuleName] != NULL){
        [user setAppModuleName:[ALUserDefaultsHandler getAppModuleName]];
    }

    //NSString * theParamString = [ALUtilityClass generateJsonStringFromDictionary:userInfo];
    NSError *error;
    NSData *postdata = [NSJSONSerialization dataWithJSONObject:user.dictionary options:0 error:&error];
    NSString *theParamString = [[NSString alloc]initWithData:postdata encoding:NSUTF8StringEncoding];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createPOSTRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"CREATE ACCOUNT" WithCompletionHandler:^(id theJson, NSError *theError) {
        NSLog(@"server response received %@", theJson);
        
        NSString *statusStr = (NSString *)theJson;
        
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        ALRegistrationResponse *response = [[ALRegistrationResponse alloc] initWithJSONString:statusStr];
        
        //Todo: figure out how to set country code
        //mobiComUserPreference.setCountryCode(user.getCountryCode());
        //mobiComUserPreference.setContactNumber(user.getContactNumber());
        @try{
            [ALUserDefaultsHandler setUserId:user.userId];
            [ALUserDefaultsHandler setEmailVerified: user.emailVerified];
            [ALUserDefaultsHandler setDisplayName: user.displayName];
            [ALUserDefaultsHandler setEmailId:user.emailId];
            [ALUserDefaultsHandler setDeviceKeyString:response.deviceKey];
            [ALUserDefaultsHandler setUserKeyString:response.userKey];
            //[ALUserDefaultsHandler setLastSyncTime:(NSNumber *)response.lastSyncTime];
        }
        
        @catch (NSException *exception) {
            NSLog(@"EXCEPTION: %@",exception);
        }
        
        @finally {
            NSLog(@"..");
        }
        [ALUserDefaultsHandler setLastSyncTime:(NSNumber *)response.currentTimeStamp];
        [ALUserDefaultsHandler setLastSyncChannelTime:(NSNumber *)response.currentTimeStamp];
        [self connect];
        ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
        if(dbService.isMessageTableEmpty){
            [ALMessageService processLatestMessagesGroupByContact];
        }
        completion(response,nil);
    }];
    
}


-(void) updateApnDeviceTokenWithCompletion:(NSString *)apnDeviceToken withCompletion:(void(^)(ALRegistrationResponse * response, NSError *error)) completion
{
    [ALUserDefaultsHandler setApnDeviceToken:apnDeviceToken];
    if ([ALUserDefaultsHandler isLoggedIn])
    {
        //call server again
        ALUser *user = [[ALUser alloc] init];
        [user setApplicationId: [ALUserDefaultsHandler getApplicationKey]];
        [user setUserId:[ALUserDefaultsHandler getUserId]];
        [self initWithCompletion:user withCompletion: completion];
    }
}

-(void) connect {
    
    //[[ALMQTTService sharedInstance] connectToApplozic];
}

-(void) disconnect {
    
   // ALMQTTConversationService *ob  = [[ALMQTTConversationService alloc] init];
    //[ob sendTypingStatus:[ALUserDefaultsHandler getApplicationKey] userID:[ALUserDefaultsHandler getUserId] typing:NO];
    
  //  [[ALMQTTConversationService sharedInstance] unsubscribeToConversation];
}

-(void) logout
{
    NSString *userKey = [ALUserDefaultsHandler getUserKeyString];
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    [ALUserDefaultsHandler clearAll];
    [ALApplozicSettings clearAllSettings];
    ALMessageDBService* messageDBService = [[ALMessageDBService alloc]init];
    [messageDBService deleteAllObjectsInCoreData];
    
    [[ALMQTTConversationService sharedInstance] unsubscribeToConversation: userKey];
}

+(BOOL)isAppUpdated{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *previousVersion = [defaults objectForKey:@"appVersion"];
    
    if (!previousVersion) {
        NSLog(@"First start after installing the app");
        [defaults setObject:currentAppVersion forKey:@"appVersion"];
        [defaults synchronize];
        return NO;
    }
    else if ([previousVersion isEqualToString:currentAppVersion]) {
        return NO;
    }
    else {
        NSLog(@"App was updated since last run");
        
        [ALRegisterUserClientService sendServerRequestForAppUpdate];
        [defaults setObject:currentAppVersion forKey:@"appVersion"];
        [defaults synchronize];
        return YES;
    }
    
}

+(void)sendServerRequestForAppUpdate{
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/register/version/update",KBASE_URL];
    NSString * paramString = [NSString stringWithFormat:@"?appVersionCode=%@&deviceKey%@",VERSION_CODE,DEVICE_KEY_STRING];
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:paramString];
    [ALResponseHandler processRequest:theRequest andTag:@"APP_UPDATED" WithCompletionHandler:^(id theJson, NSError *theError) {
        if (theError) {
            NSLog(@"error:%@",theError);
        }
        NSLog(@"Response: APP UPDATED:%@",theJson);
    }];

    
}
@end
