//
//  PageScoreViewController.m
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 29/09/2021.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import "PageScoreViewController.h"
#import <MusicKit/MusicKit.h>
#include "ScoreHandler.h"
#include "lxml.h"
#include <fstream>
#import <SSZipArchive/SSZipArchive.h>

@interface PageScoreViewController ()

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property(nonatomic, strong) VMKPageScoreLayout* scoreLayout;
@property(nonatomic, strong) VMKPageScoreDataSource* dataSource;

@end

@implementation PageScoreViewController

std::unique_ptr<mxml::dom::Score> _score;
std::unique_ptr<mxml::PageScoreGeometry> _geometry;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    
    [self loadScore];
}

- (void)setupView {
    self.scoreLayout = [[VMKPageScoreLayout alloc] init];
    self.dataSource = [[VMKPageScoreDataSource alloc] init];

    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.collectionViewLayout = self.scoreLayout;
    
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKSystemReuseIdentifier];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKSystemCursorReuseIdentifier];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:VMKPageHeaderReuseIdentifier];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:VMKPageHeaderReuseIdentifier];
    
    self.collectionView.dataSource = self.dataSource;
}

- (void)loadScore {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"BeetAnGeSample" ofType:@"mxl"];
    if (path) {
        _score = loadMXLFile(path);
        
        if (!_score->parts().empty() && !_score->parts().front()->measures().empty()) {
            _geometry.reset(new mxml::PageScoreGeometry(*_score, 728));
        } else {
            _geometry.reset();
        }

        self.scoreLayout.scoreGeometry = _geometry.get();
        self.dataSource.scoreGeometry = _geometry.get();
//        self.collectionView.frame = CGRectMake(0, 0, _geometry->frame().size.width, _geometry->frame().size.height);
        [self.collectionView reloadData];
    }
}

std::unique_ptr<mxml::dom::Score> loadMXLFile(NSString* filePath) {
    NSArray* cachePathArray = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachePath = [cachePathArray firstObject];
    NSString* filename = [[filePath lastPathComponent] stringByDeletingPathExtension];
    NSString* destPath = [cachePath stringByAppendingPathComponent:filename];

    NSError* error;
    BOOL success = [SSZipArchive unzipFileAtPath:filePath
                                   toDestination:destPath
                                       overwrite:YES
                                        password:nil
                                           error:&error
                                        delegate:nil];
    if (error)
        NSLog(@"Error unzipping: %@", error);
    if (!success) {
        NSLog(@"Failed to unzip %@", filePath);
        return std::unique_ptr<mxml::dom::Score>();
    }

    NSFileManager* fileManager = [[NSFileManager alloc] init];
    NSArray* paths = [fileManager contentsOfDirectoryAtPath:destPath error:NULL];
    NSString* xmlFile = nil;
    for (NSString* file in paths) {
        if ([file hasSuffix:@".xml"]
            || [file hasSuffix:@".musicxml"]) {
            xmlFile = file;
            break;
        }
    }
    if (xmlFile == nil) {
        NSLog(@"Archive does not contain an xml file: %@", filePath);
        return std::unique_ptr<mxml::dom::Score>();
    }

    try {
        NSString* xmlPath = [destPath stringByAppendingPathComponent:xmlFile];
        std::ifstream is([xmlPath UTF8String]);

        mxml::parsing::ScoreHandler handler;
        lxml::parse(is, [filename UTF8String], handler);
        return handler.result();
    } catch (mxml::dom::InvalidDataError& error) {
        NSLog(@"Error loading score '%@': %s", filePath, error.what());
        return std::unique_ptr<mxml::dom::Score>();
    }
}

@end
