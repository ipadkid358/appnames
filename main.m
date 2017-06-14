#import <Foundation/Foundation.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSFileManager *fileManager = NSFileManager.defaultManager;
        
        // Get list of app documents and organize them
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
        
        // Find app directory and print info
        NSString *hardAppPath = @"/var/containers/Bundle/Application";
        NSArray *allAppDirs = [fileManager contentsOfDirectoryAtPath:hardAppPath error:NULL];
        NSMutableString *output = NSMutableString.new;
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
            NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
            if (info[@"CFBundleIdentifier"]) {
                NSString *bundleID = info[@"CFBundleIdentifier"];
                if (info[@"CFBundleDisplayName"]) [output appendString:[NSString stringWithFormat:@"Display Name: %@\n", info[@"CFBundleDisplayName"]]];
                if (info[@"CFBundleExecutable"]) [output appendString:[NSString stringWithFormat:@"Executable: %@\n", info[@"CFBundleExecutable"]]];
                if (info[@"CFBundleName"]) [output appendString:[NSString stringWithFormat:@"Bundle Name: %@\n", info[@"CFBundleName"]]];
                [output appendString:[NSString stringWithFormat:@"Bundle ID: %@\n\n", bundleID]];
                [output appendString:[NSString stringWithFormat:@"Core Files: %@\n", appRoot]];
                if ([[docCheck allKeys] containsObject:bundleID]) [output appendString:[NSString stringWithFormat:@"Documents: %@\n\n", docCheck[bundleID]]];
                if (info[@"CFBundleURLTypes"]) {
                    NSArray *URLs = info[@"CFBundleURLTypes"];
                    [output appendString:@"URL Schemes:\n"];
                    for (NSDictionary *mainURL in URLs) {
                        NSArray *subURLs = mainURL[@"CFBundleURLSchemes"];
                        for (NSString *url in subURLs) {
                            [output appendString:[NSString stringWithFormat:@"  %@\n", url]];
                        }
                    }
                }
                [output appendString:@"\n------------\n\n"];
            }
        }
        NSLog(@"\n%@", output);
    }
    return 0;
}
