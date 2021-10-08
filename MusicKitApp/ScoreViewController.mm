//
//  PageScoreViewController.m
//  MusicKitApp
//
//  Created by Alexandros Katsaprakakis on 29/09/2021.
//  Copyright © 2021 Venture Media Labs. All rights reserved.
//

#import "ScoreViewController.h"
#import <MusicKit/MusicKit.h>
#include "ScoreHandler.h"
#include "lxml.h"
#include <fstream>
#import <SSZipArchive/SSZipArchive.h>
#import "VMKCustomScrollScoreLayout.h"
#include "Part.h"
#import "ScoreSequenceItem.h"
#include "EventFactory.h"

@interface ScoreViewController ()

@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, weak) UIStepper *bpmStepper;
@property (nonatomic, weak) UILabel *bpmLabel;
@property (nonatomic, weak) UIButton *playStopButton;
@property (nonatomic, weak) UIStepper *measuresStepper;
@property (nonatomic, weak) UILabel *measuresLabel;
@property (nonatomic, weak) UISwitch *metronomeSwitcher;
@property (nonatomic, weak) UILabel *metronomeLabel;

@property  (nonatomic, strong) VMKPageScoreLayout* pageScoreLayout;
@property (nonatomic, strong) VMKPageScoreDataSource* pageDataSource;

@property  (nonatomic, strong) VMKScrollScoreLayout* scrollScoreLayout;
@property (nonatomic, strong) VMKScrollScoreDataSource* scrollDataSource;

@property  (nonatomic, strong) VMKCustomScrollScoreLayout* customScrollScoreLayout;

@property (nonatomic, strong)  NSTimer *cursorTimer;

@property (nonatomic, strong) NSMutableArray<ScoreSequenceItem*> *songSequence;


@property (nonatomic, strong) ScoreAudioPlayer *player;

@property (nonatomic, assign) int metersPerLine;
@end

@implementation ScoreViewController

std::unique_ptr<mxml::dom::Score> _score;
std::unique_ptr<mxml::PageScoreGeometry> _geometry;
std::unique_ptr<mxml::ScrollScoreGeometry> _scrollGeometry;
std::unique_ptr<mxml::EventSequence> _sequence;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.metersPerLine = 2;
    
    [self setupPlayer];
    [self setupView];
    
    [self loadScore];
    [self loadAudio];
}

- (void)setupView {
    self.view.backgroundColor = UIColor.whiteColor;

    self.pageScoreLayout = [[VMKPageScoreLayout alloc] init];
    self.pageScoreLayout.cursorStyle = VMKCursorStyleNote;
    self.pageScoreLayout.scale = 1;
    
    self.pageDataSource = [[VMKPageScoreDataSource alloc] init];
    self.pageDataSource.cursorStyle = VMKCursorStyleNote;
    self.pageDataSource.cursorColor = [UIColor redColor];
    self.pageDataSource.cursorOpacity = 1;

    self.scrollScoreLayout = [[VMKScrollScoreLayout alloc] init];
    self.scrollScoreLayout.cursorStyle = VMKCursorStyleNote;
    
    self.customScrollScoreLayout = [[VMKCustomScrollScoreLayout alloc] initWithWidth:[UIScreen mainScreen].bounds.size.width - 32];
    self.customScrollScoreLayout.cursorStyle = VMKCursorStyleNote;
    
    self.scrollDataSource = [[VMKScrollScoreDataSource alloc] init];
    self.scrollDataSource.cursorStyle = VMKCursorStyleNote;
    self.scrollDataSource.cursorColor = [UIColor redColor];
    self.scrollDataSource.cursorOpacity = 0.6;
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.pageScoreLayout];
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
    
    self.collectionView.dataSource = self.pageDataSource;
