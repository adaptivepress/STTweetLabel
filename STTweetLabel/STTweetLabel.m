//
//  STTweetLabel.m
//  STTweetLabel
//
//  Created by Sebastien Thiebaud on 12/14/12.
//  Copyright (c) 2012 Sebastien Thiebaud. All rights reserved.
//

#import "STTweetLabel.h"

@interface STTweetLabel () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic) CGRect rectToUnderline;
@property (nonatomic, strong) UIColor *colorToUseToUnderline;

@end

@implementation STTweetLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self prepare];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self prepare];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if (!CGRectEqualToRect(self.rectToUnderline, CGRectNull)) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        
        CGContextBeginPath(context);
        CGContextSetStrokeColorWithColor(context, self.colorToUseToUnderline.CGColor);
        CGContextSetLineWidth(context, 1);
        CGContextMoveToPoint(context, self.rectToUnderline.origin.x, self.rectToUnderline.origin.y + self.rectToUnderline.size.height - 1);
        CGContextAddLineToPoint(context, self.rectToUnderline.origin.x + self.rectToUnderline.size.width, self.rectToUnderline.origin.y + self.rectToUnderline.size.height - 1);
        CGContextStrokePath(context);
        
        CGContextRestoreGState(context);
        
        __weak STTweetLabel *safeSelf = self;
        double delayInSeconds = 0.2;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            safeSelf.rectToUnderline = CGRectNull;
            safeSelf.colorToUseToUnderline = nil;
            [safeSelf setNeedsDisplay];
        });
    }
}

- (void)prepare
{
    // Set the basic properties
    [self setBackgroundColor:[UIColor clearColor]];
    [self setClipsToBounds:NO];
    [self setUserInteractionEnabled:YES];
    [self setNumberOfLines:0];
    [self setLineBreakMode:NSLineBreakByWordWrapping];
    
    // Init by default spaces and alignments
    _wordSpace = 0.0;
    _lineSpace = 0.0;
    _verticalAlignment = STVerticalAlignmentTop;
    _horizontalAlignment = STHorizontalAlignmentLeft;
    
    // Alloc and init the arrays which stock the touchable words and their location
    touchLocations = [[NSMutableArray alloc] init];
    touchWords = [[NSMutableArray alloc] init];
    
    // Alloc and init the array for lines' size
    sizeLines = [[NSMutableArray alloc] init];
    
    // Init touchable words colors
    _colorHashtag = [UIColor colorWithWhite:170.0/255.0 alpha:1.0];
    _colorLink = [UIColor colorWithRed:129.0/255.0 green:171.0/255.0 blue:193.0/255.0 alpha:1.0];
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActivated:)];
    self.tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.tapGestureRecognizer];
    
    self.rectToUnderline = CGRectNull;
}

