#import <Foundation/Foundation.h>

void appInfo(NSString *appRoot, NSDictionary *docCheck);
BOOL bundleGet = NO;
BOOL location = NO;
BOOL documents = NO;
BOOL urlSchemes = NO;

int main(int argc, char **argv) {
    @autoreleasepool {
        int c;
        while ((c = getopt (argc, argv, "bldu")) != -1)
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
                    printf("Usage: %s [OPTIONS]\n OPTIONS:\n   -b    Bundle provides the bundle ID of the app\n   -l    Location provides the file path to the main folder of the app\n   -d    Documents provides the file path for any files the app writes to (this is only guaranteed for sandboxed apps)\n   -u    URL Scheme provides any valid protocols directing to the app", argv[0]);
                    exit(-1);
                    break;
            }
        
        NSFileManager *fileManager = NSFileManager.defaultManager;
        
        // Get list of app documents and add them to a dictionary for easy lookup
        NSMutableDictionary *docCheck = [[NSMutableDictionary alloc] init];
        NSString *hardDocsPath = @"/var/mobile/Containers/Data/Application";
        NSArray *docDirs = [fileManager contentsOfDirectoryAtPath:hardDocsPath error:NULL];
        for (NSString *docDir in docDirs) {
            NSString *docsFullPath = [hardDocsPath stringByAppendingPathComponent:docDir];
            NSString *docsHardPlist = [docsFullPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *docsDict = [[NSDictionary alloc] initWithContentsOfFile:docsHardPlist];
            NSString *docsBundle = docsDict[@"MCMMetadataIdentifier"];
            [docCheck setObject:docsFullPath forKey:docsBundle];
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
            appInfo(appRoot, docCheck);
        }
        NSString *stockAppsOrigPath = @"/Applications";
        NSArray *stockAppsList = [fileManager contentsOfDirectoryAtPath:stockAppsOrigPath error:NULL];
        for (NSString *stockApp in stockAppsList) {
            NSString *appRoot = [stockAppsOrigPath stringByAppendingPathComponent:stockApp];
            NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
            if (info[@"CFBundleIcons"] && !(info[@"SBAppTags"])) appInfo(appRoot, docCheck);
        }
    }
    return 0;
}

void appInfo(NSString *appRoot, NSDictionary *docCheck) {
    @autoreleasepool {
        NSMutableString *output = NSMutableString.new;
        NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        if (info[@"CFBundleIdentifier"]) {
            NSString *bundleID = info[@"CFBundleIdentifier"];
            if (info[@"CFBundleDisplayName"]) [output appendString:[NSString stringWithFormat:@"Display Name: %@\n", info[@"CFBundleDisplayName"]]];
            if (info[@"CFBundleExecutable"]) [output appendString:[NSString stringWithFormat:@"Executable: %@\n", info[@"CFBundleExecutable"]]];
            if (info[@"CFBundleName"]) [output appendString:[NSString stringWithFormat:@"Bundle Name: %@\n", info[@"CFBundleName"]]];
            if (bundleGet) [output appendString:[NSString stringWithFormat:@"Bundle ID: %@\n", bundleID]];
            [output appendString:@"\n"];
            if (location) [output appendString:[NSString stringWithFormat:@"Core Files: %@\n", appRoot]];
            if ([[docCheck allKeys] containsObject:bundleID] && documents) [output appendString:[NSString stringWithFormat:@"Documents: %@\n", docCheck[bundleID]]];
            if (info[@"CFBundleURLTypes"] && urlSchemes) {
                NSArray *URLs = info[@"CFBundleURLTypes"];
                [output appendString:@"\nURL Schemes:\n"];
                for (NSDictionary *mainURL in URLs) {
                    NSArray *subURLs = mainURL[@"CFBundleURLSchemes"];
                    for (NSString *url in subURLs) {
                        [output appendString:[NSString stringWithFormat:@"  %@\n", url]];
                    }
                }
            }
            [output appendString:@"\n—————————————\n\n"];
        }
        printf("%s", output.UTF8String);
    }
}
