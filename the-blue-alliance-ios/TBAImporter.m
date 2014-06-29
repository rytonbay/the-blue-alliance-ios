//
//  DatabaseImporter.m
//  the-blue-alliance-ios
//
//  Created by Donald Pinckney on 5/23/14.
//  Copyright (c) 2014 The Blue Alliance. All rights reserved.
//

#import "TBAImporter.h"
#import "Event+Create.h"
#import "Team+Create.h"

#define kIDHeader @"the-blue-alliance:ios:v0.1"

@implementation TBAImporter

+ (id)executeTBAV2Request:(NSString *)request
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.thebluealliance.com/api/v2/%@", request]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest addValue:kIDHeader forHTTPHeaderField:@"X-TBA-App-Id"];
    
    NSURLResponse *response;
    NSError *error;
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
    NSLog(@"Executed TBA API request: %@", request);
    
    if(error || !data) {
        NSLog(@"Handle downloading error...");
        return nil;
    } else {
        NSError *jsonError;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if(jsonError || !obj) {
            NSLog(@"Handle JSON error");
            return nil;
        } else {
            return obj;
        }
    }
}

+ (void)importEventsUsingManagedObjectContext:(NSManagedObjectContext *)context
{
    int currentYear = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"EventsViewController.currentYear"];

    int startYear = 1992;
    int endYear = (int)[NSDate date].year + 1;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *downloadedEvents = [[NSMutableArray alloc] init];
        // Download the currently selected year first
        if (currentYear != 0) {
            NSArray *events = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"events/%@", @(currentYear)]];
            [downloadedEvents addObjectsFromArray:events];
        }
        for(int i = endYear; i >= startYear; i--) {
            if (i == currentYear)
                continue;
            NSArray *events = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"events/%d", i]];
            [downloadedEvents addObjectsFromArray:events];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [Event createEventsFromTBAInfoArray:downloadedEvents usingManagedObjectContext:context];
        });
    });
}


+ (void)importTeamsUsingManagedObjectContext:(NSManagedObjectContext *)context
{
    __block int page = 0;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *downloadedTeams = [[NSMutableArray alloc] init];
        NSArray *teams = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"teams/%d", page]];

        while (teams && [teams count] > 0) {
            [downloadedTeams addObjectsFromArray:teams];
            page++;
            teams = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"teams/%d", page]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [Team createTeamsFromTBAInfoArray:downloadedTeams usingManagedObjectContext:context];
        });
    });
}

+ (void)linkTeamsToEvent:(Event *)event usingManagedObjectContext:(NSManagedObjectContext *)context
{
    NSString *eventKey = event.key;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *teamList = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"event/%@/teams", eventKey]];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *teams = [Team createTeamsFromTBAInfoArray:teamList usingManagedObjectContext:context];
            [event setTeams:[NSSet setWithArray:teams]];
        });
    });
    
}

+ (void)importRankingsForEvent:(Event *)event usingManagedObjectContext:(NSManagedObjectContext *)context callback:(void (^)(NSString *rankingsString))callback;
{
    NSString *eventKey = event.key;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *rankArray = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"event/%@/rankings", eventKey]];
        NSString *rankingsString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:rankArray options:0 error:nil] encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            event.rankings = rankingsString;
            [context save:nil];
            callback(rankingsString);
        });
    });
}


+ (void)importMatchesForEvent:(Event *)event usingManagedObjectContext:(NSManagedObjectContext *)context callback:(void (^)(NSSet *matches))callback {
    NSString *eventKey = event.key;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *matchDicts = [TBAImporter executeTBAV2Request:[NSString stringWithFormat:@"event/%@/matches", eventKey]];
        dispatch_async(dispatch_get_main_queue(), ^{
            // TODO: Parse matchDicts into Core Data
            // event.matches =
            NSSet *matches = nil;
            
            [context save:nil];
            callback(matches);
        });
    });
}

@end
