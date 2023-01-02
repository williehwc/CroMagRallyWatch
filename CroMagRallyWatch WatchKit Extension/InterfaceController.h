//
//  InterfaceController.h
//  CroMagRallyWatch WatchKit Extension
//
//  Created by Willie Chang on 12/1/22.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface InterfaceController : WKInterfaceController
@property (strong, nonatomic) IBOutlet WKInterfaceImage *gameImageView;
@property (strong, nonatomic) IBOutlet WKInterfaceButton *pauseButton;
@end
