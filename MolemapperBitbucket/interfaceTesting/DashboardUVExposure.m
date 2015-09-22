//
//  DashboardUVExposure.m
//  MoleMapper
//
//  Created by Karpács István on 21/09/15.
//  Copyright © 2015 Webster Apps. All rights reserved.
//

#import "DashboardUVExposure.h"
#import "APCoreDataKit.h"
#import "DashboardModel.h"

@implementation DashboardUVExposure

- (void)awakeFromNib {
    // Initialization code
    //Heal
    _headerTitle.textColor = [[DashboardModel sharedInstance] getColorForDashboardTextAndButtons];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end