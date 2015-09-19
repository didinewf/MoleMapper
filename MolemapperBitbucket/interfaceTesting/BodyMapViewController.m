//
//  BodyMapViewController.m
//



#import "OBShapedButton.h"
#import "VariableStore.h"
#import "BodyFrontView.h"
#import "BodyBackView.h"
#import "HeadDetailView.h"
#import "ZoneViewController.h"
#import "TagZone.h"
#import "StatisticsTVC.h"
#import "CMPopTipView.h"
#import "KLCPopup.h"
#import "Zone.h"
#import "Measurement.h"
#import "Measurement+MakeAndMod.h"
#import "FollowupSurveyRKModule.h"
#import "DataExporter.h"
#import "AppDelegate.h"
#import "BodyMapViewController.h"
#import "MMUser.h"

@interface BodyMapViewController () <UIScrollViewDelegate, CMPopTipViewDelegate>
{
    VariableStore *vars;
}

@property (weak, nonatomic) UIImageView *currentView;
@property (weak, nonatomic) NSString *currentViewTitle;

@property (weak, nonatomic) UIImageView *nextView;
@property (weak, nonatomic) NSString *nextViewTitle;

@property (strong, nonatomic) BodyFrontView *bodyFront;
@property (strong, nonatomic) BodyBackView *bodyBack;
@property (strong, nonatomic) HeadDetailView *headDetail;

@property (strong, nonatomic) CMPopTipView *popTipViewWelcome;
@property (strong, nonatomic) CMPopTipView *popTipViewOpaque;

@property (strong, nonatomic) FollowupSurveyRKModule *followupSurveyModule;

@end

@implementation BodyMapViewController

//These getters rely on variable store vars to alloc/init the custom views
- (BodyFrontView *)bodyFront
{
    if (! _bodyFront)
    {
        _bodyFront = [[BodyFrontView alloc] initWithFrame:vars.imageRect];
    }
    return _bodyFront;
}

- (BodyBackView *)bodyBack
{
    if (! _bodyBack)
    {
        _bodyBack = [[BodyBackView alloc] initWithFrame:vars.imageRect];
    }
    return _bodyBack;
}

- (HeadDetailView *)headDetail
{
    if (! _headDetail)
    {
        _headDetail = [[HeadDetailView alloc] initWithFrame:vars.imageRect];
    }
    return _headDetail;
}

-(void)setUpFlipButton
{
    //Just learn how to do autolayout you lazy bastard
    double bottom = self.view.frame.size.height - 124.0; //Arbitrary placement here to be above tabBar at bottom
    //double left = 20.0;
    double right = self.view.frame.size.width - 80.0;
    UIButton *flipButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [flipButton addTarget:self action:@selector(flipButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [flipButton setBackgroundImage:[UIImage imageNamed:@"flipButton"] forState:UIControlStateNormal];
    flipButton.frame = CGRectMake(right, bottom, 60.0, 60.0);
    [self.view addSubview:flipButton];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AppDelegate *ad = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.context = ad.managedObjectContext;

    vars = [VariableStore sharedVariableStore];
    vars.myViewController = self;
    vars.context = self.context;
    
    self.containerView = [[UIView alloc] initWithFrame:vars.contentRect];   // Container View
    self.containerView.backgroundColor = [UIColor whiteColor];
    [self.scrollView addSubview:self.containerView];
    
    UIButton *backgroundButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backgroundButton.frame = vars.contentRect;
    [self.containerView addSubview:backgroundButton];
    [backgroundButton addTarget:self
                         action:@selector(backgroundTapped:)
               forControlEvents:UIControlEventTouchUpInside];
    
    [self.containerView addSubview:self.headDetail];                          // headDetail View
    self.headDetail.alpha = 0.0;
    
    [self.containerView addSubview:self.bodyBack];// bodyBack View
    self.nextView = self.bodyBack;
    self.nextView.alpha = 0.0;
    self.nextViewTitle = @"Mole Map - Back";
    
    [self.containerView addSubview:self.bodyFront];                         // bodyFront View
    self.currentView = self.bodyFront;
    self.currentViewTitle = @"Mole Map - Front";
    self.navigationItem.title = self.currentViewTitle;
    
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 12.0;
    self.scrollView.delegate=self;
    self.scrollView.contentSize = vars.contentRect.size;
    
    self.followupSurveyModule = [[FollowupSurveyRKModule alloc] init];
    
    if ([self.followupSurveyModule shouldShowFollowupSurvey])
    {
        //prevent demo from showing up over the followup module
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud setBool:NO forKey:@"showDemoInfo"];
        self.followupSurveyModule.presentingVC = self;
        [self.followupSurveyModule showSurvey];
    }
    
    [self setUpFlipButton];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.containerView bringSubviewToFront:self.currentView];
    self.headDetail.alpha = 0.0;
    //[self.scrollView zoomToRect:vars.contentRect animated:NO];
    self.scrollView.zoomScale = 1.0;
    self.navigationItem.title = self.currentViewTitle;
    
    [vars animateTransparencyOfZonesWithPhotoDataOverDuration:1.25];
    [vars updateZoneButtonImages];

}

