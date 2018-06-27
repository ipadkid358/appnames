#import <Foundation/Foundation.h>

// config
static BOOL bundleGet  = NO;
static BOOL location   = NO;
static BOOL documents  = NO;
static BOOL urlSchemes = NO;

static NSMutableDictionary *docCheck = NULL;

NSString *appInfo(NSString *appRoot) {
    NSString *appInfo = NULL;
    @autoreleasepool {
        NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        
        NSString *bundleID = info[@"CFBundleIdentifier"];
        
        BOOL isHidden = [info[@"SBAppTags"][0] isEqualToString:@"hidden"];
        BOOL noIcons = !info[@"CFBundleIcons"];
        if (noIcons || isHidden || !bundleID) {
            return NULL;
        }
        
        NSMutableString *output = [[NSMutableString alloc] initWithString:@"\n"];
        
        NSString *displayName = info[@"CFBundleDisplayName"];
        if (displayName) {
            [output appendFormat:@"Display Name: %@\n", displayName];
        }
        
        NSString *executable = info[@"CFBundleExecutable"];
        if (executable) {
            [output appendFormat:@"Executable: %@\n", executable];
        }
        
        NSString *bundleName = info[@"CFBundleName"];
        if (bundleName) {
            [output appendFormat:@"Bundle Name: %@\n", bundleName];
        }
        
        if (bundleGet) {
            [output appendFormat:@"Bundle ID: %@\n", bundleID];
        }
        
        NSString *docLocation = docCheck[bundleID];
        if (location || docLocation) {
            [output appendString:@"\n"];
            if (location) {
                [output appendFormat:@"Core Files: %@\n", appRoot];
            }
            if (docLocation) {
                [output appendFormat:@"Documents: %@\n", docLocation];
            }
        }
        
        if (urlSchemes) {
            NSArray *URLs = info[@"CFBundleURLTypes"];
            if (URLs) {
                [output appendString:@"\nURL Schemes:\n"];
                for (NSDictionary *mainURL in URLs) {
                    NSArray *subURLs = mainURL[@"CFBundleURLSchemes"];
                    for (NSString *url in subURLs)
                        [output appendFormat:@"  %@\n", url];
                }
            }
        }
        
        [output appendString:@"\n—————————————"];
        appInfo = [NSString stringWithString:output];
    }
    return appInfo;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        int c;
        while ((c = getopt(argc, argv, ":bldu")) != -1)
            switch (c) {
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
                           "   -u    URL Scheme provides any valid protocols directing to the app\n",
                           argv[0]);
                    return 1;
            }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Get list of app documents and add them to a dictionary for easy lookup
        if (documents) {
            docCheck = NSMutableDictionary.new;
            NSString *hardDocsPath = @"/var/mobile/Containers/Data/Application";
            NSArray *docDirs = [fileManager contentsOfDirectoryAtPath:hardDocsPath error:NULL];
            for (NSString *docDir in docDirs) {
                NSString *docsFullPath = [hardDocsPath stringByAppendingPathComponent:docDir];
                NSString *docsHardPlist = [docsFullPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
                NSDictionary *docsDict = [NSDictionary dictionaryWithContentsOfFile:docsHardPlist];
                NSString *docsBundle = docsDict[@"MCMMetadataIdentifier"];
                if (docsBundle) {
                    docCheck[docsBundle] = docsFullPath;
                }
            }
        }
        
        NSMutableArray *allAppRoots = [NSMutableArray array];
        
        // Find app directory and add to array
        NSString *hardAppPath = @"/private/var/containers/Bundle/Application";
        NSArray *allAppDirs = [fileManager contentsOfDirectoryAtPath:hardAppPath error:NULL];
        for (NSString *topDir in allAppDirs) {
            NSString *topDirPath = [hardAppPath stringByAppendingPathComponent:topDir];
            NSArray *inDir = [fileManager contentsOfDirectoryAtPath:topDirPath error:NULL];
            NSString *findAppDir;
            for (NSString *notFile in inDir) {
                findAppDir = [topDirPath stringByAppendingPathComponent:notFile];
                BOOL isAppFolder;
                if ([fileManager fileExistsAtPath:findAppDir isDirectory:&isAppFolder] && isAppFolder) {
                    [allAppRoots addObject:findAppDir];
                }
            }
        }
        
        NSString *stockAppsOrigPath = @"/Applications";
        NSArray *stockAppsList = [fileManager contentsOfDirectoryAtPath:stockAppsOrigPath error:NULL];
        for (NSString *stockApp in stockAppsList) {
            [allAppRoots addObject:[stockAppsOrigPath stringByAppendingPathComponent:stockApp]];
        }
        
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        unsigned long appCount = allAppRoots.count;
        __block int completionCount = 0;
        
        for (int increment = 0; increment < appCount; increment++) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSString *write = appInfo(allAppRoots[increment]);
                const char *writeRaw = write.UTF8String;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (writeRaw) {
                        puts(writeRaw);
                    }
                    completionCount++;
                    if (completionCount == appCount) {
                        CFRunLoopStop(runLoop);
                    }
                });
            });
        }
        CFRunLoopRun();
    }
}
