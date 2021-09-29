// Copyright © 2016 Venture Media Labs.
//
// This file is part of MusicKit. The full MusicKit copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

#import <UIKit/UIKit.h>
#import <MusicKit/MusicKit.h>

#include <mxml/geometry/ScrollScoreGeometry.h>
#include <mxml/geometry/PartGeometry.h>


class VMKiOSScoreRenderer {
public:
    /**
     The scale used to render the score.
     */
    static const CGFloat scale;

    /**
     The number of measures to include in the rendering.
     */
    static CGFloat maxWidth;
    
public:
    /**
     Construct a score renderer for the score geometry.
     */
    VMKiOSScoreRenderer(const mxml::ScrollScoreGeometry& scoreGeometry);

    /**
     Render the first `numberOfMeasures` measures of the last part of the score.

     @return A UIImage of the rendered score.
     */
    UIImage* render();

protected:
    static CGSize partSize(const mxml::PartGeometry& partGeometry);
    static CGFloat calculatePartHeight(const mxml::PartGeometry& partGeometry);

    void renderMeasures(CGContextRef ctx);
    void renderWords(CGContextRef ctx);
    void renderTies(CGContextRef ctx);
    
    CGRect getFrame(const mxml::Geometry& geometry);
    void renderLayer(CGContextRef ctx, VMKScoreElementLayer* layer, CGRect frame);

private:
    const mxml::ScrollScoreGeometry& _scoreGeometry;
    const mxml::PartGeometry* _lastPartGeometry;

    CGRect _renderBounds;
};