-(void)viewDidAppear:(BOOL)animated
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardUserDefaults valueForKey:@"showDemoInfo"] == [NSNumber numberWithBool:YES])
    {
        [self showWelcomePopup:self];
        [self showPopTipViewWelcome];
        [self showPopTipViewGreyedOut];
    }
    
    if ([standardUserDefaults valueForKey:@"firstViewOfBodyMap"] == [NSNumber numberWithBool:YES])
    {
        [self showPopTipViewWelcome];
        [self showPopTipViewGreyedOut];
        [standardUserDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"firstViewOfBodyMap"];
    }
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    [vars clearTransparencyOfAllZones];
    [self dismissAllPopTipViews];
}

- (UIView *)viewForZoomingInScrollView:scrollView
{
    // return self.containerView;
    return self.containerView;
}

#pragma mark CMPopTipView methods
- (void)showPopTipViewWelcome
{
    NSString *message = @"Tap on a zone of the body\nto add photos";
    CGRect  viewRect = CGRectMake(0, 0, self.view.bounds.size.width, 0);
    UIView *viewToPointAt = [[UIView alloc] initWithFrame:viewRect];
    viewToPointAt.hidden = YES;
    [self.containerView addSubview:viewToPointAt];
    self.popTipViewWelcome = [[CMPopTipView alloc] initWithMessage:message];
    self.popTipViewWelcome.delegate = self;
    [self.popTipViewWelcome presentPointingAtView:viewToPointAt inView:self.containerView animated:YES];
}

-(void)showPopTipViewGreyedOut
{
    NSString *message = @"Dimmed zones don't\nhave photos yet.";
    CGRect  viewRect = CGRectMake(175, 250, 130, 0);
    UIView *viewToPointAt = [[UIView alloc] initWithFrame:viewRect];
    viewToPointAt.hidden = YES;
    [self.containerView addSubview:viewToPointAt];
    self.popTipViewOpaque = [[CMPopTipView alloc] initWithMessage:message];
    self.popTipViewOpaque.delegate = self;
    [self.popTipViewOpaque presentPointingAtView:viewToPointAt inView:self.containerView animated:YES];
}

//Only Delegate method for CMPopTipView
- (void)popTipViewWasDismissedByUser:(CMPopTipView *)popTipView {
    // User can tap CMPopTipView to dismiss it
    popTipView = nil;
}

//Cycles through the popTip properties and dismisses them
-(void)dismissAllPopTipViews
{
    [self.popTipViewOpaque dismissAnimated:YES];
    [self.popTipViewWelcome dismissAnimated:YES];
}

