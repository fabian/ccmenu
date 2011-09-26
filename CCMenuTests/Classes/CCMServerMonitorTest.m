
#import "CCMServerMonitorTest.h"
#import "CCMUserDefaultsManager.h"
#import "CCMServer.h"
#import "CCMProject.h"
#import <OCMock/OCMock.h>
#import <EDCommon/EDCommon.h>


@implementation CCMServerMonitorTest

- (void)setUp
{
	monitor = [[[CCMServerMonitor alloc] init] autorelease];
	defaultsManagerMock = [OCMockObject mockForClass:[CCMUserDefaultsManager class]];
	[monitor setDefaultsManager:defaultsManagerMock];
    notificationFactoryMock = [OCMockObject mockForClass:[CCMBuildNotificationFactory class]];
    [monitor setNotificationFactory:notificationFactoryMock];
	notificationCenterMock = [OCMockObject mockForClass:[NSNotificationCenter class]];
	[monitor setNotificationCenter:notificationCenterMock];
}


- (void)testPostsStatusChangeNotificationWhenNoServersDefined
{
	[[[defaultsManagerMock stub] andReturnValue:[NSNumber numberWithInt:1000]] pollInterval];
	[[[defaultsManagerMock expect] andReturn:[NSArray array]] projectList]; 
	[[notificationCenterMock expect] postNotificationName:CCMProjectStatusUpdateNotification object:monitor];
    
	[monitor start];

    [defaultsManagerMock verify];
    [notificationCenterMock verify];
}


- (void)testUpdatesProjectsAndPostsBuildCompleteNotificationWhenStatusChanged
{    
    NSDictionary *oldProjectInfo = [@"{ name = Foo; lastBuildStatus = Failure; }" propertyList];
    NSDictionary *newProjectInfo = [@"{ name = Foo; lastBuildStatus = Success; }" propertyList];

    CCMConnection *dummyConnection = [[[CCMConnection alloc] initWithServerURL:nil] autorelease];
    [monitor setValue:[NSArray arrayWithObject:dummyConnection] forKey:@"connections"];   

    
    CCMServer *server = [[[CCMServer alloc] initWithURL:nil andProjectNames:[NSArray arrayWithObjects:@"Foo", @"Bar", nil]] autorelease];
    [[server projectNamed:@"Foo"] updateWithInfo:oldProjectInfo];
    NSArray *serverConnectionPairs = [NSArray arrayWithObject:[EDObjectPair pairWithObjects:server :dummyConnection]];
    [monitor setValue:serverConnectionPairs forKey:@"serverConnectionPairs"];   
    NSNotification *dummyNotification = [NSNotification notificationWithName:@"test" object:nil];
    [[[notificationFactoryMock expect] andReturn:dummyNotification] buildNotificationForOldProjectInfo:oldProjectInfo andNewProjectInfo:newProjectInfo];
    
    [monitor connection:dummyConnection didReceiveServerStatus:[NSArray arrayWithObject:newProjectInfo]];
    
    STAssertEqualObjects(CCMSuccessStatus, [[[server projectNamed:@"Foo"] status] lastBuildStatus], @"Should have updated status");
    STAssertEqualObjects(@"No project information provided by server.", [[server projectNamed:@"Bar"] statusError], @"Should have set error string");
	STAssertEquals(2u, [postedNotifications count], @"Should have posted two notifications");
//    TODO: need to fix re-creating of notification to insert object
//    STAssertTrue([postedNotifications indexOfObject:dummyNotification] != NSNotFound, @"Should have posted build complete notification");
}


- (void)testGetsProjectsFromConnection
{	
	// Unfortunately, we can't stub the connection because the repository creates it. So, we need a working URL,
	// which makes this almost an integration test.
	NSURL *url = [NSURL fileURLWithPath:@"Tests/cctray.xml"];
	CCMServer *server = [[[CCMServer alloc] initWithURL:url andProjectNames:[NSArray arrayWithObject:@"connectfour"]] autorelease];
	
	[[[defaultsManagerMock stub] andReturnValue:[NSNumber numberWithInt:1000]] pollInterval];
	[[[defaultsManagerMock expect] andReturn:[NSArray arrayWithObject:server]] servers]; 
	
	// this is now all async and will not work in a unit test anymore
	[monitor start];
	[monitor pollServers:nil];
	
	NSArray *projectList = [monitor projects];
	STAssertEquals(1u, [projectList count], @"Should have found one project.");
	CCMProject *project = [projectList objectAtIndex:0];
	STAssertEqualObjects(@"connectfour", [project name], @"Should have set up project with right name."); 

	//	STAssertEqualObjects(@"build.1", [project lastBuildLabel], @"Should have set up project projectInfo."); 
}

@end