- (void)drawTextInRect:(CGRect)rect
{
    if (_fontHashtag == nil)
    {
        _fontHashtag = self.font;
    }
    
    if (_fontLink == nil)
    {
        _fontLink = self.font;
    }
    
    [touchLocations removeAllObjects];
    [touchWords removeAllObjects];
    
    // Separate words by spaces and lines
    NSArray *words = [[self htmlToText:self.text] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Init a point which is the reference to draw words
    CGPoint drawPoint = CGPointMake(0.0, 0.0);
    
    CGSize sizeWord = CGSizeZero;
    
    // Calculate the size of a space with the actual font
    CGSize sizeSpace = [@" " sizeWithFont:self.font constrainedToSize:rect.size lineBreakMode:self.lineBreakMode];
    
    [self.textColor set];
    
    // Regex to catch @mention #hashtag and link http(s)://
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"((@|#)([A-Z0-9a-z(é|ë|ê|è|à|â|ä|á|ù|ü|û|ú|ì|ï|î|í)_-]+))|(http(s)?://([A-Z0-9a-z._-]*(/)?)*)" options:NSRegularExpressionCaseInsensitive error:&error];
    
    // Regex to catch newline
    NSRegularExpression *regexNewLine = [NSRegularExpression regularExpressionWithPattern:@"\n" options:NSRegularExpressionCaseInsensitive error:&error];
    
    // Regex for forbidden chars on post
    NSRegularExpression *regexForbiddenHashtag = [NSRegularExpression regularExpressionWithPattern:@"([^A-Z0-9a-z(é|ë|ê|è|à|â|ä|á|ù|ü|û|ú|ì|ï|î|í)_-]+)" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *regexForbiddenLink = [NSRegularExpression regularExpressionWithPattern:@"([^A-Z0-9a-z(é|ë|ê|è|à|â|ä|á|ù|ü|û|ú|ì|ï|î|í)./_-]+)" options:NSRegularExpressionCaseInsensitive error:&error];

    BOOL loopWord = NO;
    BOOL removeWord = YES;
    int indexOrigin = 0;

    NSString *wordArray;
    NSString *nextWordArray;
    
    // 2 loops : one calculation (for alignments...) ; one for printing
    for (int repeat = 0; repeat < 2; repeat++)
    {        
        for (int index = 0; index < words.count; index++)
        {
            wordArray = words[index];
            if (index < words.count - 1) {
                nextWordArray = words[index + 1];
                NSString *withTheNextWord = [NSString stringWithFormat:@"%@ %@", wordArray, nextWordArray];
                
                sizeSpace = CGSizeMake([withTheNextWord sizeWithFont:self.font].width -
                                       [wordArray sizeWithFont:self.font].width -
                                       [nextWordArray sizeWithFont:self.font].width,
                                       sizeSpace.height);
            }
            NSString *word = @"";
            NSString *lastPrefix = @"";
            NSMutableString *alreadyPrintedWord = [[NSMutableString alloc] init];
            NSMutableString *printedTouchableWord = [[NSMutableString alloc] init];
            
            do
            {
                if (removeWord)
                {
                    word = [wordArray substringFromIndex:[alreadyPrintedWord length]];
                }

                removeWord = YES;

                sizeWord = [word sizeWithFont:self.font];
                
                if (sizeWord.width <= rect.size.width)
                {
                    loopWord = NO;
                }
                
                // If the word is larger than the container's size
                while (sizeWord.width > rect.size.width)
                {
                    NSString *cutWord = [self cutTheString:word atPoint:drawPoint];
                    
                    [alreadyPrintedWord appendString:cutWord];
                    
                    word = cutWord;
                    sizeWord = [word sizeWithFont:self.font];
                    
                    loopWord = YES;
                }
                
                NSTextCheckingResult *matchNewLine = [regexNewLine firstMatchInString:word options:0 range:NSMakeRange(0, [word length])];

                // Test if the new word must be in a new line
                if (drawPoint.x + sizeWord.width > rect.size.width && !matchNewLine)
                {
                    float originX = 0.0;
                    
                    if (!repeat)
                    {                        
                        float newHAlignment = 0.0;
                        
                        switch (_horizontalAlignment) {
                            case STHorizontalAlignmentLeft:
                                newHAlignment = 0.0;
                                break;
                            case STHorizontalAlignmentCenter:
                                newHAlignment = (rect.size.width - drawPoint.x) / 2;
                                break;
                            case STHorizontalAlignmentRight:
                                newHAlignment = rect.size.width - drawPoint.x + sizeSpace.width;
                                break;
                            default:
                                break;
                        }

                        [sizeLines addObject:[NSNumber numberWithFloat:newHAlignment]];
                    }
                    else
                    {
                        originX = [[sizeLines objectAtIndex:indexOrigin] floatValue];
                        indexOrigin++;
                    }
                    
                    drawPoint = CGPointMake(originX, drawPoint.y + sizeWord.height + _lineSpace);
                }
                
                NSString *preCharacters = @"";
                NSString *wordCharacters = @"";
                NSString *postCharacters = word;

                if (repeat)
                {
                    NSTextCheckingResult *match = [regex firstMatchInString:word options:0 range:NSMakeRange(0, [word length])];

                    // Dissolve the word (for example a hashtag: #youtube!, we want only #youtube)
                    preCharacters = [word substringToIndex:match.range.location];
                    wordCharacters = [word substringWithRange:match.range];
                    postCharacters = [word substringFromIndex:match.range.location + match.range.length];
                }
                
                // Draw the prefix of the word (if it has a prefix)
                if (![preCharacters isEqualToString:@""])
                {
                    // Shadow case
                    if (self.shadowColor != NULL)
                    {
                        [self.shadowColor set];
                        
                        if (repeat)
                        {
                            [preCharacters drawAtPoint:CGPointMake(drawPoint.x + self.shadowOffset.width, drawPoint.y + self.shadowOffset.height) withFont:self.font];
                        }
                    }
                    
                    [self.textColor set];
                    CGSize sizePreCharacters = [preCharacters sizeWithFont:self.font];
                    
                    if (repeat)
                    {
                        [preCharacters drawAtPoint:drawPoint withFont:self.font];
                    }
                    
                    drawPoint = CGPointMake(drawPoint.x + sizePreCharacters.width + _wordSpace, drawPoint.y);
                }
                
                // Draw the touchable word
                if (![wordCharacters isEqualToString:@""])
                {
                    // Shadow case
                    if (self.shadowColor != NULL)
                    {
                        [self.shadowColor set];
                        
                        if (repeat)
                        {
                            [wordCharacters drawAtPoint:CGPointMake(drawPoint.x + self.shadowOffset.width, drawPoint.y + self.shadowOffset.height) withFont:self.font];
                        }
                    }
                    
                    // Set the color for mention/hashtag OR weblink
                    if ([wordCharacters hasPrefix:@"#"])
                    {
                        [_colorHashtag set];
                        lastPrefix = @"#";
                    }
                    else if ([wordCharacters hasPrefix:@"@"])
                    {
                        [_colorHashtag set];
                        lastPrefix = @"@";
                    }
                    else if ([wordCharacters hasPrefix:@"http"])
                    {
                        [_colorLink set];
                        lastPrefix = @"http";
                    }
                    
                    CGSize sizeWordCharacters = [wordCharacters sizeWithFont:self.font];
                    
                    if (repeat)
                    {
                        [wordCharacters drawAtPoint:drawPoint withFont:self.font];
                    }
                    
                    [printedTouchableWord appendString:wordCharacters];
                    
                    // Stock the touchable zone
                    [touchWords addObject:printedTouchableWord];
                    [touchLocations addObject:[NSValue valueWithCGRect:CGRectMake(drawPoint.x, drawPoint.y, sizeWordCharacters.width, sizeWordCharacters.height)]];
                    
                    drawPoint = CGPointMake(drawPoint.x + sizeWordCharacters.width + _wordSpace, drawPoint.y);
                }
                
                // Draw the suffix of the word (if it has a suffix) else the word is not touchable
                if (![postCharacters isEqualToString:@""])
                {                    
                    // If a newline is match
                    if (matchNewLine)
                    {
                        // Shadow case
                        if (self.shadowColor != NULL)
                        {
                            [self.shadowColor set];
                            
                            if (repeat)
                            {
                                [[postCharacters substringToIndex:matchNewLine.range.location] drawAtPoint:CGPointMake(drawPoint.x + self.shadowOffset.width, drawPoint.y + self.shadowOffset.height) withFont:self.font];
                            }
                        }
                        
                        [self.textColor set];
                        
                        if (repeat)
                        {
                            [[postCharacters substringToIndex:matchNewLine.range.location] drawAtPoint:drawPoint withFont:self.font];
                        }
                        
                        float originX = 0.0;
                        
                        if (!repeat)
                        {
                            float newHAlignment = 0.0;
                            
                            switch (_horizontalAlignment) {
                                case STHorizontalAlignmentLeft:
                                    newHAlignment = 0.0;
                                    break;
                                case STHorizontalAlignmentCenter:
                                    newHAlignment = (rect.size.width - drawPoint.x - [[postCharacters substringToIndex:matchNewLine.range.location] sizeWithFont:self.font].width) / 2;
                                    break;
                                case STHorizontalAlignmentRight:
                                    newHAlignment = rect.size.width - drawPoint.x - [[postCharacters substringToIndex:matchNewLine.range.location] sizeWithFont:self.font].width;
                                    break;
                                default:
                                    break;
                            }
                            
                            [sizeLines addObject:[NSNumber numberWithFloat:newHAlignment]];
                        }
                        else
                        {
                            originX = [[sizeLines objectAtIndex:indexOrigin] floatValue];
                            indexOrigin++;
                        }
                        
                        drawPoint = CGPointMake(originX, drawPoint.y + sizeWord.height + _lineSpace);
                    }
                    else
                    {
                        // Shadow case
                        if (self.shadowColor != NULL)
                        {
                            [self.shadowColor set];
                            
                            if (repeat)
                            {
                                [postCharacters drawAtPoint:CGPointMake(drawPoint.x + self.shadowOffset.width, drawPoint.y + self.shadowOffset.height) withFont:self.font];
                            }
                        }
                        
                        if (([lastPrefix isEqualToString:@"@"] || [lastPrefix isEqualToString:@"#"]) && [regexForbiddenHashtag firstMatchInString:postCharacters options:0 range:NSMakeRange(0, [postCharacters length])])
                        {
                            NSTextCheckingResult *matchFor = [regexForbiddenHashtag firstMatchInString:postCharacters options:0 range:NSMakeRange(0, [postCharacters length])];
                            
                            if (matchFor.range.location > 0)
                            {
                                loopWord = YES;
                                removeWord = NO;
                                word = [postCharacters substringFromIndex:matchFor.range.location];
                                postCharacters = [postCharacters substringToIndex:matchFor.range.location];
                            }
                            else
                            {
                                lastPrefix = @"";
                            }
                        }
                        else if ([lastPrefix isEqualToString:@"http"] && [regexForbiddenLink firstMatchInString:postCharacters options:0 range:NSMakeRange(0, [postCharacters length])])
                        {
                            NSTextCheckingResult *matchFor = [regexForbiddenLink firstMatchInString:postCharacters options:0 range:NSMakeRange(0, [postCharacters length])];
                            
                            if (matchFor.range.location > 0)
                            {
                                loopWord = YES;
                                removeWord = NO;
                                word = [postCharacters substringFromIndex:matchFor.range.location];
                                postCharacters = [postCharacters substringToIndex:matchFor.range.location];
                            }
                            else
                            {
                                lastPrefix = @"";
                            }
                        }
                        
                        // Set the color for mention/hashtag OR weblink
                        if ([lastPrefix isEqualToString:@"#"])
                        {
                            [_colorHashtag set];
                        }
                        else if ([lastPrefix isEqualToString:@"@"])
                        {
                            [_colorHashtag set];
                        }
                        else if ([lastPrefix isEqualToString:@"http"])
                        {
                            [_colorLink set];
                        }
                        else
                        {
                            [self.textColor set];
                        }

                        CGSize sizePostCharacters = [postCharacters sizeWithFont:self.font];
                        
                        if (repeat)
                        {
                            [postCharacters drawAtPoint:drawPoint withFont:self.font];
                        }
                        
                        if (![lastPrefix isEqualToString:@""])
                        {
                            // Stock the touchable zone
                            [touchWords addObject:printedTouchableWord];
                            [touchLocations addObject:[NSValue valueWithCGRect:CGRectMake(drawPoint.x, drawPoint.y, sizePostCharacters.width, sizePostCharacters.height)]];
                            
                            [printedTouchableWord appendString:postCharacters];
                        }
                        
                        drawPoint = CGPointMake(drawPoint.x + sizePostCharacters.width + _wordSpace, drawPoint.y);
                    }
                }
                
                if (!loopWord && !matchNewLine)
                {
                    drawPoint = CGPointMake(drawPoint.x + sizeSpace.width + _wordSpace, drawPoint.y);
                }
            } while (loopWord);
        }
    
        if (!repeat)
        {
            // Horizontal alignment
            float newHAlignment = 0.0;
            
            switch (_horizontalAlignment) {
                case STHorizontalAlignmentLeft:
                    newHAlignment = 0.0;
                    break;
                case STHorizontalAlignmentCenter:
                    newHAlignment = (rect.size.width - drawPoint.x) / 2;
                    break;
                case STHorizontalAlignmentRight:
                    newHAlignment = rect.size.width - drawPoint.x + sizeSpace.width;
                    break;
                default:
                    break;
            }
            
            [sizeLines addObject:[NSNumber numberWithFloat:newHAlignment]];
            
            // Vertical alignment
            float newY = 0.0;
            
            switch (_verticalAlignment) {
                case STVerticalAlignmentTop:
                    newY = 0.0;
                    break;
                case STVerticalAlignmentMiddle:
                    newY = (rect.size.height - drawPoint.y - sizeSpace.height) / 2.0;
                    break;
                case STVerticalAlignmentBottom:
                    newY = rect.size.height - drawPoint.y - sizeSpace.height;
                    break;
                default:
                    break;
            }
            
            drawPoint = CGPointMake([[sizeLines objectAtIndex:0] floatValue], newY);
            indexOrigin = 1;
        }
    }
}

- (void)tapActivated:(UITapGestureRecognizer*)recognizer
{
    CGPoint touchPoint = [recognizer locationInView:self];
    __block SEL delegateSelector;
    __block STLinkActionType actionType;
    
    if ([touchLocations count] == 0)
        return;
    
    [touchLocations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
     {
         CGRect touchZone = [obj CGRectValue];
         
         if (CGRectContainsPoint(touchZone, touchPoint)){
             //A touchable word is found
             *stop = YES;
             
             NSString *urlString = [touchWords objectAtIndex:idx];

             if ([urlString hasPrefix:@"@"]){
                 //Twitter account clicked
                 delegateSelector = @selector(twitterAccountClicked:);
                 actionType = STLinkActionTypeAccount;
                 self.colorToUseToUnderline = self.colorLink;
             }else if ([urlString hasPrefix:@"#"]){
                 //Twitter hashtag clicked
                 delegateSelector = @selector(twitterHashtagClicked:);
                 actionType = STLinkActionTypeHashtag;
                 self.colorToUseToUnderline = self.colorHashtag;
             }else if ([urlString hasPrefix:@"http"]){
                 //Twitter hashtag clicked
                 delegateSelector = @selector(websiteClicked:);
                 actionType = STLinkActionTypeWebsite;
                 self.colorToUseToUnderline = self.colorLink;
             }
             
             self.rectToUnderline = touchZone;
             // Mark ourselves for a redraw, so that
             // the underline under the touchZone can be drawn
             [self setNeedsDisplay];
             
             // Perform the delegate and callback call with a slight delay
             // so that the underline under the touchZone is more vivid
             double delayInSeconds = 0.2;
             dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
             dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                 if ([_delegate respondsToSelector:delegateSelector])
                     // WARNING: Using a deprecated method of the delegate
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#warning Using a deprecated method on _delegate
                     [_delegate performSelector:delegateSelector withObject:urlString];
#pragma clang diagnostic pop
                 
                 if (_callbackBlock != NULL)
                     _callbackBlock(actionType, urlString);
             });
         }
     }];
}

- (NSString *)htmlToText:(NSString *)htmlString
{
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&amp;"  withString:@"&"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&lt;"  withString:@"<"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&gt;"  withString:@">"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&quot;" withString:@""""];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"&#039;"  withString:@"'"];
    
    // Extras
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<3" withString:@"♥"];
 
    // normalize and separate newline from other words
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\r\n" withString:@" \n "];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\n" withString:@" \n "];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\\n" withString:@" \n "];
    
    return htmlString;
}

// Cut a string to display just the beginning in the container
- (NSString *)cutTheString:(NSString *)word atPoint:(CGPoint)drawPoint
{
    NSString *substring;
    
    for (int i = 1; i < [word length]; i++)
    {
        substring = [word substringToIndex:[word length] - i];
        CGSize sizeSubstring = [substring sizeWithFont:self.font];
        
        if (drawPoint.x + sizeSubstring.width <= self.frame.size.width)
        {
            break;
        }
    }
    
    return substring;
}

@end