#pragma mark KLCPopup
- (void)showWelcomePopup:(id)sender
{
    // Generate content view to present
    UIView* contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = [UIColor whiteColor];
    contentView.layer.cornerRadius = 12.0;
    
    UILabel* welcomeLabel = [[UILabel alloc] init];
    welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    welcomeLabel.lineBreakMode = NSLineBreakByWordWrapping;
    welcomeLabel.numberOfLines = 0;
    welcomeLabel.backgroundColor = [UIColor clearColor];
    welcomeLabel.textColor = [UIColor blackColor];
    welcomeLabel.textAlignment = NSTextAlignmentCenter;
    welcomeLabel.font = [UIFont systemFontOfSize:20.0];
    welcomeLabel.text = @"Would you like a quick demo\nof how to map and\nmeasure your moles?";
    
    UIButton* acceptDemoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    acceptDemoButton.translatesAutoresizingMaskIntoConstraints = NO;
    acceptDemoButton.contentEdgeInsets = UIEdgeInsetsMake(10, 75, 10, 75);
    acceptDemoButton.backgroundColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    [acceptDemoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [acceptDemoButton setTitleColor:[[acceptDemoButton titleColorForState:UIControlStateNormal] colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    acceptDemoButton.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [acceptDemoButton setTitle:@"Sure!" forState:UIControlStateNormal];
    acceptDemoButton.layer.cornerRadius = 6.0;
    [acceptDemoButton addTarget:self action:@selector(acceptDemoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton* rejectDemoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rejectDemoButton.translatesAutoresizingMaskIntoConstraints = NO;
    rejectDemoButton.contentEdgeInsets = UIEdgeInsetsMake(10, 60, 10, 60);
    rejectDemoButton.backgroundColor = [UIColor colorWithRed:192.0/255.0 green:192.0/255.0 blue:192.0/255.0 alpha:0.9];
    //rejectDemoButton.backgroundColor = [UIColor colorWithRed:225.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:0.75];
    [rejectDemoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [rejectDemoButton setTitleColor:[[acceptDemoButton titleColorForState:UIControlStateNormal] colorWithAlphaComponent:0.6] forState:UIControlStateHighlighted];
    rejectDemoButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    [rejectDemoButton setTitle:@"No, Thanks" forState:UIControlStateNormal];
    rejectDemoButton.layer.cornerRadius = 6.0;
    [rejectDemoButton addTarget:self action:@selector(rejectDemoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel* activateLaterLabel = [[UILabel alloc] init];
    activateLaterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    activateLaterLabel.lineBreakMode = NSLineBreakByWordWrapping;
    activateLaterLabel.numberOfLines = 0;
    activateLaterLabel.backgroundColor = [UIColor clearColor];
    activateLaterLabel.textColor = [UIColor blackColor];
    activateLaterLabel.textAlignment = NSTextAlignmentCenter;
    activateLaterLabel.font = [UIFont systemFontOfSize:12.0];
    activateLaterLabel.text = @"You can activate the demo at any time in settings";
    
    [contentView addSubview:welcomeLabel];
    [contentView addSubview:acceptDemoButton];
    [contentView addSubview:rejectDemoButton];
    [contentView addSubview:activateLaterLabel];
    
    NSDictionary* views = NSDictionaryOfVariableBindings(contentView, acceptDemoButton, rejectDemoButton, welcomeLabel, activateLaterLabel);
    
    [contentView addConstraints:
    [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(16)-[welcomeLabel]-(24)-[acceptDemoButton]-[rejectDemoButton]-(24)-[activateLaterLabel]-(16)-|"
                                             options:NSLayoutFormatAlignAllCenterX
                                             metrics:nil
                                               views:views]];
     
    [contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(18)-[welcomeLabel]-(18)-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    
    
    KLCPopup* popup = [KLCPopup popupWithContentView:contentView
                                            showType:(KLCPopupShowType)KLCPopupShowTypeSlideInFromRight
                                         dismissType:(KLCPopupDismissType)KLCPopupDismissTypeSlideOutToLeft
                                            maskType:(KLCPopupMaskType)KLCPopupMaskTypeDimmed
                            dismissOnBackgroundTouch:NO
                               dismissOnContentTouch:NO];
    
    [popup show];
}

- (void)showInitialSurveyThanks:(id)sender
{
    // Generate content view to present
    UIView* contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = [UIColor whiteColor];
    contentView.layer.cornerRadius = 12.0;
    
    UILabel* thanksLabel = [[UILabel alloc] init];
    thanksLabel.translatesAutoresizingMaskIntoConstraints = NO;
    thanksLabel.lineBreakMode = NSLineBreakByWordWrapping;
    thanksLabel.numberOfLines = 0;
    thanksLabel.backgroundColor = [UIColor clearColor];
    thanksLabel.textColor = [UIColor blackColor];
    thanksLabel.textAlignment = NSTextAlignmentCenter;
    thanksLabel.font = [UIFont systemFontOfSize:22.0];
    thanksLabel.text = @"Thank you for participating!";

    
    UILabel* checkBack = [[UILabel alloc] init];
    checkBack.translatesAutoresizingMaskIntoConstraints = NO;
    checkBack.lineBreakMode = NSLineBreakByWordWrapping;
    checkBack.numberOfLines = 0;
    checkBack.backgroundColor = [UIColor clearColor];
    checkBack.textColor = [UIColor blackColor];
    checkBack.textAlignment = NSTextAlignmentCenter;
    checkBack.font = [UIFont systemFontOfSize:16.0];
    checkBack.text = @"We'll check back monthly, and in\nthe meantime please continue\nto add and update your\nmole measurements";
    
    UIButton* keepMappingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    keepMappingButton.translatesAutoresizingMaskIntoConstraints = NO;
    keepMappingButton.contentEdgeInsets = UIEdgeInsetsMake(12, 50, 12, 50);
    keepMappingButton.backgroundColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    [keepMappingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [keepMappingButton setTitleColor:[[keepMappingButton titleColorForState:UIControlStateNormal] colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
    keepMappingButton.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [keepMappingButton setTitle:@"Keep On Mapping" forState:UIControlStateNormal];
    keepMappingButton.layer.cornerRadius = 6.0;
    [keepMappingButton addTarget:self action:@selector(okPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    [contentView addSubview:thanksLabel];
    [contentView addSubview:keepMappingButton];
    [contentView addSubview:checkBack];
    NSDictionary* views = NSDictionaryOfVariableBindings(contentView, keepMappingButton, thanksLabel, checkBack);
    
    [contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(20)-[thanksLabel]-(20)-[checkBack]-(30)-[keepMappingButton]-(20)-|"
                                             options:NSLayoutFormatAlignAllCenterX
                                             metrics:nil
                                               views:views]];
    
    [contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(10)-[keepMappingButton]-(10)-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    
    KLCPopup* popup = [KLCPopup popupWithContentView:contentView
                                            showType:(KLCPopupShowType)KLCPopupShowTypeGrowIn
                                         dismissType:(KLCPopupDismissType)KLCPopupDismissTypeShrinkOut
                                            maskType:(KLCPopupMaskType)KLCPopupMaskTypeDimmed
                            dismissOnBackgroundTouch:YES
                               dismissOnContentTouch:YES];
    
    [popup show];
}

- (void)acceptDemoButtonPressed:(id)sender
{
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"showDemoInfo"];
    if ([sender isKindOfClass:[UIView class]])
    {
        [(UIView*)sender dismissPresentingPopup];
    }
}

- (void)rejectDemoButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIView class]])
    {
        [(UIView*)sender dismissPresentingPopup];
    }
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"showDemoInfo"];
}

- (void)okPressed:(id)sender
{
    if ([sender isKindOfClass:[UIView class]])
    {
        [(UIView*)sender dismissPresentingPopup];
        [self performSelector:@selector(showWelcomePopup:) withObject:self afterDelay:0.4];
    }
}

- (void)fieldCancelButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)zoneButtonTapped:(OBShapedButton *)sender
{
    float x = vars.imageRect.origin.x + sender.frame.origin.x;
    float y = vars.imageRect.origin.y + sender.frame.origin.y;
    float width = sender.frame.size.width;
    float height = sender.frame.size.height;
    CGRect zoomToRect = CGRectMake(x, y, width, height);
    
    if ((sender.tag == 1100) || (sender.tag == 2100)) // Front view Head or Back view Head
    {
        float x = vars.imageRect.origin.x + sender.center.x - 80.0;
        float y = vars.imageRect.origin.y + sender.center.y - 30.0;
        float width = 160.0;
        float height = 160.0;
        CGRect zoomRect = CGRectMake(x, y, width, height);
        [self.scrollView zoomToRect:zoomRect animated:YES];
        [self.containerView bringSubviewToFront:self.headDetail];
        [UIView transitionWithView:self.scrollView duration:0.3
                           options:UIViewAnimationOptionTransitionNone
                        animations:^{
                            self.headDetail.alpha = 1.0;
                        } completion:^(BOOL finished) {
                        }];
    } else {
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [self.scrollView zoomToRect:zoomToRect animated:NO];
                         } completion:^(BOOL finished) {
                             [self performSelector:@selector(segueToZoneView:) withObject:sender afterDelay:0.0];
                         }];
        
    }
}

- (IBAction)backgroundTapped:(UIButton *)sender
{
    if (self.headDetail.alpha == 1.0) {
        self.headDetail.alpha = 0.0;
        [self.scrollView zoomToRect:vars.contentRect animated:YES];
        self.navigationItem.title = self.currentViewTitle;
    }
    [self dismissAllPopTipViews];
}

- (IBAction)flipButtonTapped:(UIButton *)sender
{
    [self dismissAllPopTipViews];
    [UIView transitionWithView:self.scrollView duration:0.4
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    animations:^{
                        [self.containerView bringSubviewToFront:self.nextView];
                        UIImageView *lastView = self.currentView;
                        NSString *lastViewTitle = self.currentViewTitle;
                        self.currentView = self.nextView;
                        self.currentViewTitle = self.nextViewTitle;
                        self.nextView = lastView;
                        self.nextViewTitle = lastViewTitle;
                        self.nextView.alpha = 0.0;
                        self.currentView.alpha = 1.0;
                    } completion:^(BOOL finished) {
                        self.navigationItem.title = self.currentViewTitle;
                        //[self.scrollView zoomToRect:vars.contentRect animated:YES];
                    }];
}

- (UIImageView *)imageViewForZoneID:(NSString *)zoneID
{
    UIImageView *imageViewContainingZone;
    int zone = [zoneID intValue];
    if (zone > 1000 && zone < 2000) {imageViewContainingZone = self.bodyFront;}
    else if (zone > 2000 && zone < 3000) {imageViewContainingZone = self.bodyBack;}
    else if (zone > 3000 && zone < 4000) {imageViewContainingZone = self.headDetail;}
    
    return imageViewContainingZone;
}

//Helper method to check if file exists for a given zone
-(BOOL)imageFileExistsForZone:(Zone *)zone
{
    BOOL fileExists;
    NSString *zoneID = [NSString stringWithFormat:@"zone%@",zone.zoneID];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0]; //Get the docs directory
    NSString *filename = [zoneID stringByAppendingString:@".png"];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:filename];
    fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    return fileExists;
}

-(void)segueToZoneView:(id)zoneButtonSending
{
    OBShapedButton *buttonSending = (OBShapedButton *)zoneButtonSending;
    [self performSegueWithIdentifier:@"GoToZoneView" sender:buttonSending];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"GoToZoneView"])
    {
        ZoneViewController *destVC = segue.destinationViewController;
        
        OBShapedButton *buttonSending = (OBShapedButton *)sender;
        NSString *key = [NSString stringWithFormat:@"%ld",(long)buttonSending.tag];
        TagZone *tz = [vars.tagZones objectForKey:key];
        
        destVC.zoneTitle = tz.titleBarText;
        destVC.context = self.context;
        destVC.zoneID = key; //zoneID is a 4-digit int as a string used as a key in Core Data
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end