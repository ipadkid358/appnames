#import <Foundation/Foundation.h>

NSString *appInfo(NSString *appRoot);
void asynCaller(NSString *appRoot);
BOOL bundleGet = NO;
BOOL location = NO;
BOOL documents = NO;
BOOL urlSchemes = NO;
NSMutableDictionary *docCheck = nil;

int main(int argc, char **argv) {
    @autoreleasepool {
        int c;
        while ((c = getopt(argc, argv, ":bldu")) != -1)
            switch(c) {
                case 'b':
                    bundleGet = YES;
                    break;
                case 'l':
                    location = YES;
                    break;
                case 'd':
                    documents = YES;
                    break;
                case 'u':
                    urlSchemes = YES;
                    break;
                case '?':
                    printf("Usage: %s [OPTIONS]\n"
                           " OPTIONS:\n"
                           "   -b    Bundle provides the bundle ID of the app\n"
                           "   -l    Location provides the file path to the main folder of the app\n"
                           "   -d    Documents provides the file path for any files the app writes to (this is only guaranteed for sandboxed apps)\n"
                           "   -u    URL Scheme provides any valid protocols directing to the app\n", argv[0]);
                    return 1;
                    break;
            }
        
        NSFileManager *fileManager = NSFileManager.defaultManager;
        
        // Get list of app documents and add them to a dictionary for easy lookup
        if (documents) {
            docCheck = NSMutableDictionary.new;
            NSString *hardDocsPath = @"/var/mobile/Containers/Data/Application";
            NSArray *docDirs = [fileManager contentsOfDirectoryAtPath:hardDocsPath error:NULL];
            for (NSString *docDir in docDirs) {
                NSString *docsFullPath = [hardDocsPath stringByAppendingPathComponent:docDir];
                NSString *docsHardPlist = [docsFullPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
                NSDictionary *docsDict = [[NSDictionary alloc] initWithContentsOfFile:docsHardPlist];
                NSString *docsBundle = docsDict[@"MCMMetadataIdentifier"];
                if (docsBundle) docCheck[docsBundle] = docsFullPath;
            }
        }
        // Find app directory and pass to appInfo
        NSString *hardAppPath = @"/var/containers/Bundle/Application";
        NSArray *allAppDirs = [fileManager contentsOfDirectoryAtPath:hardAppPath error:NULL];
        for (NSString *topDir in allAppDirs) {
            NSString *topDirPath = [hardAppPath stringByAppendingPathComponent:topDir];
            NSArray *inDir = [fileManager contentsOfDirectoryAtPath:topDirPath error:NULL];
            NSString *findAppDir;
            for (NSString *notFile in inDir) {
                findAppDir = [topDirPath stringByAppendingPathComponent:notFile];
                BOOL isAppFolder;
                if ([fileManager fileExistsAtPath:findAppDir isDirectory:&isAppFolder] && isAppFolder) asynCaller(findAppDir);
            }
        }
        
        NSString *stockAppsOrigPath = @"/Applications";
        NSArray *stockAppsList = [fileManager contentsOfDirectoryAtPath:stockAppsOrigPath error:NULL];
        for (NSString *stockApp in stockAppsList) asynCaller([stockAppsOrigPath stringByAppendingPathComponent:stockApp]);
    }
    return 0;
}

void asynCaller(NSString *appRoot) {
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *writeable = appInfo(appRoot);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (writeable) printf("%s", writeable.UTF8String);
            CFRunLoopStop(runLoop);
        });
    });
    CFRunLoopRun();
}

NSString *appInfo(NSString *appRoot) {
    @autoreleasepool {
        NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        
        NSString *bundleID = info[@"CFBundleIdentifier"];
        if (!info[@"CFBundleIcons"] || [info[@"SBAppTags"][0] isEqualToString:@"hidden"] || !bundleID) return nil;
        
        NSMutableString *output = [[NSMutableString alloc] initWithString:@"\n"];
        
        NSString *displayName = info[@"CFBundleDisplayName"];
        if (displayName) [output appendFormat:@"Display Name: %@\n", displayName];
        
        NSString *executable = info[@"CFBundleExecutable"];
        if (executable) [output appendFormat:@"Executable: %@\n", executable];
        
        NSString *bundleName = info[@"CFBundleName"];
        if (bundleName) [output appendFormat:@"Bundle Name: %@\n", bundleName];
        
        if (bundleGet) [output appendFormat:@"Bundle ID: %@\n", bundleID];
        [output appendString:@"\n"];
        if (location) [output appendFormat:@"Core Files: %@\n", appRoot];
        
        NSString *docLocation = docCheck[bundleID];
        if (documents && docLocation) [output appendFormat:@"Documents: %@\n", docLocation];
        
        NSArray *URLs = info[@"CFBundleURLTypes"];
        if (URLs && urlSchemes) {
            [output appendString:@"\nURL Schemes:\n"];
            for (NSDictionary *mainURL in URLs) {
                NSArray *subURLs = mainURL[@"CFBundleURLSchemes"];
                for (NSString *url in subURLs) [output appendFormat:@"  %@\n", url];
            }
        }
        [output appendString:@"\n—————————————\n"];
        return output;
    }
}
