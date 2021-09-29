//
//  ViewController.m
//  MusicKit
//
//  Created by Daniel Kuntz on 4/27/17.
//  Copyright © 2017 Venture Media Labs. All rights reserved.
//

#import "ViewController.h"
#import <MusicKit/MusicKit.h>
#import <SSZipArchive/SSZipArchive.h>
#include <mxml/parsing/ScoreHandler.h>
#include <mxml/SpanFactory.h>
#include <lxml/lxml.h>

#include <iostream>
#include <fstream>
#include "VMKiOSScoreRenderer.h"

@interface ViewController ()
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self loadScore];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupView {
    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.layer.borderColor = UIColor.grayColor.CGColor;
    self.imageView.layer.borderWidth = 1;
    
    self.imageView.translatesAutoresizingMaskIntoConstraints = false;
    self.imageView.frame = self.view.bounds;
    [self.view addSubview:self.imageView];

    [NSLayoutConstraint activateConstraints:@[
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.imageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ]];
}

- (void)loadScore {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"BeetAnGeSample" ofType:@"mxl"];
    if (path) {
        std::unique_ptr<mxml::dom::Score> score = loadMXL(path);
        
        if (!score || score->parts().empty() || score->parts().front()->measures().empty())
            return;

        // Generate geometry
        std::unique_ptr<mxml::ScrollScoreGeometry> scoreGeometry(new mxml::ScrollScoreGeometry(*score));
        mxml::ScoreProperties scoreProperties = scoreGeometry->scoreProperties();

        VMKiOSScoreRenderer::maxWidth = self.imageView.frame.size.width;
        VMKiOSScoreRenderer renderer(*scoreGeometry);

        UIImage* rep = renderer.render();
        if (!rep)
            return;

        self.imageView.image = rep;
    }
}

std::unique_ptr<mxml::dom::Score> loadMXL(NSString* filePath) {
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