//    self.collectionView.dataSource = self.scrollDataSource;
    
    
    UIStepper *stepper = [[UIStepper alloc] init];
    stepper.maximumValue = 250;
    stepper.minimumValue = 40;
    stepper.value = self.player.bpm;
    stepper.backgroundColor = UIColor.whiteColor;
    stepper.translatesAutoresizingMaskIntoConstraints = false;
    stepper.continuous = YES;
    [stepper addTarget:self action:@selector(didChangeBPMStepper:) forControlEvents:UIControlEventValueChanged];
    self.bpmStepper = stepper;
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = false;
    label.textColor = UIColor.blackColor;
    label.text = [NSString stringWithFormat:@"%.1f", self.player.bpm];
    self.bpmLabel = label;
    
    UIStepper *measStepper = [[UIStepper alloc] init];
    measStepper.maximumValue = 8;
    measStepper.minimumValue = 1;
    measStepper.value = self.metersPerLine;
    measStepper.backgroundColor = UIColor.whiteColor;
    measStepper.translatesAutoresizingMaskIntoConstraints = false;
    measStepper.continuous = YES;
    [measStepper addTarget:self action:@selector(didChangeMeasuresStepper:) forControlEvents:UIControlEventValueChanged];
    self.measuresStepper = measStepper;
    
    UILabel *measLabel = [[UILabel alloc] init];
    measLabel.translatesAutoresizingMaskIntoConstraints = false;
    measLabel.textColor = UIColor.blackColor;
    measLabel.text = [NSString stringWithFormat:@"%d meters/line", self.metersPerLine];
    self.measuresLabel = measLabel;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"Play" forState:UIControlStateNormal];
    [button setTitle:@"Stop" forState:UIControlStateSelected];
    [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    button.translatesAutoresizingMaskIntoConstraints = false;
    [button addTarget:self action:@selector(didTapPlayStopButton:) forControlEvents:UIControlEventTouchUpInside];
    self.playStopButton = button;
    
    UISwitch *metronomeSwitcher = [[UISwitch alloc] init];
    metronomeSwitcher.translatesAutoresizingMaskIntoConstraints = false;
    [metronomeSwitcher addTarget:self action:@selector(didTapMetronome:) forControlEvents:UIControlEventValueChanged];
    [metronomeSwitcher setOn:NO];
    self.metronomeSwitcher = metronomeSwitcher;
    
    UILabel *metronomeLabel = [[UILabel alloc] init];
    metronomeLabel.translatesAutoresizingMaskIntoConstraints = false;
    metronomeLabel.textColor = UIColor.blackColor;
    metronomeLabel.text = @"MIDI/Metronome";
    self.metronomeLabel = metronomeLabel;
    
    UIView *firstSeparator = [[UIView alloc] init];
    firstSeparator.translatesAutoresizingMaskIntoConstraints = false;
    
    UIView *secondSeparator = [[UIView alloc] init];
    secondSeparator.translatesAutoresizingMaskIntoConstraints = false;
    
    UIView *thirdSeparator = [[UIView alloc] init];
    thirdSeparator.translatesAutoresizingMaskIntoConstraints = false;
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        label,
        stepper,
        firstSeparator,
        button,
        secondSeparator,
        measStepper,
        measLabel,
        thirdSeparator,
        metronomeSwitcher,
        metronomeLabel
    ]];
    
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = false;
    [stack setBackgroundColor:UIColor.whiteColor];
    [stack.layer setBorderColor:UIColor.blackColor.CGColor];
    [stack.layer setBorderWidth:1];
    [self.view addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:
     @[
       [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
       [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
       
       [stack.heightAnchor constraintEqualToConstant:44],
       
       [firstSeparator.widthAnchor constraintEqualToConstant:40],
       [secondSeparator.widthAnchor constraintEqualToConstant:40],
       [thirdSeparator.widthAnchor constraintEqualToConstant:40]
       ]
     ];
    
}

- (void)setupPlayer {
    self.player = [[ScoreAudioPlayer alloc] init];
}

- (void)didChangeBPMStepper:(UIStepper*)stepper {
    [self.player configureBPM: stepper.value];
    self.bpmLabel.text = [NSString stringWithFormat:@"%.1f", self.player.bpm];
}

- (void)didChangeMeasuresStepper:(UIStepper*)stepper {
    self.metersPerLine = (int)stepper.value;
    self.measuresLabel.text = [NSString stringWithFormat:@"%d meters/line", self.metersPerLine];
    
    [self loadScore];
}


- (void)didTapPlayStopButton:(UIButton*)button {
    button.selected = !button.selected;
    
    if (button.isSelected) {
        [self.player play];
        self.bpmStepper.enabled = NO;
        self.measuresStepper.enabled = NO;
        self.metronomeSwitcher.enabled = NO;
    } else {
        [self.player stop];
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
        self.bpmStepper.enabled = YES;
        self.measuresStepper.enabled = YES;
        self.metronomeSwitcher.enabled = YES;
    }
}

- (void)didTapMetronome:(UISwitch*)switcher {
    [self.player configureMetronomeWithActive:switcher.isOn];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.customScrollScoreLayout.width = self.collectionView.bounds.size.width;
}

- (void)loadScore {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"TELMI_14 - Kreutzer_4" ofType:@"xml"];
    if (path) {
//        _score = loadMXLFile(path);
        _score= loadXML(path);

        if (!_score->parts().empty() && !_score->parts().front()->measures().empty()) {
            int lines = _score->parts().front()->measures().size() / self.metersPerLine;
            _geometry.reset(new mxml::PageScoreGeometry(*_score, 700, 718, lines));
            _scrollGeometry.reset(new mxml::ScrollScoreGeometry(*_score, true));
        } else {
            _geometry.reset();
            _scrollGeometry.reset();
        }

        self.pageScoreLayout.scoreGeometry = _geometry.get();
        self.pageDataSource.scoreGeometry = _geometry.get();
        self.scrollScoreLayout.scoreGeometry = _scrollGeometry.get();
        self.scrollDataSource.scoreGeometry = _scrollGeometry.get();
        self.customScrollScoreLayout.scoreGeometry = _scrollGeometry.get();
        
        _sequence = _geometry->events();
        
        [self.collectionView reloadData];
    }
}

