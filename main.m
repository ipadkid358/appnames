#import <Foundation/Foundation.h>

void appInfo(NSString *appRoot);
BOOL bundleGet = NO;
BOOL location = NO;
BOOL documents = NO;
BOOL urlSchemes = NO;
NSMutableDictionary *docCheck = nil;

int main(int argc, char **argv) {
    @autoreleasepool {
        int c;
        while ((c = getopt (argc, argv, ":bldu")) != -1)
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
                    printf("Usage: %s [OPTIONS]\n OPTIONS:\n   -b    Bundle provides the bundle ID of the app\n   -l    Location provides the file path to the main folder of the app\n   -d    Documents provides the file path for any files the app writes to (this is only guaranteed for sandboxed apps)\n   -u    URL Scheme provides any valid protocols directing to the app\n", argv[0]);
                    exit(-1);
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
                if (docsBundle) [docCheck setObject:docsFullPath forKey:docsBundle];
            }
        }
        // Find app directory and pass to appInfo
        NSString *hardAppPath = @"/var/containers/Bundle/Application";
        NSArray *allAppDirs = [fileManager contentsOfDirectoryAtPath:hardAppPath error:NULL];
        for (NSString *topDir in allAppDirs) {
            NSString *topDirPath = [hardAppPath stringByAppendingPathComponent:topDir];
            NSArray *inDir = [fileManager contentsOfDirectoryAtPath:topDirPath error:NULL];
            NSString *appRoot;
            BOOL isAppFolder;
            NSString *findAppDir;
            for (NSString *notFile in inDir) {
                findAppDir = [topDirPath stringByAppendingPathComponent:notFile];
                if ([fileManager fileExistsAtPath:findAppDir isDirectory:&isAppFolder] && isAppFolder) appRoot = findAppDir;
            }
            appInfo(appRoot);
        }
        NSString *stockAppsOrigPath = @"/Applications";
        NSArray *stockAppsList = [fileManager contentsOfDirectoryAtPath:stockAppsOrigPath error:NULL];
        for (NSString *stockApp in stockAppsList) {
            NSString *appRoot = [stockAppsOrigPath stringByAppendingPathComponent:stockApp];
            NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
            if (info[@"CFBundleIcons"] && !(info[@"SBAppTags"])) appInfo(appRoot);
        }
    }
    return 0;
}

void appInfo(NSString *appRoot) {
    @autoreleasepool {
        NSMutableString *output = NSMutableString.new;
        NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        if (info[@"CFBundleIdentifier"]) {
            NSString *bundleID = info[@"CFBundleIdentifier"];
            if (info[@"CFBundleDisplayName"]) [output appendFormat:@"Display Name: %@\n", info[@"CFBundleDisplayName"]];
            if (info[@"CFBundleExecutable"]) [output appendFormat:@"Executable: %@\n", info[@"CFBundleExecutable"]];
            if (info[@"CFBundleName"]) [output appendFormat:@"Bundle Name: %@\n", info[@"CFBundleName"]];
            if (bundleGet) [output appendFormat:@"Bundle ID: %@\n", bundleID];
            [output appendString:@"\n"];
            if (location) [output appendFormat:@"Core Files: %@\n", appRoot];
            if (documents && [docCheck.allKeys containsObject:bundleID]) [output appendFormat:@"Documents: %@\n", docCheck[bundleID]];
            if (info[@"CFBundleURLTypes"] && urlSchemes) {
                NSArray *URLs = info[@"CFBundleURLTypes"];
                [output appendString:@"\nURL Schemes:\n"];
                for (NSDictionary *mainURL in URLs) {
                    NSArray *subURLs = mainURL[@"CFBundleURLSchemes"];
                    for (NSString *url in subURLs) [output appendFormat:@"  %@\n", url];
                }
            }
            [output appendString:@"\n—————————————\n\n"];
        }
        printf("%s", output.UTF8String);
    }
}
