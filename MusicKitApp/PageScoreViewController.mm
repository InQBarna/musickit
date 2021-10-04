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
@property  (nonatomic, strong) VMKPageScoreLayout* scoreLayout;
@property (nonatomic, strong) VMKPageScoreDataSource* dataSource;
@property  (nonatomic, strong) VMKScrollScoreLayout* scrollScoreLayout;
@property (nonatomic, strong) VMKScrollScoreDataSource* scrollDataSource;

@property (nonatomic, strong)  NSTimer *cursorTimer;

@end

@implementation PageScoreViewController

std::unique_ptr<mxml::dom::Score> _score;
std::unique_ptr<mxml::PageScoreGeometry> _geometry;
std::unique_ptr<mxml::ScrollScoreGeometry> _scrollGeometry;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    
    [self loadScore];
}

- (void)setupView {
    self.view.backgroundColor = UIColor.whiteColor;

    self.scoreLayout = [[VMKPageScoreLayout alloc] init];
    self.scoreLayout.cursorStyle = VMKCursorStyleNote;

    self.dataSource = [[VMKPageScoreDataSource alloc] init];
    self.dataSource.cursorStyle = VMKCursorStyleNote;
    self.dataSource.cursorColor = [UIColor redColor];
    self.dataSource.cursorOpacity = 1;

    self.scrollScoreLayout = [[VMKScrollScoreLayout alloc] init];
    self.scrollDataSource = [[VMKScrollScoreDataSource alloc] init];

//    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.scrollScoreLayout];
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.scoreLayout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:collectionView];

    [NSLayoutConstraint activateConstraints:
     @[
       [collectionView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
       [collectionView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
       [collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
       [collectionView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
       ]
     ];
    self.collectionView = collectionView;
    self.collectionView.backgroundColor = [UIColor clearColor];

    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKSystemReuseIdentifier];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKSystemCursorReuseIdentifier];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:VMKPageHeaderReuseIdentifier];
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:VMKPageHeaderReuseIdentifier];

    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKMeasureReuseIdentifier];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKTieReuseIdentifier];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:VMKDirectionReuseIdentifier];
    
    self.collectionView.dataSource = self.dataSource;
//    self.collectionView.dataSource = self.scrollDataSource;

    [self  updateCursor];
}

- (void)updateCursor {
    __block int division = 0;
    self.cursorTimer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        division += 20;
        self.scoreLayout.cursorMeasureTime = division;
        [self.scoreLayout invalidateLayout];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.cursorTimer forMode:NSDefaultRunLoopMode];
}

- (void)loadScore {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"musicxml"];
    if (path) {
//        _score = loadMXLFile(path);
        _score= loadXML(path);

        if (!_score->parts().empty() && !_score->parts().front()->measures().empty()) {
            _geometry.reset(new mxml::PageScoreGeometry(*_score, 728));
            _scrollGeometry.reset(new mxml::ScrollScoreGeometry(*_score));
        } else {
            _geometry.reset();
            _scrollGeometry.reset();
        }

        self.scoreLayout.scoreGeometry = _geometry.get();
        self.dataSource.scoreGeometry = _geometry.get();
        self.scrollScoreLayout.scoreGeometry = _scrollGeometry.get();
        self.scrollDataSource.scoreGeometry = _scrollGeometry.get();

        

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

std::unique_ptr<mxml::dom::Score> loadXML(NSString* filePath) {
    mxml::parsing::ScoreHandler handler;
    std::ifstream is([filePath UTF8String]);
    lxml::parse(is, [filePath UTF8String], handler);
    return handler.result();
}

@end