- (void)loadAudio {
    if (_score->parts().empty() || _score->parts().front()->measures().empty()) {
        return;
    }
    
    self.songSequence = @[].mutableCopy;
 
    for (int i = 0; i < _score->parts().front()->measures().size(); i++) {
        auto& measure =  _score->parts().front()->measures()[i];
        auto divisions = _geometry->scoreProperties().divisionsPerMeasure(i);
        const mxml::dom::Time *time = _geometry->scoreProperties().time(i);
        
        auto beatDivisions = divisions / time->beats();
        beatDivisions = beatDivisions * (4 / time->beatType());
        
        for (auto& node : measure->nodes()) {
            if (auto chord = dynamic_cast<mxml::dom::Chord*>(node.get())) {
                NSMutableArray *sequenceNotes = [NSMutableArray array];
                
                for (auto& note : chord->notes()) {
                    ScoreSequenceNote *sequenceNote = [[ScoreSequenceNote alloc] init];
                    sequenceNote.channel = 1;
                    sequenceNote.note = note->midiNumber();
                    sequenceNote.velocity = 0;
                    
                    [sequenceNotes addObject:sequenceNote];
                }
                
                ScoreSequenceItem *item = [[ScoreSequenceItem alloc] init];
                item.duration = (float)(chord->duration())/(float)divisions;
                item.notes = sequenceNotes;
                
                [self.songSequence addObject:item];
            } else if (auto note = dynamic_cast<mxml::dom::Note*>(node.get())) {
                ScoreSequenceNote *sequenceNote = [[ScoreSequenceNote alloc] init];
                sequenceNote.channel = 1;
                sequenceNote.note = note->midiNumber();
                sequenceNote.velocity = 0;
                
                ScoreSequenceItem *item = [[ScoreSequenceItem alloc] init];
                item.duration = (float)note->duration()/(float)divisions;
                item.notes = @[sequenceNote];
                
                [self.songSequence addObject:item];
            }
        }
    }

    self.player.delegate = self;
    [self.player loadWithScoreSequence:self.songSequence];
}

- (void)updatePlayPositionWithMeasures:(NSTimeInterval)measures {
    NSInteger measureIndex = measures;
    auto& measure = _score->parts().front()->measures()[(int)measureIndex];
          
    self.pageScoreLayout.cursorMeasureIndex = measureIndex;

    mxml::dom::time_t measureDivisions = _geometry->scoreProperties().divisionsPerMeasure(measureIndex);
    
    double measurePctFilled = measures - (double)measureIndex;
    self.pageScoreLayout.cursorMeasureTime = (int)(measureDivisions * measurePctFilled);
    [self.pageScoreLayout invalidateLayout];
    
    int collectionIndex = measureIndex / self.metersPerLine;
    if (collectionIndex < [self.collectionView numberOfItemsInSection:VMKPageScoreSectionSystem]) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:collectionIndex inSection:VMKPageScoreSectionSystem] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
    }
    /*
     divisions = _scoreProperties.divisions(event.measureIndex());
     tempo = _scoreProperties.tempo(event.measureIndex(), event.measureTime());

     const auto divisionsPerBeat = _scoreProperties.divisionsPerBeat(event.measureIndex());
     const auto divisionDuration = 60.0 / (divisionsPerBeat * tempo); // In seconds

     wallTime += divisionDuration * static_cast<double>(event.absoluteTime() - time);
     time = event.absoluteTime();
     */
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
